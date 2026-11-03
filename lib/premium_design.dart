import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class BmColors {
  static const navy = Color(0xFF122D58);
  static const blue = Color(0xFF1259F4);
  static const cyan = Color(0xFF00BBE8);
  static const teal = Color(0xFF05B99C);
  static const purple = Color(0xFF8956EF);
  static const background = Color(0xFFF3F6FD);
  static const muted = Color(0xFF677892);
}

class BmLogo extends StatelessWidget {
  const BmLogo({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    height: size, width: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(colors: [BmColors.cyan, BmColors.blue, BmColors.purple]),
      boxShadow: [BoxShadow(color: BmColors.blue.withValues(alpha: .25),
        blurRadius: 17, offset: const Offset(0, 8))],
    ),
    child: Icon(Icons.apartment_rounded, color: Colors.white, size: size * .55),
  );
}

class BmSoftCard extends StatelessWidget {
  const BmSoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(21),
      border: Border.all(color: const Color(0xFFE4EBF9)),
      boxShadow: [BoxShadow(
        color: BmColors.navy.withValues(alpha: .07),
        blurRadius: 22, offset: const Offset(0, 9))],
    ),
    child: child,
  );
}

class BmPrimaryButton extends StatelessWidget {
  const BmPrimaryButton({super.key, required this.label, required this.onPressed,
    this.icon = Icons.arrow_forward_rounded});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .5 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [BmColors.cyan, BmColors.blue]),
        boxShadow: [BoxShadow(color: BmColors.blue.withValues(alpha: .25),
          blurRadius: 16, offset: const Offset(0, 8))]),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: onPressed, borderRadius: BorderRadius.circular(16),
        child: SizedBox(height: 52, child: Row(
          mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 9),
            Icon(icon, color: Colors.white),
          ],
        )),
      )),
    ),
  );
}

class BmSlideRoute<T> extends PageRouteBuilder<T> {
  BmSlideRoute({required Widget page}) : super(
    transitionDuration: const Duration(milliseconds: 330),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(.08, .015), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
    ),
  );
}

class BmDashboard extends StatefulWidget {
  const BmDashboard({super.key, required this.api, required this.profile,
    required this.projectId, required this.modules, required this.onModule,
    required this.onAttendance, required this.onProject, required this.onLogout,
    required this.biometricsEnabled, required this.onBiometricsChanged});
  final ApiClient api;
  final Map<String, dynamic> profile;
  final int? projectId;
  final List<ModuleLink> modules;
  final ValueChanged<ModuleLink> onModule;
  final VoidCallback onAttendance;
  final ValueChanged<int?> onProject;
  final VoidCallback onLogout;
  final bool biometricsEnabled;
  final Future<void> Function(bool) onBiometricsChanged;

  @override
  State<BmDashboard> createState() => _BmDashboardState();
}

class _BmDashboardState extends State<BmDashboard> {
  final shell = GlobalKey<ScaffoldState>();
  Future<Map<String, dynamic>>? summary;
  Future<Map<String, dynamic>>? today;
  @override
  void initState() { super.initState(); reload(); }
  @override
  void didUpdateWidget(covariant BmDashboard old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId) reload();
  }
  void reload() {
    if (widget.projectId == null) return;
    summary = widget.api.call('GET', 'dashboard',
      query: {'project_id': widget.projectId.toString()});
    today = widget.api.call('GET', 'attendance/staff/today',
      query: {'project_id': widget.projectId.toString()});
    if (mounted) setState(() {});
  }
  ModuleLink? module(String route) {
    for (final item in widget.modules) {
      if (item.route == route) return item;
    }
    return null;
  }
  void open(ModuleLink? target) {
    if (target != null) widget.onModule(target);
  }
  void settings() => Navigator.of(context).push(BmSlideRoute<void>(
    page: BmSettings(enabled: widget.biometricsEnabled,
      onChanged: widget.onBiometricsChanged)));

  @override
  Widget build(BuildContext context) {
    final user = objectOf(widget.profile['user']);
    final name = user['name']?.toString() ?? 'Employee';
    final roles = listOf(widget.profile['role_names']).join(' · ');
    final projects = listOf(widget.profile['projects']).map(objectOf)
      .where((p) => numberOf(p['id']) != null).toList();
    final current = projects.where((p) => numberOf(p['id']) == widget.projectId).toList();
    final projectName = current.isEmpty
        ? 'Select project' : current.first['name']?.toString() ?? 'Project';

    return Scaffold(
      key: shell, backgroundColor: BmColors.background,
      drawer: Drawer(
        backgroundColor: Colors.white, width: 294,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(26))),
        child: SafeArea(child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [BmColors.navy, BmColors.blue]),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(26))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const BmLogo(size: 44),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close menu', onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 18),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 21,
                  fontWeight: FontWeight.w800)),
              Text(roles, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.all(10), children: [
            _drawerItem(Icons.dashboard_rounded, 'Dashboard', () => Navigator.pop(context),
              selected: true),
            _drawerItem(Icons.access_time_rounded, 'Attendance', () {
              Navigator.pop(context); widget.onAttendance();
            }),
            for (final item in widget.modules)
              _drawerItem(item.icon, item.title, () {
                Navigator.pop(context); widget.onModule(item);
              }),
            const Divider(height: 28),
            _drawerItem(Icons.settings_rounded, 'Settings', () {
              Navigator.pop(context); settings();
            }),
            _drawerItem(Icons.logout_rounded, 'Logout', () {
              Navigator.pop(context); widget.onLogout();
            }, danger: true),
          ])),
          const Padding(padding: EdgeInsets.all(14),
            child: Text('BlueMarketing · Employee Workspace',
              style: TextStyle(fontSize: 11, color: BmColors.muted))),
        ]))),
      ),
      bottomNavigationBar: SafeArea(top: false, child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
        color: Colors.white, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _bottom(Icons.space_dashboard_rounded, 'Home', () {}, active: true),
            _bottom(Icons.people_alt_rounded, 'CRM',
              () => open(module('crm/leads'))),
            _bottom(Icons.event_available_rounded, 'Attendance', widget.onAttendance),
            _bottom(Icons.menu_rounded, 'Menu',
              () => shell.currentState?.openDrawer()),
          ],
        ),
      )),
      body: SafeArea(bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            reload();
            try {
              await Future.wait([
                if (summary != null) summary!,
                if (today != null) today!,
              ]);
            } catch (_) { /* individual API cards surface errors */ }
          },
          child: ListView(physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BmColors.navy, BmColors.blue, BmColors.cyan],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Open menu', onPressed: () => shell.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu_rounded, color: Colors.white)),
                    const BmLogo(size: 36),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('BlueMarketing',
                      style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 17))),
                    IconButton(onPressed: settings, tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined, color: Colors.white)),
                  ]),
                  const SizedBox(height: 15),
                  Row(children: [
                    CircleAvatar(radius: 26,
                      backgroundColor: Colors.white24,
                      child: Text(_initials(name), style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back', style: TextStyle(color: Colors.white70)),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                            fontSize: 24, fontWeight: FontWeight.w800)),
                        Text(roles, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                  ]),
                  const SizedBox(height: 19),
                  Material(color: Colors.white24, borderRadius: BorderRadius.circular(14),
                    child: PopupMenuButton<int>(
                      enabled: projects.length > 1,
                      tooltip: 'Switch project',
                      onSelected: widget.onProject,
                      itemBuilder: (_) => projects.map((p) =>
                        PopupMenuItem<int>(value: numberOf(p['id']),
                          child: Text("${p['name'] ?? 'Project'}"))).toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                        child: Row(children: [
                          const Icon(Icons.apartment, size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(projectName,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700))),
                          if (projects.length > 1)
                            const Icon(Icons.expand_more, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(17),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _heading('Performance snapshot'),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: summary,
                    builder: (context, snapshot) {
                      final crm = objectOf(objectOf(snapshot.data?['data'])['crm']);
                      return Column(children: [
                        Row(children: [
                          Expanded(child: _stat('Projects', '${projects.length}',
                            Icons.apartment_rounded, BmColors.blue)),
                          const SizedBox(width: 11),
                          Expanded(child: _stat('CRM leads',
                            crm['total_leads']?.toString() ?? '—',
                            Icons.people_alt_rounded, BmColors.cyan)),
                        ]),
                        const SizedBox(height: 11),
                        Row(children: [
                          Expanded(child: _stat('Follow-ups today',
                            crm['today_followups']?.toString() ?? '—',
                            Icons.event_available_rounded, BmColors.teal)),
                          const SizedBox(width: 11),
                          Expanded(child: _stat('Your modules',
                            '${widget.modules.length}',
                            Icons.widgets_rounded, BmColors.purple)),
                        ]),
                        if (snapshot.hasError)
                          const Padding(padding: EdgeInsets.only(top: 8),
                            child: Text('Statistics unavailable. Pull down to retry.',
                              style: TextStyle(color: BmColors.muted))),
                      ]);
                    },
                  ),
                  const SizedBox(height: 23),
                  _heading('Quick actions'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _quick(Icons.groups_2_outlined, 'CRM', BmColors.blue,
                      () => open(module('crm/leads')))),
                    const SizedBox(width: 9),
                    Expanded(child: _quick(Icons.how_to_reg_outlined, 'Check in',
                      BmColors.teal, widget.onAttendance)),
                    const SizedBox(width: 9),
                    Expanded(child: _quick(Icons.inventory_2_outlined, 'Stock',
                      BmColors.purple, () => open(module('stock/entries')))),
                    const SizedBox(width: 9),
                    Expanded(child: _quick(Icons.bar_chart_rounded, 'Reports',
                      BmColors.cyan, () => open(module('reports/projects')))),
                  ]),
                  const SizedBox(height: 23),
                  _heading('Today’s attendance'),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: today,
                    builder: (context, snapshot) {
                      final data = objectOf(snapshot.data?['data']);
                      return BmSoftCard(child: Row(children: [
                        Container(height: 53, width: 53,
                          decoration: BoxDecoration(
                            color: BmColors.teal.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.verified_rounded,
                            color: BmColors.teal, size: 30)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(snapshot.hasError ? 'Attendance unavailable'
                                : data['status']?.toString() ?? 'Loading…',
                              style: const TextStyle(fontWeight: FontWeight.w800,
                                color: BmColors.navy, fontSize: 15)),
                            const SizedBox(height: 5),
                            Text(data.isEmpty ? 'View your attendance' :
                              "In: ${data['check_in_time'] ?? '—'}  Out: ${data['check_out_time'] ?? '—'}",
                              style: const TextStyle(color: BmColors.muted, fontSize: 11)),
                          ])),
                        IconButton(icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: widget.onAttendance),
                      ]));
                    },
                  ),
                  const SizedBox(height: 23),
                  Row(children: [
                    Expanded(child: _heading('Explore modules')),
                    TextButton(onPressed: () => shell.currentState?.openDrawer(),
                      child: const Text('See all')),
                  ]),
                  const SizedBox(height: 10),
                  for (final item in widget.modules.take(4))
                    Padding(padding: const EdgeInsets.only(bottom: 10),
                      child: BmSoftCard(padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: BmColors.blue.withValues(alpha: .1),
                            child: Icon(item.icon, color: BmColors.blue)),
                          title: Text(item.title, style: const TextStyle(
                            fontWeight: FontWeight.w700, color: BmColors.navy)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => open(item),
                        )),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Text(text, style: const TextStyle(
    color: BmColors.navy, fontWeight: FontWeight.w800, fontSize: 19));

  Widget _stat(String title, String count, IconData icon, Color color) =>
    TweenAnimationBuilder<double>(
      tween: Tween(begin: .94, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
        Transform.scale(scale: value, child: child),
      child: Container(
        height: 111, padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color, Color.lerp(color, BmColors.navy, .27)!]),
          borderRadius: BorderRadius.circular(21),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .27),
            blurRadius: 19, offset: const Offset(0, 10))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: Colors.white, size: 22),
            const Spacer(),
            Text(count, style: const TextStyle(color: Colors.white,
              fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
          const Spacer(),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

  Widget _quick(IconData icon, String label, Color color, VoidCallback action) =>
    BmSoftCard(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
      child: InkWell(onTap: action, child: Column(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color)),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ])));

  Widget _drawerItem(IconData icon, String title, VoidCallback action,
      {bool selected = false, bool danger = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(color: selected ? const Color(0xFFE7EDFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: ListTile(
          dense: true, leading: Icon(icon,
            color: danger ? Colors.red : (selected ? BmColors.blue : BmColors.navy)),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: danger ? Colors.red : BmColors.navy,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          onTap: action,
        ),
      ));

  Widget _bottom(IconData icon, String title, VoidCallback action, {bool active = false}) =>
    InkWell(onTap: action, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? BmColors.blue : BmColors.muted),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? BmColors.blue : BmColors.muted)),
        ])));
}

class BmSettings extends StatefulWidget {
  const BmSettings({super.key, required this.enabled, required this.onChanged});
  final bool enabled;
  final Future<void> Function(bool) onChanged;
  @override
  State<BmSettings> createState() => _BmSettingsState();
}

class _BmSettingsState extends State<BmSettings> {
  late bool enabled = widget.enabled;
  bool busy = false;
  Future<void> update(bool next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onChanged(next);
      if (mounted) setState(() => enabled = next);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const SizedBox(height: 12),
      const Text('Security & sign in', style: TextStyle(
        color: BmColors.navy, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      BmSoftCard(child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.fingerprint_rounded, color: BmColors.purple, size: 32),
        title: const Text('Fingerprint / Face unlock',
          style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text(
          'When enabled, biometrics will be requested when you open the app. '
          'Only you can turn this setting off.'),
        value: enabled, onChanged: busy ? null : update,
      )),
      const SizedBox(height: 14),
      const BmSoftCard(child: Row(children: [
        Icon(Icons.lock_outline_rounded, color: BmColors.teal),
        SizedBox(width: 12),
        Expanded(child: Text('Your password is never saved. '
          'Only your secure login session is remembered.',
          style: TextStyle(color: BmColors.muted))),
      ])),
    ]),
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'BM';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
}
