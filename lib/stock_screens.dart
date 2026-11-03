import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class StockWorkspace extends StatelessWidget {
  const StockWorkspace({super.key, required this.api, required this.projectId});
  final ApiClient api;
  final int projectId;

  void open(BuildContext context, String path, String title) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      StockRecords(api: api, projectId: projectId, path: path, title: title)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock workspace')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: ListTile(leading: Icon(Icons.info_outline),
        title: Text('Company-wide stock'),
        subtitle: Text('Backend stock balances and movements are global, not per-project.'))),
      for (final item in const [
        ('stock/items', 'Stock items', Icons.inventory_2_outlined),
        ('stock/parties', 'Suppliers and consumers', Icons.groups_outlined),
        ('stock/entries', 'Stock movements', Icons.receipt_long_outlined),
        ('stock/report', 'Stock report', Icons.bar_chart_outlined),
      ])
        Card(child: ListTile(leading: Icon(item.$3), title: Text(item.$2),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(context, item.$1, item.$2))),
    ]),
  );
}

class StockRecords extends StatefulWidget {
  const StockRecords({super.key, required this.api, required this.projectId,
    required this.path, required this.title});
  final ApiClient api;
  final int projectId;
  final String path;
  final String title;
  @override
  State<StockRecords> createState() => _StockRecordsState();
}

class _StockRecordsState extends State<StockRecords> {
  final search = TextEditingController();
  int page = 1;
  String flow = 'all';
  Future<Map<String, dynamic>>? result;
  bool get isReport => widget.path == 'stock/report';

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  void load({bool reset = false}) {
    if (reset) { page = 1; }
    result = widget.api.call('GET', widget.path, query: {
      if (widget.path != 'stock/items' && widget.path != 'stock/parties')
        'project_id': widget.projectId.toString(),
      if (!isReport) ...{
        'page': page.toString(), 'per_page': '20',
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
      },
      if (widget.path == 'stock/entries' && flow != 'all') 'flow': flow,
    });
    if (mounted) { setState(() {}); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(children: [
      if (isReport) const Card(child: ListTile(
        leading: Icon(Icons.warning_amber_outlined),
        title: Text('Global inventory report'),
        subtitle: Text('Amounts are not scoped to this project.'))),
      if (!isReport) Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: TextField(controller: search,
            onSubmitted: (_) => load(reset: true),
            decoration: InputDecoration(labelText: 'Search',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
                onPressed: () => load(reset: true))))),
          if (widget.path == 'stock/entries')
            PopupMenuButton<String>(tooltip: 'Movement type', initialValue: flow,
              onSelected: (value) { flow = value; load(reset: true); },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('All')),
                PopupMenuItem(value: 'IN', child: Text('IN')),
                PopupMenuItem(value: 'OUT', child: Text('OUT')),
              ]),
        ])),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: result,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!['data'];
          final meta = objectOf(snap.data!['meta']);
          final report = objectOf(data);
          final rows = (isReport ? listOf(report['rows']) : listOf(data))
              .map(objectOf).toList();
          final last = numberOf(meta['last_page']) ?? 1;
          return Column(children: [
            if (isReport)
              Padding(padding: const EdgeInsets.all(12), child:
                Text('Items: '+ (objectOf(report['kpi'])['items']?.toString() ?? '0'))),
            Expanded(child: RefreshIndicator(
              onRefresh: () async { load(); await result; },
              child: ListView.builder(
                itemCount: rows.isEmpty ? 1 : rows.length,
                itemBuilder: (context, index) {
                  if (rows.isEmpty) {
                    return const ListTile(title: Text('No records found.'));
                  }
                  final row = rows[index];
                  final isEntry = widget.path == 'stock/entries';
                  final title = isEntry ? row['slip_no'] : row['name'] ?? row['item_name'];
                  final details = isEntry
                    ? (row['flow']?.toString() ?? '') + ' · ' +
                      (objectOf(row['item'])['name']?.toString() ?? '') +
                      ' · Qty ' + (row['qty']?.toString() ?? '—')
                    : isReport
                      ? 'Available: ' + (row['available_qty']?.toString() ?? '—')
                      : widget.path == 'stock/items'
                        ? 'On hand: ' + (row['available_qty']?.toString() ?? '—') +
                          ' ' + (row['unit']?.toString() ?? '')
                        : (row['type']?.toString() ?? '') + ' · ' +
                          (row['mobile']?.toString() ?? '');
                  return Card(child: ListTile(
                    title: Text(title?.toString() ?? 'Record'),
                    subtitle: Text(details),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                      builder: (_) => StockDetail(api: widget.api, projectId: widget.projectId,
                        entryId: isEntry ? numberOf(row['id']) : null,
                        fallback: row))),
                  ));
                },
              ),
            )),
            if (!isReport) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: page > 1 ? () { page--; load(); } : null,
                  child: const Text('Previous')),
                Text('Page ' + page.toString() + ' / ' + last.toString()),
                TextButton(onPressed: page < last ? () { page++; load(); } : null,
                  child: const Text('Next')),
              ]),
          ]);
        },
      )),
    ]),
  );
}

class StockDetail extends StatelessWidget {
  const StockDetail({super.key, required this.api, required this.projectId,
    required this.entryId, required this.fallback});
  final ApiClient api;
  final int projectId;
  final int? entryId;
  final Map<String, dynamic> fallback;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock detail')),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: entryId == null ? Future.value(null) : api.call('GET',
        'stock/entries/' + entryId.toString(),
        query: {'project_id': projectId.toString()}),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(snap.error.toString()));
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final details = entryId == null ? fallback : objectOf(snap.data?['data']);
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final item in details.entries)
            ListTile(title: Text(item.key.replaceAll('_', ' ')),
              subtitle: Text(item.value?.toString() ?? '—')),
        ]);
      },
    ),
  );
}
