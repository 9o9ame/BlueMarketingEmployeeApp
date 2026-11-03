import 'package:flutter/material.dart';
import 'live_employee_app.dart';

/// Mark a selected group of labourers for one date. No automatic submission:
/// user must review each selected status and confirm the server write.
class LabourBulkMark extends StatefulWidget {
  const LabourBulkMark({super.key, required this.api, required this.projectId});
  final ApiClient api;
  final int projectId;
  @override
  State<LabourBulkMark> createState() => _LabourBulkMarkState();
}

class _LabourBulkMarkState extends State<LabourBulkMark> {
  Future<Map<String, dynamic>>? labour;
  final selections = <int, String>{};
  DateTime date = DateTime.now();
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    labour = widget.api.call('GET', 'attendance/labour', query: {
      'project_id': widget.projectId.toString(),
      'status': 'active',
      'per_page': '100',
    });
  }

  Future<void> submit() async {
    if (selections.isEmpty) {
      setState(() => error = 'Select at least one labourer.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm bulk attendance'),
        content: Text('Submit attendance for ${selections.length} selected workers '
          'on ${bulkDate(date)}? Existing entries may require update permission.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Submit')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.api.call('POST', 'attendance/labour/mark', data: {
        'project_id': widget.projectId,
        'date': bulkDate(date),
        'records': selections.entries.map((entry) => {
          'labour_id': entry.key,
          'status': entry.value,
          if (entry.value == 'present') 'hours': 8,
        }).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bulk labour attendance')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: labour,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = listOf(snapshot.data!['data']).map(objectOf).toList();
        final meta = objectOf(snapshot.data!['meta']);
        final more = (numberOf(meta['last_page']) ?? 1) > 1;
        return Column(children: [
          ListTile(
            title: const Text('Attendance date'),
            subtitle: Text(bulkDate(date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final next = await showDatePicker(
                context: context, initialDate: date,
                firstDate: DateTime(2020), lastDate: DateTime(2100),
              );
              if (next != null) setState(() => date = next);
            },
          ),
          if (more) const Card(child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Only the first 100 workers are shown'),
            subtitle: Text('Additional workers require separate page selection; '
              'this form cannot silently mark unseen workers.'),
          )),
          Expanded(child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final worker = rows[index];
              final id = numberOf(worker['id']);
              if (id == null) return const SizedBox.shrink();
              return Card(child: Column(children: [
                ListTile(
                  title: Text('${worker['name'] ?? 'Worker'}'),
                  subtitle: Text('${worker['role'] ?? ''}'),
                  trailing: selections.containsKey(id)
                    ? const Icon(Icons.check_circle, color: Colors.green) : null,
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text('Present'),
                      selected: selections[id] == 'present',
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selections[id] = 'present';
                        } else {
                          selections.remove(id);
                        }
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Absent'),
                      selected: selections[id] == 'absent',
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selections[id] = 'absent';
                        } else {
                          selections.remove(id);
                        }
                      }),
                    ),
                    TextButton(onPressed: () => setState(() {
                      selections.remove(id);
                    }), child: const Text('Clear')),
                  ],
                ),
              ]));
            },
          )),
          if (error != null) Text(error!,
              style: const TextStyle(color: Colors.red)),
          Padding(padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: saving ? null : submit,
              child: Text(saving ? 'Saving...' :
                'Submit ${selections.length} selected attendance records'),
            )),
        ]);
      },
    ),
  );
}

String bulkDate(DateTime date) =>
    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
