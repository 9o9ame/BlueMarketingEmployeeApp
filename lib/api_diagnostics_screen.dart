import 'package:flutter/material.dart';
import 'live_employee_app.dart';
import 'premium_design.dart';

/// Read-only checks against existing /api/v1/mobile routes. No passwords,
/// tokens, complete response bodies, or customer records are displayed.
class ApiDiagnosticsScreen extends StatefulWidget {
  const ApiDiagnosticsScreen({
    super.key, required this.api, required this.projectId,
  });

  final ApiClient api;
  final int? projectId;

  @override
  State<ApiDiagnosticsScreen> createState() => _ApiDiagnosticsScreenState();
}

class _Probe {
  const _Probe(this.label, this.path, {this.projectScoped = false,
    this.extraQuery = const {}});
  final String label;
  final String path;
  final bool projectScoped;
  final Map<String, String> extraQuery;
}

const _probes = <_Probe>[
  _Probe('Logged-in account', 'auth/me'),
  _Probe('Assigned projects', 'projects'),
  _Probe('Dashboard', 'dashboard', projectScoped: true),
  _Probe('CRM leads', 'crm/leads', projectScoped: true,
    extraQuery: {'page': '1', 'per_page': '1'}),
  _Probe('CRM summary', 'crm/summary', projectScoped: true),
  _Probe('Today attendance', 'attendance/staff/today',
    projectScoped: true),
  _Probe('Labour records', 'attendance/labour', projectScoped: true,
    extraQuery: {'page': '1', 'per_page': '1'}),
  _Probe('Stock items (global)', 'stock/items',
    extraQuery: {'page': '1', 'per_page': '1'}),
  _Probe('Stock movements', 'stock/entries', projectScoped: true,
    extraQuery: {'page': '1', 'per_page': '1'}),
  _Probe('Stock report', 'stock/report', projectScoped: true),
  _Probe('Project reports', 'reports/projects', projectScoped: true,
    extraQuery: {'page': '1', 'per_page': '1'}),
  _Probe('Inventory report', 'reports/inventory', projectScoped: true),
  _Probe('Approvals', 'approvals/',
    extraQuery: {'status': 'all', 'page': '1', 'per_page': '1'}),
];

class _ApiDiagnosticsScreenState extends State<ApiDiagnosticsScreen> {
  final Map<String, String> findings = {};
  bool checking = false;

  String _successfulSummary(Map<String, dynamic> response) {
    final data = response['data'];
    final meta = objectOf(response['meta']);
    if (meta['total'] != null) {
      return 'Connected · ${meta['total']} total records';
    }
    if (data is List) {
      return 'Connected · ${data.length} records returned';
    }
    final details = objectOf(data);
    if (details['rows'] is List) {
      return 'Connected · ${listOf(details['rows']).length} report rows';
    }
    if (details.isEmpty) {
      return 'Connected · no summary data';
    }
    return 'Connected · response received';
  }

  Future<void> checkAll() async {
    if (checking) return;
    setState(() {
      checking = true;
      findings.clear();
    });
    await Future.wait(_probes.map((probe) async {
      if (probe.projectScoped && widget.projectId == null) {
        if (mounted) {
          setState(() => findings[probe.label] =
              'No selected project · check account project assignment');
        }
        return;
      }
      try {
        final query = <String, String>{
          ...probe.extraQuery,
          if (probe.projectScoped)
            'project_id': widget.projectId.toString(),
        };
        final response = await widget.api.call('GET', probe.path,
          query: query.isEmpty ? null : query);
        if (mounted) {
          setState(() => findings[probe.label] =
              _successfulSummary(response));
        }
      } on ApiRequestException catch (problem) {
        if (mounted) {
          setState(() => findings[probe.label] =
              'HTTP ${problem.statusCode} · ${problem.message}');
        }
      } catch (problem) {
        if (mounted) {
          setState(() => findings[probe.label] =
              'Connection/response error · ${problem.runtimeType}');
        }
      }
    }));
    if (mounted) {
      setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('API Diagnostics')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const BmModuleHero(
        title: 'Check live API data',
        subtitle: 'Read-only connectivity tests for your signed-in account',
        icon: Icons.fact_check_outlined, accent: BmColors.teal,
      ),
      BmSoftCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Selected project ID: ${widget.projectId ?? 'None'}',
            style: const TextStyle(
              fontWeight: FontWeight.w800, color: BmColors.navy)),
          const SizedBox(height: 8),
          const Text(
            'Run checks to see which existing mobile endpoints return '
            'data, no records, access errors, or connection failures. '
            'No data is created, updated or deleted.',
            style: TextStyle(color: BmColors.muted),
          ),
          const SizedBox(height: 15),
          BmPrimaryButton(
            label: checking ? 'Checking...' : 'Run read-only checks',
            icon: Icons.play_arrow_rounded,
            onPressed: checking ? null : checkAll,
          ),
        ],
      )),
      const SizedBox(height: 14),
      for (final probe in _probes)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: BmSoftCard(
            child: Row(children: [
              Icon(findings[probe.label]?.startsWith('Connected') == true
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: findings[probe.label]?.startsWith('Connected') == true
                    ? BmColors.teal : BmColors.blue),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(probe.label, style: const TextStyle(
                    fontWeight: FontWeight.w700, color: BmColors.navy)),
                  const SizedBox(height: 4),
                  Text(findings[probe.label] ??
                    (checking ? 'Checking...' : 'Not checked'),
                    style: const TextStyle(color: BmColors.muted,
                      fontSize: 12)),
                ],
              )),
            ]),
          ),
        ),
      const Text(
        'HTTP 401: expired login; 403: permissions/project; '
        '404: endpoint not deployed; 422: request validation; '
        '500: server-side error. An empty successful response may also '
        'mean there are no records in the selected project.',
        style: TextStyle(fontSize: 11, color: BmColors.muted),
      ),
    ]),
  );
}
