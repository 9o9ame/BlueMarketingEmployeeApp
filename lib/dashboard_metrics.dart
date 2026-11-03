import 'package:flutter/material.dart';
import 'live_employee_app.dart';

class EmployeeDashboardMetrics extends StatelessWidget {
  const EmployeeDashboardMetrics({super.key, required this.api,
    required this.projectId});
  final ApiClient api;
  final int projectId;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: api.call('GET', 'dashboard',
      query: {'project_id': projectId.toString()}),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Dashboard summary unavailable'),
        subtitle: Text('${snapshot.error}', maxLines: 2),
        ));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final crm = objectOf(objectOf(snapshot.data!['data'])['crm']);
      if (crm.isEmpty) {
        return const SizedBox.shrink();
      }
      return Row(children: [
        Expanded(child: Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Total leads'),
            Text('${crm['total_leads'] ?? '—'}',
              style: Theme.of(context).textTheme.headlineMedium),
          ]),
        ))),
        Expanded(child: Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Today follow-ups'),
            Text('${crm['today_followups'] ?? '—'}',
              style: Theme.of(context).textTheme.headlineMedium),
          ]),
        ))),
      ]);
    },
  );
}
