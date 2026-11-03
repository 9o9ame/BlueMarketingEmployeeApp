import 'package:flutter/material.dart';
import 'live_employee_app.dart';

/// Stock transactions can post accounting ledger entries. A single
/// confirmation is required; the server validates balances and permissions.
class StockEntryForm extends StatefulWidget {
  const StockEntryForm({
    super.key, required this.api, required this.projectId, required this.flow,
  });
  final ApiClient api;
  final int projectId;
  final String flow;
  @override
  State<StockEntryForm> createState() => _StockEntryFormState();
}

class _StockEntryFormState extends State<StockEntryForm> {
  final form = GlobalKey<FormState>();
  final vehicle = TextEditingController();
  final driver = TextEditingController();
  final reason = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  Future<Map<String, dynamic>>? catalog;
  DateTime day = DateTime.now();
  int? partyId;
  int? itemId;
  bool saving = false;
  String? issue;

  @override
  void initState() {
    super.initState();
    catalog = widget.api.call('GET', 'stock/meta',
      query: {'project_id': widget.projectId.toString()});
  }

  @override
  void dispose() {
    for (final field in [vehicle, driver, reason, quantity, rate]) {
      field.dispose();
    }
    super.dispose();
  }

  static String? checkQuantity(String? text) {
    final value = text?.trim() ?? '';
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(value) ||
        (double.tryParse(value) ?? 0) <= 0) {
      return 'Enter positive quantity (up to 3 decimals)';
    }
    return null;
  }

  static String? checkRate(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    if (value == null || !value.isFinite || value < 0) {
      return 'Enter a valid non-negative rate';
    }
    return null;
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || partyId == null || itemId == null) {
      setState(() => issue = 'Select a valid party and item.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Confirm stock ${widget.flow}'),
        content: const Text(
          'This stock transaction can affect inventory balances and financial ledgers. '
          'Review the item, quantity, rate and party before saving.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm and post')),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    setState(() { saving = true; issue = null; });
    try {
      await widget.api.call('POST', 'stock/entries/${widget.flow.toLowerCase()}',
        data: {
          'project_id': widget.projectId,
          'date': stockDate(day),
          'party_id': partyId,
          if (vehicle.text.trim().isNotEmpty) 'vehicle': vehicle.text.trim(),
          if (driver.text.trim().isNotEmpty) 'driver': driver.text.trim(),
          if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
          'lines': [
            {
              'item_id': itemId,
              'qty': quantity.text.trim(),
              'rate': double.parse(rate.text.trim()),
            },
          ],
        });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => issue = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Stock ${widget.flow}')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = objectOf(snapshot.data!['data']);
        final parties = listOf(data['parties']).map(objectOf)
            .where((value) => numberOf(value['id']) != null).toList();
        final items = listOf(data['items']).map(objectOf)
            .where((value) => numberOf(value['id']) != null).toList();
        return Form(key: form, child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Live stock transaction'),
              subtitle: Text('Entries are currently company-wide. '
                'Backend validates permission and inventory availability.'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(stockDate(day)),
              onPressed: () async {
                final next = await showDatePicker(context: context,
                  initialDate: day, firstDate: DateTime(2020),
                  lastDate: DateTime(2100));
                if (next != null) {
                  setState(() => day = next);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: partyId,
              decoration: const InputDecoration(labelText: 'Stock party'),
              items: parties.map((row) => DropdownMenuItem<int>(
                value: numberOf(row['id']),
                child: Text('${row['name'] ?? ''} (${row['type'] ?? ''})'),
              )).toList(),
              onChanged: (value) => setState(() => partyId = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'Stock item'),
              items: items.map((row) => DropdownMenuItem<int>(
                value: numberOf(row['id']),
                child: Text('${row['name'] ?? ''} · ${row['unit'] ?? ''}'),
              )).toList(),
              onChanged: (value) => setState(() => itemId = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: checkQuantity,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: rate,
              decoration: const InputDecoration(labelText: 'Rate (PKR)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: checkRate,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: vehicle,
              decoration: const InputDecoration(labelText: 'Vehicle (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: driver,
              decoration: const InputDecoration(labelText: 'Driver (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: reason, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (optional)')),
            const SizedBox(height: 12),
            if (issue != null)
              Text(issue!, style: const TextStyle(color: Colors.red)),
            FilledButton.icon(
              onPressed: saving ? null : submit,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Posting...' : 'Post stock ${widget.flow}'),
            ),
          ],
        ));
      },
    ),
  );
}

String stockDate(DateTime date) =>
    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
