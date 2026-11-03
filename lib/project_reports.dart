import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class ProjectReportsHome extends StatelessWidget {
  const ProjectReportsHome({super.key, required this.api,
    required this.projectId, required this.permissions});
  final ApiClient api;
  final int projectId;
  final Set<String> permissions;

  void open(BuildContext context, String title, String suffix,
      {bool pagination = true}) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => ProjectReportList(api: api, projectId: projectId,
        title: title, suffix: suffix, pagination: pagination),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project reports')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: const Text('Project summary'),
        onTap: () => open(context, 'Project summary', '', pagination: false),
      )),
      if (permissions.contains('read plot'))
        Card(child: ListTile(
          leading: const Icon(Icons.grid_on_outlined),
          title: const Text('Plots'),
          onTap: () => open(context, 'Project plots', '/plots'),
        )),
      if (permissions.contains('read booking'))
        for (final item in const [
          ('Bookings', '/bookings', Icons.description_outlined),
          ('Recovery', '/recovery', Icons.payments_outlined),
          ('Customers', '/customers', Icons.people_outline),
        ])
          Card(child: ListTile(
            leading: Icon(item.$3),
            title: Text(item.$1),
            onTap: () => open(context, item.$1, item.$2),
          )),
    ]),
  );
}

class ProjectReportList extends StatefulWidget {
  const ProjectReportList({super.key, required this.api, required this.projectId,
    required this.title, required this.suffix, required this.pagination});
  final ApiClient api;
  final int projectId;
  final String title;
  final String suffix;
  final bool pagination;
  @override
  State<ProjectReportList> createState() => _ProjectReportListState();
}

class _ProjectReportListState extends State<ProjectReportList> {
  final search = TextEditingController();
  int page = 1;
  String status = 'all';
  DateTime? from;
  DateTime? to;
  Future<Map<String, dynamic>>? current;
  bool get hasDates => widget.suffix == '/bookings' ||
      widget.suffix == '/recovery';
  bool get hasSearch => widget.suffix != '' && widget.suffix != '/recovery';

  @override
  void initState() { super.initState(); reload(); }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  void reload({bool reset = false}) {
    if (reset) page = 1;
    final path = 'reports/projects/${widget.projectId}${widget.suffix}';
    current = widget.api.call('GET', path, query: widget.pagination ? {
      'page': '$page', 'per_page': '20',
      if (hasSearch && search.text.trim().isNotEmpty)
        'search': search.text.trim(),
      if (widget.suffix == '/plots' && status != 'all') 'status': status,
      if (from != null) 'date_from': reportDate(from!),
      if (to != null) 'date_to': reportDate(to!),
    } : null);
    if (mounted) setState(() {});
  }

  Future<void> pickRange() async {
    final range = await showDateRangePicker(
      context: context, firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from!, end: to!) : null,
    );
    if (range != null) {
      setState(() { from = range.start; to = range.end; });
      reload(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(children: [
      if (hasSearch) Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => reload(reset: true),
          decoration: InputDecoration(
            labelText: 'Search',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
              onPressed: () => reload(reset: true)),
          ),
        ),
      ),
      if (widget.suffix == '/plots')
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Plot status'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'available', child: Text('Available')),
              DropdownMenuItem(value: 'hold', child: Text('Hold')),
              DropdownMenuItem(value: 'sold', child: Text('Sold')),
            ],
            onChanged: (value) {
              if (value != null) { status = value; reload(reset: true); }
            },
          )),
      if (hasDates) Padding(padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(
          onPressed: pickRange,
          icon: const Icon(Icons.date_range),
          label: Text(from == null || to == null
              ? 'Filter by date' : '${reportDate(from!)} — ${reportDate(to!)}'),
        )),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: current,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final response = snapshot.data!;
          final value = response['data'];
          final structured = objectOf(value);
          final rows = widget.suffix.isEmpty
              ? structured.entries.map((entry) => <String, dynamic>{
                  'field': entry.key, 'value': entry.value,
                }).toList()
              : (value is List ? listOf(value) : listOf(structured['rows']))
                  .map(objectOf).toList();
          final meta = objectOf(response['meta']);
          final lastPage = numberOf(meta['last_page']) ?? 1;
          return Column(children: [
            if (widget.suffix == '/recovery')
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  for (final entry in objectOf(structured['summary']).entries)
                    ListTile(title: Text(entry.key.replaceAll('_', ' ')),
                      trailing: Text('${entry.value ?? '—'}')),
                ]),
              )),
            Expanded(child: RefreshIndicator(
              onRefresh: () async { reload(); await current; },
              child: ListView.builder(
                itemCount: rows.isEmpty ? 1 : rows.length,
                itemBuilder: (context, i) {
                  if (rows.isEmpty) {
                    return const ListTile(title: Text('No records found.'));
                  }
                  final row = rows[i];
                  final title = row['name'] ?? row['plot_name'] ??
                      row['booking_number'] ?? row['field'] ??
                      row['first_name'] ?? row['id'] ?? 'Record';
                  return Card(child: ExpansionTile(
                    title: Text('$title'),
                    subtitle: Text('${row['status'] ?? row['value'] ?? ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    children: [
                      for (final entry in row.entries)
                        ListTile(
                          dense: true, title: Text(entry.key.replaceAll('_', ' ')),
                          subtitle: Text(entry.value is Map || entry.value is List
                            ? 'Details are available in the server response'
                            : '${entry.value ?? '—'}'),
                        ),
                    ],
                  ));
                },
              ),
            )),
            if (widget.pagination)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                OutlinedButton(onPressed: page > 1 ? () {
                  page--; reload();
                } : null, child: const Text('Previous')),
                Text('Page $page / $lastPage'),
                OutlinedButton(onPressed: page < lastPage ? () {
                  page++; reload();
                } : null, child: const Text('Next')),
              ]),
          ]);
        },
      )),
    ]),
  );
}

String reportDate(DateTime date) =>
    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
