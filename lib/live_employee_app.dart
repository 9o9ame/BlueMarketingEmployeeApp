import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_unlock.dart';
import 'remembered_accounts.dart';
import 'crm_screens.dart';
import 'stock_screens.dart';
import 'labour_screens.dart';
import 'approval_screens.dart';
import 'project_reports.dart';
import 'premium_design.dart';

const apiHost = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://dev.bluemarketing.com.pk');
const tokenStorage = FlutterSecureStorage();
const tokenKey = 'bm_access_token';
const biometricFlagKey = 'bm_biometric_enabled';
const rememberedEmailKey = 'bm_remembered_email';

class ApiRequestException implements Exception {
  const ApiRequestException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> objectOf(dynamic raw) => raw is Map
    ? raw.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
List<dynamic> listOf(dynamic raw) => raw is List ? raw : <dynamic>[];
int? numberOf(dynamic raw) => raw is int ? raw : int.tryParse(raw.toString());

class ApiClient {
  ApiClient(this.host, {http.Client? httpClient}) : client = httpClient ?? http.Client();
  final String host;
  final http.Client client;
  String? token;
  Future<Map<String, dynamic>> call(String method, String endpoint,
      {Map<String, dynamic>? data, Map<String, String>? query}) async {
    if (!host.startsWith('https://')) {
      throw const FormatException('Set HTTPS API_BASE_URL to use the live app.');
    }
    final base = host.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/api/v1/mobile/$endpoint')
        .replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (data != null) request.body = jsonEncode(data);
    final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid API response.');
    }
    final result = objectOf(decoded);
    if (response.statusCode >= 400 || result['status'] == false) {
      throw ApiRequestException(response.statusCode,
        result['message']?.toString() ?? 'Request failed');
    }
    return result;
  }
  void close() => client.close();
}

class ModuleLink {
  const ModuleLink(this.title, this.route, this.icon, this.permissions,
      {this.needsProject = true});
  final String title;
  final String route;
  final IconData icon;
  final Set<String> permissions;
  final bool needsProject;
}

const modules = <ModuleLink>[
  ModuleLink('CRM Leads', 'crm/leads', Icons.people_alt_outlined, {'read lead'}),
  ModuleLink('CRM Summary', 'crm/summary', Icons.insights_outlined, {'read lead'}),
  ModuleLink('Labour', 'attendance/labour', Icons.engineering_outlined, {'read labour', 'read attendance'}),
  ModuleLink('Stock Workspace', 'stock/entries', Icons.inventory_2_outlined, {'read stock', 'view inventory'}),
  ModuleLink('Stock Items', 'stock/items', Icons.category_outlined, {'read stock', 'view inventory'}),
  ModuleLink('Stock Report', 'stock/report', Icons.bar_chart_outlined, {'read stock', 'view inventory'}),
  ModuleLink('Project Reports', 'reports/projects', Icons.apartment_outlined, {'read project', 'view project report'}),
  ModuleLink('Inventory Report', 'reports/inventory', Icons.analytics_outlined, {'view inventory', 'read stock'}),
  ModuleLink('Approvals', 'approvals/', Icons.task_alt_outlined,
      {'direct-update'}, needsProject: false),
];

List<ModuleLink> allowedModules(Set<String> permissions, {bool superadmin = false}) =>
    modules.where((module) => superadmin ||
        module.permissions.any(permissions.contains)).toList();

void main() => runApp(const BlueMarketingLiveApp());

class BlueMarketingLiveApp extends StatefulWidget {
  const BlueMarketingLiveApp({super.key});
  @override
  State<BlueMarketingLiveApp> createState() => _BlueMarketingLiveAppState();
}

class _BlueMarketingLiveAppState extends State<BlueMarketingLiveApp> with WidgetsBindingObserver {
  late final ApiClient api = ApiClient(apiHost);
  final navigatorKey = GlobalKey<NavigatorState>();
  Map<String, dynamic>? profile;
  String? error;
  int? projectId;
  bool loading = true;
  bool biometricsEnabled = false;
  bool projectChosen = false;
  bool canBiometricLogin = false;
  String? rememberedEmail;
  List<String> savedAccounts = const [];
  late final accountVault = RememberedAccounts(tokenStorage);
  final biometric = BiometricUnlock();
  bool _biometricPromptInProgress = false;
  bool _lockOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (biometricsEnabled && profile != null && !_biometricPromptInProgress) {
        _lockOnResume = true;
      }
    } else if (state == AppLifecycleState.resumed && _lockOnResume &&
        biometricsEnabled && profile != null && !_biometricPromptInProgress) {
      _lockOnResume = false;
      _unlockOnResume();
    }
  }

  Future<bool> _verifyOnDevice() async {
    if (_biometricPromptInProgress) {
      return false;
    }
    _biometricPromptInProgress = true;
    try {
      return await biometric.verify();
    } finally {
      _biometricPromptInProgress = false;
    }
  }

  Future<void> _unlockOnResume() async {
    // Close any sensitive module route before showing the biometric prompt.
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    final selected = projectId;
    final wasChosen = projectChosen;
    setState(() { loading = true; profile = null; error = null; });
    try {
      if (await _verifyOnDevice()) {
        await _fetchCurrentUser();
        if (selected != null && listOf(profile?['projects'])
            .map(objectOf).any((p) => numberOf(p['id']) == selected)) {
          projectId = selected;
          projectChosen = wasChosen;
        }
      } else {
        error = 'Unlock cancelled. Use fingerprint again or sign in.';
      }
    } on ApiRequestException catch (requestError) {
      if (requestError.statusCode == 401) {
        await _invalidateExpiredToken();
      }
      error = requestError.message;
    } catch (_) {
      error = 'Unable to unlock. Retry fingerprint or use your password.';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void setProfile(Map<String, dynamic> data) {
    profile = data;
    final projects = listOf(data['projects']);
    // Every multi-project user explicitly chooses the working project.
    projectChosen = projects.length <= 1;
    projectId = projectChosen && projects.isNotEmpty
        ? numberOf(objectOf(projects.first)['id']) : null;
  }

  Future<void> chooseProject(int id) async {
    final allowed = listOf(profile?['projects'])
        .map(objectOf).any((project) => numberOf(project['id']) == id);
    if (!allowed) {
      return;
    }
    setState(() { projectId = id; projectChosen = true; });
  }

  Future<void> configureBiometrics(bool enabled) async {
    if (enabled && !await _verifyOnDevice()) {
      throw Exception('Fingerprint or face verification was not completed.');
    }
    if (!enabled) {
      // Explicitly disabling biometric login destroys saved login passwords.
      await accountVault.clearPasswords();
    }
    await tokenStorage.write(key: biometricFlagKey,
        value: enabled ? '1' : '0');
    if (mounted) {
      setState(() {
        biometricsEnabled = enabled;
        canBiometricLogin = enabled && (api.token != null ||
            savedAccounts.isNotEmpty);
      });
    }
  }

  Future<void> _fetchCurrentUser() async {
    final response = await api.call('GET', 'auth/me');
    setProfile(objectOf(response['data']));
  }

  Future<void> _invalidateExpiredToken() async {
    api.token = null;
    await tokenStorage.delete(key: tokenKey);
    // Keep biometric preference and explicit remembered credentials.
    canBiometricLogin = biometricsEnabled;
  }

  Future<void> _loginFromVault(String email) async {
    // This private method MUST only be called after biometric verification.
    final password = await accountVault.passwordAfterBiometric(email);
    if (password == null || password.isEmpty) {
      throw const FormatException(
          'No biometric credential stored for this account. Enter its password once.');
    }
    final response = await api.call('POST', 'auth/login',
      data: {'email': email, 'password': password});
    final data = objectOf(response['data']);
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Login token missing.');
    }
    api.token = token;
    await tokenStorage.write(key: tokenKey, value: token);
    rememberedEmail = email;
    await tokenStorage.write(key: rememberedEmailKey, value: email);
    await accountVault.recordLogin(email);
    savedAccounts = await accountVault.list();
    setProfile(data);
  }

  Future<void> restore() async {
    try {
      biometricsEnabled =
          (await tokenStorage.read(key: biometricFlagKey)) == '1';
      savedAccounts = await accountVault.list();
      rememberedEmail = await tokenStorage.read(key: rememberedEmailKey);
      rememberedEmail ??= savedAccounts.isEmpty ? null : savedAccounts.first;
      api.token = await tokenStorage.read(key: tokenKey);
      canBiometricLogin = biometricsEnabled;
      if (api.token != null) {
        final allowed = !biometricsEnabled || await _verifyOnDevice();
        if (allowed) {
          try {
            await _fetchCurrentUser();
          } on ApiRequestException catch (problem) {
            if (problem.statusCode != 401) rethrow;
            await _invalidateExpiredToken();
            if (biometricsEnabled && rememberedEmail != null &&
                await accountVault.hasPassword(rememberedEmail!)) {
              // Re-use the biometric check that just succeeded.
              await _loginFromVault(rememberedEmail!);
            } else {
              error = 'Session expired. Please sign in again.';
            }
          }
        } else {
          error = 'Unlock cancelled. Tap fingerprint to retry.';
        }
      } else if (biometricsEnabled && rememberedEmail != null &&
          await accountVault.hasPassword(rememberedEmail!)) {
        // Explicit logout revoked the token, so obtain a NEW token via the
        // registered auth/login API after checking a stored credential.
        if (await _verifyOnDevice()) {
          await _loginFromVault(rememberedEmail!);
        } else {
          error = 'Unlock cancelled. Tap fingerprint to retry.';
        }
      }
    } on ApiRequestException catch (problem) {
      error = problem.message;
    } catch (_) {
      error = 'Could not restore the session. Sign in or retry fingerprint.';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> retryBiometric([String? chosenEmail]) async {
    if (!biometricsEnabled) {
      setState(() => error =
        'Enable fingerprint sign-in by choosing Remember for fingerprint at login.');
      return;
    }
    final email = chosenEmail ?? rememberedEmail ??
        (savedAccounts.isEmpty ? null : savedAccounts.first);
    if (email == null) {
      setState(() => error = 'No account saved. Sign in using your password first.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      if (!await _verifyOnDevice()) {
        error = 'Fingerprint verification was cancelled or failed.';
      } else if (api.token != null &&
          email.toLowerCase() == rememberedEmail?.toLowerCase()) {
        try {
          await _fetchCurrentUser();
        } on ApiRequestException catch (problem) {
          if (problem.statusCode != 401) rethrow;
          await _invalidateExpiredToken();
          await _loginFromVault(email);
        }
      } else {
        await _loginFromVault(email);
      }
    } on ApiRequestException catch (problem) {
      error = problem.message;
    } catch (problem) {
      error = '$problem';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> selectSavedAccount(String email) async {
    // Always show the selected email, even when the password wasn't saved.
    rememberedEmail = email;
    if (biometricsEnabled && await accountVault.hasPassword(email)) {
      await retryBiometric(email);
    } else if (mounted) {
      setState(() {
        error = 'Account selected. Use its password or Android Autofill to sign in.';
      });
    }
  }

  Future<void> login(String email, String password) async {
    setState(() { loading = true; error = null; });
    try {
      final cleanEmail = RememberedAccounts.normalized(email);
      final response = await api.call('POST', 'auth/login',
          data: {'email': cleanEmail, 'password': password});
      final data = objectOf(response['data']);
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw const FormatException('Login token missing.');
      }
      api.token = token;
      await tokenStorage.write(key: tokenKey, value: token);
      await tokenStorage.write(key: rememberedEmailKey, value: cleanEmail);
      rememberedEmail = cleanEmail;
      try {
        await accountVault.recordLogin(cleanEmail);
        savedAccounts = await accountVault.list();
      } catch (_) {
        // A storage failure must not invalidate a successful server login.
      }
      canBiometricLogin = biometricsEnabled;
      setProfile(data);
    } catch (problem) {
      error = '$problem';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> loginRemembered(String email, String password, bool remember) async {
    await login(email, password);
    if (!remember || profile == null) return;
    // Never save passwords silently: this checkbox requires explicit opt-in,
    // and a successful device biometric prompt gates the first save.
    if (!await _verifyOnDevice()) return;
    try {
      await accountVault.rememberPassword(email, password);
      await tokenStorage.write(key: biometricFlagKey, value: '1');
      if (mounted) {
        setState(() {
          biometricsEnabled = true;
          canBiometricLogin = true;
        });
      }
    } catch (_) {
      // Login remains successful even if the optional vault write fails.
    }
  }

  Future<void> logout() async {
    setState(() => loading = true);
    try {
      await api.call('POST', 'auth/logout');
    } catch (_) {
      // Never keep the current server token after explicit logout.
    }
    api.token = null;
    await tokenStorage.delete(key: tokenKey);
    canBiometricLogin = biometricsEnabled;
    if (mounted) {
      setState(() {
        profile = null;
        projectId = null;
        projectChosen = false;
        error = null;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'BlueMarketing Employee',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: BmColors.blue),
      scaffoldBackgroundColor: BmColors.background,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white,
        foregroundColor: BmColors.navy, elevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(color: BmColors.navy,
          fontSize: 19, fontWeight: FontWeight.w800)),
      cardTheme: CardThemeData(
        color: Colors.white, elevation: 1,
        shadowColor: BmColors.navy.withValues(alpha: .10),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: Color(0xFFE7EBF5)))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: BmColors.blue, foregroundColor: Colors.white,
        minimumSize: const Size(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: BmColors.blue, minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BmColors.blue, foregroundColor: Colors.white),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDEE5F2))),
      ),
    ),
    home: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : profile == null
            ? LoginScreen(onLogin: login, error: error,
                onLoginRemembered: loginRemembered,
                savedAccounts: savedAccounts,
                onSavedAccount: selectSavedAccount,
                rememberedEmail: rememberedEmail,
                showFingerprint: true,
                onFingerprint: () => retryBiometric())
            : !projectChosen
                ? ProjectSelectionScreen(profile: profile!, onSelect: chooseProject, onLogout: logout)
                : HomeScreen(
                api: api,
                profile: profile!,
                projectId: projectId,
                onProject: (value) => setState(() => projectId = value),
                onLogout: logout,
                biometricsEnabled: biometricsEnabled,
                onBiometricsChanged: configureBiometrics,
              ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key, required this.onLogin, required this.error,
    this.rememberedEmail, this.showFingerprint = false, this.onFingerprint,
    this.savedAccounts = const [], this.onSavedAccount, this.onLoginRemembered,
  });
  final Future<void> Function(String, String) onLogin;
  final Future<void> Function(String, String, bool)? onLoginRemembered;
  final Future<void> Function(String)? onSavedAccount;
  final List<String> savedAccounts;
  final String? error;
  final String? rememberedEmail;
  final bool showFingerprint;
  final VoidCallback? onFingerprint;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final email = TextEditingController(text: widget.rememberedEmail ?? '');
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool obscure = true;
  bool saveForFingerprint = false;

  Future<void> chooseAccount() async {
    if (widget.savedAccounts.isEmpty) return;
    FocusScope.of(context).unfocus();
    final chosen = await showModalBottomSheet<String>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (dialog) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('Recent BlueMarketing accounts',
              style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Most recent account first.'),
          ),
          for (final account in widget.savedAccounts)
            ListTile(
              leading: const Icon(Icons.account_circle_rounded,
                color: BmColors.blue),
              title: Text(account),
              subtitle: const Text('Tap to sign in'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(dialog, account),
            ),
        ]),
      )),
    );
    if (chosen == null || !mounted) return;
    email.text = chosen;
    password.clear();
    setState(() {});
    await widget.onSavedAccount?.call(chosen);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.navy,
    body: Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BmColors.navy, BmColors.blue, BmColors.cyan, BmColors.purple])))),
      Positioned(top: -80, right: -75, child: CircleAvatar(
        radius: 135, backgroundColor: Colors.white.withValues(alpha: .08))),
      Positioned(bottom: -100, left: -90, child: CircleAvatar(
        radius: 160, backgroundColor: Colors.white.withValues(alpha: .09))),
      SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: BmLogo(size: 74)),
            const SizedBox(height: 14),
            const Text('BlueMarketing', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.w900)),
            const Text('Employee Workspace', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 30),
            const Text('Welcome back!', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const Text('Sign in to your employee account',
              style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 19),
            BmSoftCard(padding: const EdgeInsets.all(20),
              child: Form(key: form, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onTap: chooseAccount,
                    decoration: InputDecoration(labelText: 'Work email',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      suffixIcon: widget.savedAccounts.isEmpty ? null :
                        IconButton(
                          tooltip: 'Choose recent account',
                          icon: const Icon(Icons.manage_accounts_rounded),
                          onPressed: chooseAccount)),
                    validator: (value) => value?.contains('@') == true
                      ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: password, obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    onTap: chooseAccount,
                    decoration: InputDecoration(labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_outlined :
                          Icons.visibility_off_outlined),
                        onPressed: () => setState(() => obscure = !obscure))),
                    validator: (value) => value?.isNotEmpty == true
                      ? null : 'Enter password',
                  ),
                  if (widget.savedAccounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: chooseAccount,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Use a recent account'),
                    ),
                  ],
                  if (widget.error != null) ...[
                    const SizedBox(height: 10),
                    Text(widget.error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: saveForFingerprint,
                    onChanged: (value) =>
                      setState(() => saveForFingerprint = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Remember for fingerprint sign-in',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    subtitle: const Text('Optional encrypted password storage; '
                      'requires biometric verification.',
                      style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(height: 12),
                  BmPrimaryButton(label: 'Secure sign in',
                    onPressed: !apiHost.startsWith('https://') ? null : () {
                      if (form.currentState!.validate()) {
                        if (widget.onLoginRemembered != null) {
                          widget.onLoginRemembered!(
                            email.text.trim(), password.text, saveForFingerprint);
                        } else {
                          widget.onLogin(email.text.trim(), password.text);
                        }
                      }
                    }),
                  if (widget.showFingerprint && widget.onFingerprint != null) ...[
                    const SizedBox(height: 13),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.fingerprint_rounded, size: 26),
                      label: const Text('Sign in with fingerprint / face'),
                      onPressed: widget.onFingerprint,
                    ),
                  ],
                  const SizedBox(height: 13),
                  const Text('Recent emails are remembered. Passwords are saved '
                    'only if you select biometric sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BmColors.muted, fontSize: 11)),
                ],
              )),
            ),
          ]),
        ),
      ))),
    ]),
  );
}

class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key, required this.profile,
    required this.onSelect, required this.onLogout});
  final Map<String, dynamic> profile;
  final Future<void> Function(int) onSelect;
  final VoidCallback onLogout;

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final projects = listOf(widget.profile['projects']).map(objectOf)
      .where((p) => (p['name']?.toString() ?? '')
        .toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: BmColors.background,
      appBar: AppBar(title: const Text('Select a project'),
        actions: [IconButton(tooltip: 'Logout', onPressed: widget.onLogout,
          icon: const Icon(Icons.logout_rounded))]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [BmColors.blue, BmColors.purple]),
            borderRadius: BorderRadius.circular(23)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BmLogo(size: 40), SizedBox(height: 12),
            Text('Choose your workspace',
              style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w800)),
            Text('Choose a project to continue your work',
              style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 19),
        TextField(onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Search projects')),
        const SizedBox(height: 15),
        if (projects.isEmpty) const BmSoftCard(child: ListTile(
          title: Text('No matching projects'),
          subtitle: Text('Check your search or contact your administrator.'))),
        for (var i = 0; i < projects.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(projects[i]['id']),
              duration: Duration(milliseconds: 250 + i * 50),
              tween: Tween(begin: .95, end: 1),
              builder: (context, amount, child) =>
                Transform.scale(scale: amount, child: child),
              child: BmSoftCard(padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(width: 54, height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: i.isEven
                        ? [BmColors.cyan, BmColors.blue]
                        : [BmColors.purple, BmColors.blue]),
                      borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white)),
                  title: Text(projects[i]['name']?.toString() ?? 'Project',
                    style: const TextStyle(fontWeight: FontWeight.w800,
                      color: BmColors.navy)),
                  subtitle: const Text('Tap to open workspace',
                    style: TextStyle(color: BmColors.muted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: numberOf(projects[i]['id']) == null ? null :
                    () => widget.onSelect(numberOf(projects[i]['id'])!),
                )),
            ),
          ),
      ]),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key, required this.api, required this.profile,
    required this.projectId, required this.onProject, required this.onLogout,
    required this.biometricsEnabled, required this.onBiometricsChanged,
  });
  final ApiClient api;
  final Map<String, dynamic> profile;
  final int? projectId;
  final ValueChanged<int?> onProject;
  final VoidCallback onLogout;
  final bool biometricsEnabled;
  final Future<void> Function(bool) onBiometricsChanged;

  void open(BuildContext context, String title, String path, {bool project = true}) {
    if (project && projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a project first.')));
      return;
    }
    if (path == 'crm/leads' && projectId != null) {
      final permissions = listOf(profile['permissions']).map((e) => e.toString()).toSet();
      final roles = listOf(profile['role_names']).map((e) => e.toString()).toSet();
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CrmScreen(
        api: api, projectId: projectId!,
        permissions: roles.contains('superadmin')
          ? {...permissions, 'create lead', 'update lead'} : permissions,
      )));
      return;
    }
    final permissions = listOf(profile['permissions']).map((e) => e.toString()).toSet();
    final roles = listOf(profile['role_names']).map((e) => e.toString()).toSet();
    if (path.startsWith('stock/') && projectId != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
        StockWorkspace(api: api, projectId: projectId!,
          canWrite: permissions.contains('create stock') ||
              roles.contains('admin') || roles.contains('superadmin'))));
      return;
    }
    if (path == 'attendance/labour' && projectId != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
        LabourWorkspace(api: api, projectId: projectId!,
          permissions: permissions, roles: roles)));
      return;
    }
    if (path == 'reports/inventory' && projectId != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
        StockRecords(api: api, projectId: projectId!,
          path: 'reports/inventory', title: 'Inventory report')));
      return;
    }
    if (path == 'reports/projects' && projectId != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
        ProjectReportsHome(api: api, projectId: projectId!,
          permissions: permissions, roles: roles)));
      return;
    }
    if (path == 'approvals/' && mayReadApprovals(permissions, roles)) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
        ApprovalWorkspace(api: api, permissions: permissions, roles: roles)));
      return;
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DataScreen(
      api: api, title: title, path: path, projectId: project ? projectId : null,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final permissions = listOf(profile['permissions']).map((e) => e.toString()).toSet();
    final roles = listOf(profile['role_names']).map((e) => e.toString()).toSet();
    final available = allowedModules(permissions,
      superadmin: roles.contains('superadmin') ||
        roles.contains('super-admin') || roles.contains('admin'));
    return BmDashboard(
      api: api, profile: profile, projectId: projectId, modules: available,
      biometricsEnabled: biometricsEnabled,
      onBiometricsChanged: onBiometricsChanged,
      onProject: onProject,
      onLogout: onLogout,
      onAttendance: () => Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(api: api, projectId: projectId))),
      onModule: (module) => open(context, module.title, module.route,
        project: module.needsProject),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.api, required this.projectId});
  final ApiClient api;
  final int? projectId;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<Map<String, dynamic>> info;
  bool posting = false;
  @override
  void initState() {
    super.initState();
    reload();
  }
  void reload() {
    info = widget.api.call('GET', 'attendance/staff/today',
      query: widget.projectId == null ? null : {'project_id': widget.projectId.toString()});
    if (mounted) {
      setState(() {});
    }
  }
  Future<void> punch(String action) async {
    if (widget.projectId == null) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $action'),
        content: const Text('This action will record real attendance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    setState(() => posting = true);
    try {
      await widget.api.call('POST', 'attendance/staff/$action',
          data: {'project_id': widget.projectId});
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => posting = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('Attendance')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: info,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPanel(message: snapshot.error.toString(), retry: reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = objectOf(snapshot.data!['data']);
        final checkedIn = data['can_check_in'] == false;
        return RefreshIndicator(
          onRefresh: () async { reload(); await info; },
          child: ListView(children: [
            const BmModuleHero(title: 'My attendance',
              subtitle: 'Daily check-in, check-out and your attendance history',
              icon: Icons.access_time_rounded, accent: BmColors.teal),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                BmSoftCard(child: Column(children: [
                  CircleAvatar(radius: 31, backgroundColor:
                    BmColors.teal.withValues(alpha: .12),
                    child: Icon(checkedIn ? Icons.verified_rounded :
                      Icons.schedule_rounded, color: BmColors.teal, size: 35)),
                  const SizedBox(height: 11),
                  Text(data['status']?.toString() ?? 'Attendance status',
                    style: const TextStyle(color: BmColors.navy, fontSize: 23,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 9),
                  Text(data['date']?.toString() ?? '',
                    style: const TextStyle(color: BmColors.muted)),
                ])),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: BmSoftCard(child: Column(children: [
                    const Icon(Icons.login_rounded, color: BmColors.teal, size: 27),
                    const SizedBox(height: 7),
                    const Text('Check in', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("${data['check_in_time'] ?? '—'}",
                      style: const TextStyle(color: BmColors.muted)),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: !posting && widget.projectId != null &&
                      data['can_check_in'] == true ? () => punch('check-in') : null,
                      child: const Text('Check in')),
                  ]))),
                  const SizedBox(width: 11),
                  Expanded(child: BmSoftCard(child: Column(children: [
                    const Icon(Icons.logout_rounded, color: BmColors.purple, size: 27),
                    const SizedBox(height: 7),
                    const Text('Check out', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("${data['check_out_time'] ?? '—'}",
                      style: const TextStyle(color: BmColors.muted)),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: !posting && widget.projectId != null &&
                      data['can_check_out'] == true ? () => punch('check-out') : null,
                      child: const Text('Check out')),
                  ]))),
                ]),
                const SizedBox(height: 22),
                const Align(alignment: Alignment.centerLeft,
                  child: Text('Attendance history', style: TextStyle(
                    fontWeight: FontWeight.w800, color: BmColors.navy, fontSize: 20))),
                const SizedBox(height: 11),
                BmSoftCard(child: ListTile(
                  leading: const Icon(Icons.history_rounded, color: BmColors.blue),
                  title: const Text('View attendance history'),
                  subtitle: const Text('Your recorded attendance from the server'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => DataScreen(
                      api: widget.api, title: 'Attendance history',
                      path: 'attendance/staff/history', projectId: widget.projectId))),
                )),
              ]),
            ),
          ]),
        );
      },
    ),
  );
}

class DataScreen extends StatefulWidget {
  const DataScreen({
    super.key, required this.api, required this.title,
    required this.path, required this.projectId,
  });
  final ApiClient api;
  final String title;
  final String path;
  final int? projectId;
  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  late Future<Map<String, dynamic>> response;
  @override
  void initState() { super.initState(); reload(); }
  void reload() {
    response = widget.api.call('GET', widget.path,
        query: widget.projectId == null ? null : {'project_id': widget.projectId.toString()});
    if (mounted) {
      setState(() {});
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: response,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPanel(message: snapshot.error.toString(), retry: reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!['data'];
        final rows = data is List
            ? data
            : objectOf(data).entries.map((e) => {'key': e.key, 'value': e.value}).toList();
        if (rows.isEmpty) {
          return const Center(child: Text('No records found.'));
        }
        return RefreshIndicator(
          onRefresh: () async { reload(); await response; },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = objectOf(rows[i]);
              final title = row['name'] ?? row['first_name'] ??
                  row['item_name'] ?? row['project'] ?? row['key'] ??
                  row['id'] ?? 'Record';
              final summary = row['value'] ?? row['description'] ??
                  row['status'] ?? row['date'] ?? '';
              return Card(child: ExpansionTile(
                title: Text(title.toString()),
                subtitle: Text(summary is Map || summary is List
                    ? 'Tap to inspect details' : summary.toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                children: [
                  for (final entry in row.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.key),
                      subtitle: Text(entry.value is Map || entry.value is List
                          ? 'Structured data' : (entry.value?.toString() ?? '—'),
                          maxLines: 3),
                    ),
                ],
              ));
            },
          ),
        );
      },
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 40),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 14),
      FilledButton(onPressed: retry, child: const Text('Retry')),
    ]),
  ));
}
