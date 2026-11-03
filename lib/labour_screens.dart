import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class LabourWorkspace extends StatefulWidget {
  const LabourWorkspace({super.key, required this.api, required this.projectId,
    required this.permissions, required this.roles});
  final ApiClient api;
  final int projectId;
  final Set<String> permissions;
  final Set<String> roles;
  @override
  State<LabourWorkspace> createState() => _LabourWorkspaceState();
}

class _LabourWorkspaceState extends State<LabourWorkspace> {
  final search = TextEditingController();
  int page = 1;
  String status = 'all';
  Future<Map<String, dynamic>>? current;
  bool get mayMark => widget.permissions.contains('create attendance') ||
    widget.permissions.contains('create labour') ||
    widget.roles.contains('admin') || widget.roles.contains('superadmin');

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  void load({bool reset = false}) {
    if (reset) { page = 1; }
    current = widget.api.call('GET', 'attendance/labour', query: {
      'project_id': widget.projectId.toString(), 'per_page': '20',
      'page': page.toString(),
      if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
      if (status != 'all') 'status': status,
    });
    if (mounted) { setState(() {}); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Labour attendance')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => load(reset: true),
          decoration: InputDecoration(labelText: 'Search labour',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
              onPressed: () => load(reset: true))))),
        PopupMenuButton<String>(initialValue: status,
          tooltip: 'Status', onSelected: (value) { status = value; load(reset: true); },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('All')),
            PopupMenuItem(value: 'active', child: Text('Active')),
            PopupMenuItem(value: 'inactive', child: Text('Inactive')),
          ]),
      ])),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: current,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = listOf(snap.data!['data']).map(objectOf).toList();
          final meta = objectOf(snap.data!['meta']);
          final last = numberOf(meta['last_page']) ?? 1;
          return Column(children: [
            Expanded(child: RefreshIndicator(
              onRefresh: () async { load(); await current; },
              child: ListView.builder(
                itemCount: rows.isEmpty ? 1 : rows.length,
                itemBuilder: (context, i) {
                  if (rows.isEmpty) {
                    return const ListTile(title: Text('No labour records found.'));
                  }
                  final labour = rows[i];
                  final today = objectOf(labour['today_attendance']);
                  return Card(child: ListTile(
                    title: Text(labour['name']?.toString() ?? 'Labour'),
                    subtitle: Text((labour['role']?.toString() ?? '') +
                      " · Today: ${today['status'] ?? 'Unmarked'}"),
                    trailing: mayMark ? const Icon(Icons.edit_calendar_outlined) : null,
                    onTap: mayMark && numberOf(labour['id']) != null
                      ? () async {
                          final saved = await Navigator.push<bool>(context,
                            MaterialPageRoute(builder: (_) => LabourMarkScreen(
                              api: widget.api, projectId: widget.projectId,
                              labourId: numberOf(labour['id'])!,
                              name: labour['name']?.toString() ?? 'Labour',
                              existing: today.isNotEmpty)));
                          if (saved == true) {
                            load();
                          }
                        }
                      : null,
                  ));
                },
              ),
            )),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton(onPressed: page > 1 ? () { page--; load(); } : null,
                child: const Text('Previous')),
              Text('Page $page/$last'),
              TextButton(onPressed: page < last ? () { page++; load(); } : null,
                child: const Text('Next')),
            ]),
          ]);
        },
      )),
      Padding(padding: const EdgeInsets.all(10), child: OutlinedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => LabourReportScreen(api: widget.api, projectId: widget.projectId))),
        child: const Text('Attendance report'),
      )),
    ]),
  );
}

class LabourMarkScreen extends StatefulWidget {
  const LabourMarkScreen({super.key, required this.api, required this.projectId,
    required this.labourId, required this.name, required this.existing});
  final ApiClient api;
  final int projectId;
  final int labourId;
  final String name;
  final bool existing;
  @override
  State<LabourMarkScreen> createState() => _LabourMarkScreenState();
}

class _LabourMarkScreenState extends State<LabourMarkScreen> {
  DateTime date = DateTime.now();
  String status = 'present';
  final hours = TextEditingController(text: '8');
  final notes = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() { hours.dispose(); notes.dispose(); super.dispose(); }
  String get dateValue => "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> submit() async {
    final duration = double.tryParse(hours.text);
    if (status == 'present' &&
        (duration == null || duration < 0 || duration > 24)) {
      setState(() => error = 'Hours must be between 0 and 24.');
      return;
    }
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm attendance'),
        content: Text('Record $status for ${widget.name} on $dateValue? This changes live attendance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
        ],
      )) ?? false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await widget.api.call('POST', 'attendance/labour/mark', data: {
        'project_id': widget.projectId,
        'date': dateValue,
        'records': [{
          'labour_id': widget.labourId,
          'status': status,
          if (status == 'present') 'hours': duration,
          if (notes.text.trim().isNotEmpty) 'remarks': notes.text.trim(),
        }],
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Mark ${widget.name}')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      if (widget.existing) const Card(child: ListTile(
        leading: Icon(Icons.warning_amber_outlined),
        title: Text('Already marked today'),
        subtitle: Text('Updating existing attendance needs additional server permission.'))),
      OutlinedButton.icon(onPressed: () async {
        final next = await showDatePicker(context: context,
          initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (next != null) {
          setState(() => date = next);
        }
      }, icon: const Icon(Icons.date_range), label: Text(dateValue)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: status,
        items: const [
          DropdownMenuItem(value: 'present', child: Text('Present')),
          DropdownMenuItem(value: 'absent', child: Text('Absent')),
        ],
        onChanged: (value) { if (value != null) setState(() => status = value); },
        decoration: const InputDecoration(labelText: 'Attendance status'),
      ),
      if (status == 'present') TextField(controller: hours,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Hours (0–24)')),
      const SizedBox(height: 14),
      TextField(controller: notes, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Remarks (optional)')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : submit,
        child: Text(saving ? 'Saving...' : 'Record attendance')),
    ]),
  );
}

class LabourReportScreen extends StatelessWidget {
  const LabourReportScreen({super.key, required this.api, required this.projectId});
  final ApiClient api;
  final int projectId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Labour report')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: api.call('GET', 'attendance/labour/report',
        query: {'project_id': projectId.toString()}),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(snap.error.toString()));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!['data'];
        final rows = data is List ? listOf(data).map(objectOf).toList()
          : listOf(objectOf(data)['rows']).map(objectOf).toList();
        if (rows.isEmpty) {
          return const Center(child: Text('No labour report data.'));
        }
        return ListView(children: [
          for (final item in rows)
            Card(child: ListTile(
              title: Text(item['labour_name']?.toString() ?? 'Labour'),
              subtitle: Text("Present days: ${item['present_days'] ?? '—'}"),
              trailing: Text(item['total_amount']?.toString() ?? '—'),
            )),
        ]);
      },
    ),
  );
}
