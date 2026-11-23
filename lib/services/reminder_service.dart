import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../db/database_helper.dart';
import '../models/bill_reminder.dart';

class ReminderSettings {
  static const billsKey = 'bill_reminders';
  static const daysBeforeKey = 'bill_reminder_days';
  static const dailyKey = 'daily_reminder';
  static const dailyTimeKey = 'daily_reminder_time';

  final bool bills;
  final int daysBefore;
  final bool daily;
  final TimeOfDay dailyTime;

  const ReminderSettings({
    required this.bills,
    required this.daysBefore,
    required this.daily,
    required this.dailyTime,
  });

  static Future<ReminderSettings> load() async {
    final db = DatabaseHelper.instance;
    final time = (await db.getSetting(dailyTimeKey, '20:00')).split(':');
    return ReminderSettings(
      bills: await db.getSetting(billsKey, '0') == '1',
      daysBefore: int.tryParse(await db.getSetting(daysBeforeKey, '1')) ?? 1,
      daily: await db.getSetting(dailyKey, '0') == '1',
      dailyTime: TimeOfDay(
        hour: int.tryParse(time.first) ?? 20,
        minute: int.tryParse(time.last) ?? 0,
      ),
    );
  }
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _dailyId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _scheduled = '';

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks the phone for permission and returns whether it was granted.
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('ReminderService.requestPermission: $e');
      return false;
    }
  }

  /// Brings scheduled notifications in line with the saved settings and bills.
  /// Does nothing when the schedule has not changed.
  Future<void> sync() async {
    try {
      final db = DatabaseHelper.instance;
      final settings = await ReminderSettings.load();
      final bills = settings.bills
          ? planBillReminders(
              recurring: await db.getRecurringExpenses(),
              now: DateTime.now(),
              daysBefore: settings.daysBefore,
              currency: await db.getSetting('currency', 'Rs.'),
            )
          : const <PlannedReminder>[];
      final time = settings.dailyTime;
      final signature = [
        if (settings.daily) 'daily|${time.hour}:${time.minute}',
        ...bills.map((b) => b.signature),
      ].join('\n');
      if (signature == _scheduled) return;

      await _init();
      await _plugin.cancelAll();
      if (settings.daily) await _scheduleDaily(time);
      for (final bill in bills) {
        await _plugin.zonedSchedule(
          id: bill.id,
          title: bill.title,
          body: bill.body,
          scheduledDate: tz.TZDateTime(tz.local, bill.when.year,
              bill.when.month, bill.when.day, bill.when.hour),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'bill_reminders',
              'Bill reminders',
              channelDescription: 'Reminders before a recurring bill is due',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      _scheduled = signature;
    } catch (e) {
      debugPrint('ReminderService.sync: $e');
    }
  }

  Future<void> _scheduleDaily(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!first.isAfter(now)) {
      first = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1,
          time.hour, time.minute);
    }
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: 'Budgie',
      body: 'Did you spend anything today? Add it now.',
      scheduledDate: first,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'A daily reminder to record your expenses',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
