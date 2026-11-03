import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class LabourPaymentReport extends StatefulWidget {
  const LabourPaymentReport({super.key, required this.api,
    required this.projectId});
  final ApiClient api;
  final int projectId;
  @override
  State<LabourPaymentReport> createState() => _LabourPaymentReportState();
}

class _LabourPaymentReportState extends State<LabourPaymentReport> {
  late DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  Future<Map<String, dynamic>>? pending;

  String dateValue(DateTime d) =>
    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void load() {
    pending = widget.api.call('GET', 'attendance/labour/payment-summary',
      query: {
        'project_id': widget.projectId.toString(),
        'date_from': dateValue(from),
        'date_to': dateValue(to),
      });
    if (mounted) setState(() {});
  }

  Future<void> pickDates() async {
    final range = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to));
    if (range != null) {
      from = range.start;
      to = range.end;
      load();
    }
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Labour payment summary')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: pickDates,
          icon: const Icon(Icons.date_range),
          label: Text('${dateValue(from)} — ${dateValue(to)}'),
        )),
      const Card(child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Read-only payment summary'),
        subtitle: Text('Only unpaid eligible attendance is included by the server.'),
      )),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: pending,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!['data'];
          final map = objectOf(data);
          final rows = data is List ? listOf(data).map(objectOf).toList()
              : listOf(map['rows']).map(objectOf).toList();
          return ListView(children: [
            for (final entry in map.entries)
              if (entry.value is! List && entry.value is! Map)
                ListTile(title: Text(entry.key.replaceAll('_', ' ')),
                  trailing: Text('${entry.value ?? '—'}')),
            for (final row in rows)
              Card(child: ExpansionTile(
                title: Text('${row['labour_name'] ?? row['name'] ?? 'Labour'}'),
                children: [
                  for (final entry in row.entries)
                    ListTile(dense: true,
                      title: Text(entry.key.replaceAll('_', ' ')),
                      trailing: Text('${entry.value ?? '—'}')),
                ],
              )),
            if (rows.isEmpty && map.isEmpty)
              const ListTile(title: Text('No eligible payments found.')),
          ]);
        },
      )),
    ]),
  );
}
