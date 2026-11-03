import 'package:flutter/material.dart';
import 'premium_design.dart';

/// The Task Management backend currently exposes no mobile notification API.
/// This screen deliberately shows no fabricated notifications or unread count.
class TaskNotificationsScreen extends StatelessWidget {
  const TaskNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BmColors.background,
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const BmModuleHero(
        title: 'Notifications & Tasks',
        subtitle: 'Stay up to date with your assigned work',
        icon: Icons.notifications_active_rounded,
        accent: BmColors.purple,
      ),
      const SizedBox(height: 24),
      const BmSoftCard(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          Icon(Icons.notifications_none_rounded,
            size: 62, color: BmColors.blue),
          SizedBox(height: 16),
          Text('Task notifications are being connected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19,
              color: BmColors.navy, fontWeight: FontWeight.w800)),
          SizedBox(height: 9),
          Text(
            'Your real assigned-task notifications will appear here '
            'after the Task Management notification service is enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BmColors.muted),
          ),
        ]),
      )),
    ]),
  );
}
