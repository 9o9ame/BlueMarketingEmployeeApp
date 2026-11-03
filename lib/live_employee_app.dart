import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_unlock.dart';
import 'crm_screens.dart';
import 'stock_screens.dart';
import 'labour_screens.dart';
import 'approval_screens.dart';
import 'project_reports.dart';
import 'dashboard_metrics.dart';

const apiHost = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://dev.bluemarketing.com.pk');
const tokenStorage = FlutterSecureStorage();
const tokenKey = 'bm_access_token';
const biometricFlagKey = 'bm_biometric_enabled';

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
    if (decoded is! Map) throw const FormatException('Invalid API response.');
    final result = objectOf(decoded);
    if (response.statusCode >= 400 || result['status'] == false) {
      throw Exception(result['message'] ?? 'Request failed');
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

class _BlueMarketingLiveAppState extends State<BlueMarketingLiveApp> {
  late final ApiClient api = ApiClient(apiHost);
  Map<String, dynamic>? profile;
  String? error;
  int? projectId;
  bool loading = true;
  bool biometricsEnabled = false;
  bool projectChosen = false;
  final biometric = BiometricUnlock();

  @override
  void initState() {
    super.initState();
    restore();
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
    if (!allowed) return;
    setState(() { projectId = id; projectChosen = true; });
  }

  Future<void> configureBiometrics(bool enable) async {
    if (enable && !await biometric.verify()) {
      throw Exception('Biometric verification failed or is unavailable.');
    }
    await tokenStorage.write(key: biometricFlagKey, value: enable ? '1' : '0');
    if (mounted) setState(() => biometricsEnabled = enable);
  }

  Future<void> restore() async {
    try {
      biometricsEnabled = (await tokenStorage.read(key: biometricFlagKey)) == '1';
      api.token = await tokenStorage.read(key: tokenKey);
      if (api.token != null) {
        if (biometricsEnabled && !await biometric.verify()) {
          throw Exception('Session unlock was not completed.');
        }
        final response = await api.call('GET', 'auth/me');
        setProfile(objectOf(response['data']));
      }
    } catch (_) {
      api.token = null;
      await tokenStorage.delete(key: tokenKey);
      // Require email/password again when biometric unlock cannot complete.
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> login(String email, String password) async {
    setState(() { loading = true; error = null; });
    try {
      final response = await api.call('POST', 'auth/login',
          data: {'email': email, 'password': password});
      final data = objectOf(response['data']);
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) throw Exception('Login token missing.');
      api.token = token;
      await tokenStorage.write(key: tokenKey, value: token);
      // A different account must explicitly opt in to biometrics again.
      await tokenStorage.delete(key: biometricFlagKey);
      biometricsEnabled = false;
      setProfile(data);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> logout() async {
    setState(() => loading = true);
    try {
      await api.call('POST', 'auth/logout');
    } catch (_) {
      // Local logout is required even when server is unavailable.
    }
    api.token = null;
    await tokenStorage.delete(key: tokenKey);
    await tokenStorage.delete(key: biometricFlagKey);
    if (mounted) setState(() { profile = null; projectId = null; projectChosen = false; biometricsEnabled = false; loading = false; });
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BlueMarketing Employee',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457A6)),
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : profile == null
            ? LoginScreen(onLogin: login, error: error)
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
  const LoginScreen({super.key, required this.onLogin, required this.error});
  final Future<void> Function(String, String) onLogin;
  final String? error;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Form(key: form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CircleAvatar(radius: 34, child: Icon(Icons.apartment, size: 36)),
            const SizedBox(height: 20),
            const Text('BlueMarketing', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
            const Text('Employee Workspace', textAlign: TextAlign.center),
            const SizedBox(height: 28),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Work email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (value) => value?.contains('@') == true ? null : 'Enter email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscure = !obscure),
                  )),
              validator: (value) => value?.isNotEmpty == true ? null : 'Enter password',
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 10),
              Text(widget.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (!apiHost.startsWith('https://'))
              const Text('API_BASE_URL is missing. Configure an HTTPS URL.',
                  style: TextStyle(color: Colors.deepOrange)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: apiHost.startsWith('https://') ? () {
                if (form.currentState!.validate()) {
                  widget.onLogin(email.text.trim(), password.text);
                }
              } : null,
              child: const Text('Secure sign in'),
            ),
          ],
        )),
      ),
    ))),
  );
}

class ProjectSelectionScreen extends StatelessWidget {
  const ProjectSelectionScreen({
    super.key, required this.profile, required this.onSelect,
    required this.onLogout,
  });
  final Map<String, dynamic> profile;
  final Future<void> Function(int) onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final projects = listOf(profile['projects']).map(objectOf).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your project'),
        actions: [
          IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Select the project you want to work in.',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (projects.isEmpty)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No active projects assigned'),
              subtitle: Text('Contact your administrator.'),
            ),
          for (final project in projects)
            Card(
              child: ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(project['name']?.toString() ?? 'Project'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: numberOf(project['id']) == null
                    ? null : () => onSelect(numberOf(project['id'])!),
              ),
            ),
        ],
      ),
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
    final user = objectOf(profile['user']);
    final permissions = listOf(profile['permissions']).map((e) => e.toString()).toSet();
    final roles = listOf(profile['role_names']).map((e) => e.toString()).toSet();
    final projects = listOf(profile['projects']).map(objectOf).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('BlueMarketing'),
        actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF183B70), Color(0xFF3266B2)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(user['name']?.toString() ?? 'Employee',
                style: const TextStyle(color: Colors.white, fontSize: 26,
                    fontWeight: FontWeight.bold)),
            Text(roles.join(', '), style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        if (projects.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: projects.any((p) => numberOf(p['id']) == projectId)
                ? projectId : null,
            decoration: const InputDecoration(labelText: 'Selected project'),
            items: projects.map((p) => DropdownMenuItem<int>(
              value: numberOf(p['id']),
              child: Text(p['name']?.toString() ?? 'Project'),
            )).toList(),
            onChanged: onProject,
          ),
        if (projectId != null) ...[
          const SizedBox(height: 16),
          EmployeeDashboardMetrics(api: api, projectId: projectId!),
        ],
        const SizedBox(height: 20),
        const Text('My workspace', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        Card(child: ListTile(
          leading: const Icon(Icons.access_time_outlined),
          title: const Text('Today attendance'),
          subtitle: const Text('Check in, check out, history'),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AttendanceScreen(api: api, projectId: projectId))),
        )),
        for (final module in allowedModules(permissions,
            superadmin: roles.contains('superadmin') || roles.contains('super-admin') || roles.contains('admin')))
          Card(child: ListTile(
            leading: Icon(module.icon),
            title: Text(module.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(context, module.title, module.route,
                project: module.needsProject),
          )),
        const SizedBox(height: 15),
        Card(child: SwitchListTile.adaptive(
          title: const Text('Fingerprint / Face unlock'),
          subtitle: const Text('Optional local unlock on your next app launch'),
          value: biometricsEnabled,
          onChanged: (enabled) async {
            try {
              await onBiometricsChanged(enabled);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$error')),
                );
              }
            }
          },
        )),
        const Text('Data and permissions come from your BlueMarketing account.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
      ]),
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
    if (mounted) setState(() {});
  }
  Future<void> punch(String action) async {
    if (widget.projectId == null) return;
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
    if (yes != true || !mounted) return;
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
      if (mounted) setState(() => posting = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Today attendance')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: info,
      builder: (context, snap) {
        if (snap.hasError) return ErrorPanel(message: snap.error.toString(), retry: reload);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = objectOf(snap.data!['data']);
        return ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['date']?.toString() ?? ''),
              const SizedBox(height: 8),
              Text(data['status']?.toString() ?? 'Unknown',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text("Check in: ${data['check_in_time'] ?? '—'}"),
              Text("Check out: ${data['check_out_time'] ?? '—'}"),
            ]),
          )),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: !posting && widget.projectId != null && data['can_check_in'] == true
                ? () => punch('check-in') : null,
            child: const Text('Check in'),
          ),
          OutlinedButton(
            onPressed: !posting && widget.projectId != null && data['can_check_out'] == true
                ? () => punch('check-out') : null,
            child: const Text('Check out'),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => DataScreen(
                api: widget.api, title: 'Attendance history',
                path: 'attendance/staff/history', projectId: widget.projectId,
              ),
            )),
            child: const Text('Attendance history'),
          ),
        ]);
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
    if (mounted) setState(() {});
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!['data'];
        final rows = data is List
            ? data
            : objectOf(data).entries.map((e) => {'key': e.key, 'value': e.value}).toList();
        if (rows.isEmpty) return const Center(child: Text('No records found.'));
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
