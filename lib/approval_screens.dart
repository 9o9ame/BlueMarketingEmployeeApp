import 'package:flutter/material.dart';
import 'live_employee_app.dart';
import 'premium_design.dart';

bool mayReadApprovals(Set<String> permissions, Set<String> roles) =>
  permissions.contains('direct-update') ||
  roles.any({'admin', 'superadmin', 'super-admin'}.contains);

bool mayActOnApproval(Set<String> permissions, Set<String> roles) =>
  permissions.contains('direct-update') ||
  roles.any({'superadmin', 'super-admin'}.contains);

class ApprovalWorkspace extends StatefulWidget {
  const ApprovalWorkspace({super.key, required this.api,
    required this.permissions, required this.roles});
  final ApiClient api;
  final Set<String> permissions;
  final Set<String> roles;
  @override
  State<ApprovalWorkspace> createState() => _ApprovalWorkspaceState();
}

class _ApprovalWorkspaceState extends State<ApprovalWorkspace> {
  String status = 'pending';
  int page = 1;
  Future<Map<String, dynamic>>? current;
  @override
  void initState() { super.initState(); load(); }
  void load({bool reset = false}) {
    if (reset) { page = 1; }
    current = widget.api.call('GET', 'approvals/', query: {
      'status': status, 'page': page.toString(), 'per_page': '20',
    });
    if (mounted) { setState(() {}); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('Approvals')),
    body: Column(children: [
      const BmModuleHero(title: 'Approvals & Tasks',
        subtitle: 'Review requests and inspect changes before deciding',
        icon: Icons.task_alt_rounded, accent: BmColors.purple),
      Padding(padding: const EdgeInsets.all(12), child:
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Approval status'),
          items: const [
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            DropdownMenuItem(value: 'all', child: Text('All')),
          ],
          onChanged: (value) {
            if (value != null) { status = value; load(reset: true); }
          },
        )),
      Expanded(child: FutureBuilder<Map<String, dynamic>>(
        future: current,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final approvals = listOf(snap.data!['data']).map(objectOf).toList();
          final meta = objectOf(snap.data!['meta']);
          final last = numberOf(meta['last_page']) ?? 1;
          return Column(children: [
            Expanded(child: RefreshIndicator(
              onRefresh: () async { load(); await current; },
              child: ListView.builder(
                itemCount: approvals.isEmpty ? 1 : approvals.length,
                itemBuilder: (context, index) {
                  if (approvals.isEmpty) {
                    return const ListTile(title: Text('No approvals.'));
                  }
                  final approval = approvals[index];
                  final id = numberOf(approval['id']);
                  return Card(child: ListTile(
                    leading: CircleAvatar(backgroundColor: BmColors.purple.withValues(alpha: .12),
                      child: const Icon(Icons.task_alt_rounded, color: BmColors.purple)),
                    title: Text(approval['table_label']?.toString() ??
                      approval['table']?.toString() ?? 'Approval'),
                    subtitle: Text("${approval['summary'] ?? ''}\n${approval['status'] ?? ''}"),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: id == null ? null : () async {
                      await Navigator.push<void>(context, MaterialPageRoute(
                        builder: (_) => ApprovalDetails(api: widget.api, id: id,
                          canAct: mayActOnApproval(widget.permissions, widget.roles))));
                      load();
                    },
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
    ]),
  );
}

class ApprovalDetails extends StatefulWidget {
  const ApprovalDetails({super.key, required this.api, required this.id,
    required this.canAct});
  final ApiClient api;
  final int id;
  final bool canAct;
  @override
  State<ApprovalDetails> createState() => _ApprovalDetailsState();
}
class _ApprovalDetailsState extends State<ApprovalDetails> {
  Future<Map<String, dynamic>>? detail;
  Future<Map<String, dynamic>>? preview;
  bool sending = false;
  bool previewReviewed = false;
  String? failure;
  @override
  void initState() {
    super.initState();
    detail = widget.api.call('GET', 'approvals/${widget.id}');
    preview = widget.api.call('GET', 'approvals/${widget.id}/preview');
  }
  Future<void> submit(String action) async {
    // Never act on a pending record without a successful, nonempty diff preview.
    try {
      final loaded = await preview;
      final changes = listOf(objectOf(loaded?['data'])['changes']);
      if (changes.isEmpty) {
        throw StateError('No changes available to review.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => failure = 'Cannot confirm approval preview: $error');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final yes = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: Text(action == 'approve' ? 'Approve request?' : 'Reject request?'),
        content: const Text('This will change live records. Inspect the changes before confirming.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
        ],
      )) ?? false;
    if (!yes || !mounted) {
      return;
    }
    setState(() { sending = true; failure = null; });
    try {
      await widget.api.call('POST',
        'approvals/${widget.id}/$action');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => failure = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review approval')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: detail,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(snap.error.toString()));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final approval = objectOf(snap.data!['data']);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(approval['table_label']?.toString() ?? 'Approval',
                style: Theme.of(context).textTheme.titleLarge),
              ListTile(title: const Text('Status'),
                subtitle: Text(approval['status']?.toString() ?? 'Unknown')),
              ListTile(title: const Text('Record'),
                subtitle: Text(approval['record_id']?.toString() ?? '—')),
              ListTile(title: const Text('Submitted by'),
                subtitle: Text(objectOf(approval['submitted_by'])['name']?.toString() ?? '—')),
            ]),
          )),
          const SizedBox(height: 15),
          Text('Changes preview', style: Theme.of(context).textTheme.titleLarge),
          FutureBuilder<Map<String, dynamic>>(
            future: preview,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(snap.error.toString());
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              final changes = listOf(objectOf(snap.data!['data'])['changes'])
                  .map(objectOf).toList();
              if (changes.isEmpty) {
                return const Text('No changes provided.');
              }
              return Column(children: [
                for (final change in changes)
                  Card(child: ListTile(
                    title: Text(change['field']?.toString() ?? 'Field'),
                    subtitle: Text("Before: ${change['old'] ?? '—'}\nAfter: ${change['new'] ?? '—'}"),
                    trailing: change['changed'] == true
                      ? const Icon(Icons.compare_arrows) : null,
                  )),
              ]);
            },
          ),
          if (failure != null) Padding(padding: const EdgeInsets.all(10),
            child: Text(failure!, style: const TextStyle(color: Colors.red))),
          if (widget.canAct && approval['status'] == 'pending')
            CheckboxListTile(
              title: const Text('I reviewed the changes above'),
              subtitle: const Text('Required before a live approval decision'),
              value: previewReviewed,
              onChanged: (value) => setState(() => previewReviewed = value ?? false),
            ),
          if (widget.canAct && approval['status'] == 'pending' && previewReviewed)
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: sending ? null : () => submit('reject'),
                child: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: sending ? null : () => submit('approve'),
                child: const Text('Approve'))),
            ]),
          const SizedBox(height: 20),
        ]);
      },
    ),
  );
}
