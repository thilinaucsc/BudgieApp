import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/reminder_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final db = DatabaseHelper.instance;
  ReminderSettings? settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ReminderSettings.load();
    if (mounted) setState(() => settings = s);
  }

  Future<void> _apply(String key, String value) async {
    await db.setSetting(key, value);
    await _load();
    await ReminderService.instance.sync();
  }

  Future<void> _toggle(String key, bool on) async {
    if (on && !await ReminderService.instance.requestPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Allow notifications for Budgie in your phone settings'),
      ));
      return;
    }
    await _apply(key, on ? '1' : '0');
  }

  Future<void> _pickTime(TimeOfDay current) async {
    final picked =
        await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    await _apply(
        ReminderSettings.dailyTimeKey, '${picked.hour}:${picked.minute}');
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.event_note_outlined),
                        title: const Text('Bill reminders'),
                        subtitle: const Text(
                            'Notify me at 9 AM about recurring expenses'),
                        value: s.bills,
                        onChanged: (v) =>
                            _toggle(ReminderSettings.billsKey, v),
                      ),
                      if (s.bills)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                    value: 0, label: Text('On the day')),
                                ButtonSegment(
                                    value: 1, label: Text('1 day before')),
                                ButtonSegment(
                                    value: 3, label: Text('3 days before')),
                              ],
                              selected: {s.daysBefore},
                              onSelectionChanged: (v) => _apply(
                                  ReminderSettings.daysBeforeKey,
                                  '${v.first}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary:
                            const Icon(Icons.notifications_active_outlined),
                        title: const Text('Daily reminder'),
                        subtitle: const Text('Remind me to record expenses'),
                        value: s.daily,
                        onChanged: (v) =>
                            _toggle(ReminderSettings.dailyKey, v),
                      ),
                      if (s.daily) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('Reminder time'),
                          trailing: Text(s.dailyTime.format(context)),
                          onTap: () => _pickTime(s.dailyTime),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
