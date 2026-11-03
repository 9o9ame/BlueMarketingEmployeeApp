import 'package:flutter/material.dart';
import 'live_employee_app.dart';
import 'premium_design.dart';

String displayLeadName(Map<String, dynamic> lead) =>
    [lead['first_name'], lead['last_name']].where((v) => v != null)
        .map((v) => v.toString()).join(' ');

String? validateMobile(String? text) {
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return RegExp(r'^[0-9]{11}$').hasMatch(text.trim()) ? null : 'Use 11 digits';
}

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key, required this.api, required this.projectId,
    required this.permissions});
  final ApiClient api;
  final int projectId;
  final Set<String> permissions;
  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final search = TextEditingController();
  Future<Map<String, dynamic>>? data;
  int page = 1;
  String status = 'all';
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  void load({bool reset = false}) {
    if (reset) {
      page = 1;
    }
    data = widget.api.call('GET', 'crm/leads', query: {
      'project_id': widget.projectId.toString(), 'page': page.toString(),
      'per_page': '20', 'sort_by': 'follow_up',
      if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
      if (status != 'all') 'status': status,
    });
    if (mounted) {
      setState(() {});
    }
  }
  Future<void> create() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => LeadForm(api: widget.api, projectId: widget.projectId),
    ));
    if (saved == true) {
      load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('CRM Leads')),
    floatingActionButton: widget.permissions.contains('create lead')
        ? FloatingActionButton.extended(onPressed: create,
            icon: const Icon(Icons.add), label: const Text('New lead')) : null,
    body: Column(children: [
      const BmModuleHero(title: 'CRM & Leads',
        subtitle: 'Manage leads, follow-ups and your project pipeline',
        icon: Icons.people_alt_rounded, accent: BmColors.blue),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => load(reset: true),
          decoration: InputDecoration(
            labelText: 'Search name or phone', prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
                onPressed: () => load(reset: true)),
          ),
        )),
        PopupMenuButton<String>(
          tooltip: 'Lead status',
          initialValue: status,
          onSelected: (v) { status = v; load(reset: true); },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('All')),
            PopupMenuItem(value: 'active', child: Text('Active')),
            PopupMenuItem(value: 'inactive', child: Text('Inactive')),
          ],
        ),
      ])),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Problem(message: snap.error.toString(), retry: load);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final leads = listOf(snap.data!['data']).map(objectOf).toList();
          final meta = objectOf(snap.data!['meta']);
          final last = numberOf(meta['last_page']) ?? 1;
          return Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Total ${meta['total'] ?? leads.length} · Page $page/$last")),
            Expanded(child: RefreshIndicator(
              onRefresh: () async { load(); await data; },
              child: ListView.builder(
                itemCount: leads.isEmpty ? 1 : leads.length,
                itemBuilder: (context, index) {
                  if (leads.isEmpty) {
                    return const ListTile(title: Text('No leads found.'));
                  }
                  final lead = leads[index];
                  final id = numberOf(lead['id']);
                  return Card(child: ListTile(
                    title: Text(displayLeadName(lead)),
                    subtitle: Text("${lead['phone_number'] ?? ''} · ${lead['follow_up'] ?? 'No follow-up'}"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: id == null ? null : () async {
                      await Navigator.push<void>(context, MaterialPageRoute(
                        builder: (_) => LeadDetail(api: widget.api, id: id,
                          projectId: widget.projectId,
                          permissions: widget.permissions),
                      ));
                      load();
                    },
                  ));
                },
              ),
            )),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              OutlinedButton(onPressed: page > 1 ? () { page--; load(); } : null,
                child: const Text('Previous')),
              OutlinedButton(onPressed: page < last ? () { page++; load(); } : null,
                child: const Text('Next')),
            ]),
          ]);
        },
      )),
    ]),
  );
}

class LeadDetail extends StatefulWidget {
  const LeadDetail({super.key, required this.api, required this.id,
    required this.projectId, required this.permissions});
  final ApiClient api;
  final int id;
  final int projectId;
  final Set<String> permissions;
  @override
  State<LeadDetail> createState() => _LeadDetailState();
}
class _LeadDetailState extends State<LeadDetail> {
  Future<Map<String, dynamic>>? data;
  @override
  void initState() { super.initState(); load(); }
  void load() {
    data = widget.api.call('GET', 'crm/leads/${widget.id}');
    if (mounted) {
      setState(() {});
    }
  }
  Future<void> form(Map<String, dynamic> lead, {bool followUp = false}) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => followUp
          ? FollowUpForm(api: widget.api, id: widget.id)
          : LeadForm(api: widget.api, projectId: widget.projectId, lead: lead),
    ));
    if (saved == true) {
      load();
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lead details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Problem(message: snap.error.toString(), retry: load);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lead = objectOf(snap.data!['data']);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(displayLeadName(lead), style: Theme.of(context).textTheme.headlineSmall),
          for (final key in ['phone_number', 'mobile_number', 'status',
              'follow_up', 'nic_number_masked', 'remarks'])
            ListTile(title: Text(key.replaceAll('_', ' ')),
              subtitle: Text(lead[key]?.toString() ?? '—')),
          if (widget.permissions.contains('update lead')) ...[
            FilledButton(onPressed: () => form(lead, followUp: true),
              child: const Text('Record follow-up')),
            OutlinedButton(onPressed: () => form(lead),
              child: const Text('Edit lead')),
          ],
          TextButton.icon(
            icon: const Icon(Icons.history), label: const Text('Activity history'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => LeadHistory(api: widget.api, id: widget.id),
            )),
          ),
        ]);
      },
    ),
  );
}

class LeadHistory extends StatelessWidget {
  const LeadHistory({super.key, required this.api, required this.id});
  final ApiClient api;
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lead activity')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: api.call('GET', 'crm/leads/$id/history'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(snap.error.toString()));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = listOf(snap.data!['data']).map(objectOf).toList();
        if (items.isEmpty) {
          return const Center(child: Text('No history found.'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => Card(child: ListTile(
            title: Text(items[i]['comment']?.toString() ?? 'Activity'),
            subtitle: Text(items[i]['created_at']?.toString() ?? ''),
          )),
        );
      },
    ),
  );
}

class LeadForm extends StatefulWidget {
  const LeadForm({super.key, required this.api, required this.projectId, this.lead});
  final ApiClient api;
  final int projectId;
  final Map<String, dynamic>? lead;
  @override
  State<LeadForm> createState() => _LeadFormState();
}
class _LeadFormState extends State<LeadForm> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final key in ['first_name', 'last_name', 'phone_number', 'mobile_number', 'remarks'])
      key: TextEditingController(text: widget.lead?[key]?.toString() ?? ''),
  };
  DateTime? followUp;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) { field.dispose(); }
    super.dispose();
  }
  Future<void> pickDate() async {
    final d = await showDatePicker(context: context,
      initialDate: followUp ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) {
      setState(() => followUp = d);
    }
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    if (!await confirmChange(context, widget.lead == null
        ? 'Create this lead?' : 'Update this lead?')) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() { busy = true; error = null; });
    final body = <String, dynamic>{
      'first_name': fields['first_name']!.text.trim(),
      'last_name': fields['last_name']!.text.trim(),
      'phone_number': fields['phone_number']!.text.trim(),
      if (widget.lead == null) 'project_id': widget.projectId,
      if (fields['mobile_number']!.text.trim().isNotEmpty)
        'mobile_number': fields['mobile_number']!.text.trim(),
      if (fields['remarks']!.text.trim().isNotEmpty)
        'remarks': fields['remarks']!.text.trim(),
      if (followUp != null) 'follow_up': isoDate(followUp!),
    };
    try {
      final id = numberOf(widget.lead?['id']);
      await widget.api.call(id == null ? 'POST' : 'PUT',
        id == null ? 'crm/leads' : 'crm/leads/$id', data: body);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }
  Widget entry(String key, String label, {bool required = false, int? length}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextFormField(
        controller: fields[key], maxLength: length,
        maxLines: key == 'remarks' ? 3 : 1,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value?.trim().isEmpty ?? true)) {
            return 'Required';
          }
          if (key == 'mobile_number') {
            return validateMobile(value);
          }
          return null;
        },
      ),
    );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.lead == null ? 'New lead' : 'Edit lead')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(18), children: [
      entry('first_name', 'First name', required: true, length: 25),
      entry('last_name', 'Last name', required: true, length: 25),
      entry('phone_number', 'Phone', required: true, length: 25),
      entry('mobile_number', 'Mobile (optional)', length: 11),
      entry('remarks', 'Remarks'),
      OutlinedButton(onPressed: pickDate, child: Text(followUp == null
        ? 'Select follow-up date' : isoDate(followUp!))),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      FilledButton(onPressed: busy ? null : save,
        child: Text(busy ? 'Saving...' : 'Save lead')),
    ])),
  );
}

class FollowUpForm extends StatefulWidget {
  const FollowUpForm({super.key, required this.api, required this.id});
  final ApiClient api;
  final int id;
  @override
  State<FollowUpForm> createState() => _FollowUpFormState();
}
class _FollowUpFormState extends State<FollowUpForm> {
  DateTime date = DateTime.now();
  final notes = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() { notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!await confirmChange(context, 'Record this follow-up?')) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await widget.api.call('POST', 'crm/leads/${widget.id}/follow-up',
        data: {'follow_up_date': isoDate(date),
          if (notes.text.trim().isNotEmpty) 'remarks': notes.text.trim(),
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
        setState(() => busy = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Follow-up')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.date_range), label: Text(isoDate(date)),
        onPressed: () async {
          final d = await showDatePicker(context: context,
            initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) {
            setState(() => date = d);
          }
        },
      ),
      TextField(controller: notes, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Remarks')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : save,
        child: Text(busy ? 'Saving...' : 'Save follow-up')),
    ]),
  );
}

String isoDate(DateTime date) => [date.year.toString(),
  date.month.toString().padLeft(2, '0'),
  date.day.toString().padLeft(2, '0')].join('-');

Future<bool> confirmChange(BuildContext context, String question) async =>
  await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Confirm'),
    content: Text(question),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true),
        child: const Text('Confirm')),
    ],
  )) ?? false;

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, textAlign: TextAlign.center),
      FilledButton(onPressed: retry, child: const Text('Retry')),
    ]),
  );
}
