import 'package:flutter/material.dart';

/// UI preview only: never treat these example permissions as authorization.
class EmployeeModule {
  final String name;
  final IconData icon;
  final String description;
  final String? requiredPermission;
  const EmployeeModule(this.name, this.icon, this.description, {this.requiredPermission});
}

const employeeModules = <EmployeeModule>[
  EmployeeModule('Attendance', Icons.schedule, 'Check-in and attendance history'),
  EmployeeModule('Projects', Icons.apartment, 'Assigned projects'),
  EmployeeModule('CRM', Icons.people_alt_outlined, 'Leads and follow-ups', requiredPermission: 'read lead'),
  EmployeeModule('Stock', Icons.inventory_2_outlined, 'Stock movement and inventory', requiredPermission: 'read stock'),
  EmployeeModule('Labour', Icons.engineering_outlined, 'Labour attendance', requiredPermission: 'read labour'),
  EmployeeModule('Reports', Icons.bar_chart_outlined, 'Project reports', requiredPermission: 'read project'),
  EmployeeModule('Approvals', Icons.task_alt_outlined, 'Pending approvals', requiredPermission: 'can approve'),
];

List<EmployeeModule> modulesFor(Set<String> permissions, {bool superadmin = false}) =>
    employeeModules.where((module) =>
        superadmin || module.requiredPermission == null ||
        permissions.contains(module.requiredPermission)).toList(growable: false);

void main() => runApp(const BlueMarketingApp());

class BlueMarketingApp extends StatelessWidget {
  const BlueMarketingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BlueMarketing Employee',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2456A7),
        surface: const Color(0xFFF7F9FD),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FD),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    ),
    home: const LoginPreview(),
  );
}

class LoginPreview extends StatefulWidget {
  const LoginPreview({super.key});
  @override
  State<LoginPreview> createState() => _LoginPreviewState();
}

class _LoginPreviewState extends State<LoginPreview> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFE1EAFA),
                  child: Icon(Icons.apartment_rounded, size: 40, color: Color(0xFF173B70)),
                )),
                const SizedBox(height: 24),
                const Text('BlueMarketing', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Color(0xFF173B70))),
                const Text('Employee Workspace', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                const SizedBox(height: 32),
                const PreviewNotice(),
                const SizedBox(height: 24),
                const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: 'Show or hide password',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Real sign-in is not enabled yet. Do not enter your actual password.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => const WorkspacePreview())),
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Preview dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5DF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF0D8A4)),
    ),
    child: const Row(children: [
      Icon(Icons.info_outline, color: Color(0xFF946200)),
      SizedBox(width: 10),
      Expanded(child: Text('UI preview — no real login, employee data or API requests.')),
    ]),
  );
}

class WorkspacePreview extends StatefulWidget {
  const WorkspacePreview({super.key});
  @override
  State<WorkspacePreview> createState() => _WorkspacePreviewState();
}

class _WorkspacePreviewState extends State<WorkspacePreview> {
  String role = 'Employee';
  Set<String> get permissions => switch (role) {
    'CRM / Sales' => {'read lead'},
    'Stock Staff' => {'read stock'},
    'Manager' => {'read lead', 'read stock', 'read labour', 'read project', 'can approve'},
    _ => <String>{},
  };

  @override
  Widget build(BuildContext context) {
    final modules = modulesFor(permissions);
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const PreviewNotice(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF173B70), Color(0xFF2F66BC)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome to BlueMarketing', style: TextStyle(fontSize: 20, color: Colors.white,
                  fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Your employee workspace', style: TextStyle(color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Preview role (example only)'),
            items: ['Employee', 'CRM / Sales', 'Stock Staff', 'Manager']
                .map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => role = value);
            },
          ),
          const SizedBox(height: 18),
          const Text('Available modules', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...modules.map((module) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: Icon(module.icon, color: const Color(0xFF2456A7)),
              title: Text(module.name),
              subtitle: Text(module.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(module.name)),
                  body: const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('This screen is a placeholder. Live API integration is pending.',
                        textAlign: TextAlign.center),
                  )),
                ),
              )),
            ),
          )),
        ],
      ),
    );
  }
}
