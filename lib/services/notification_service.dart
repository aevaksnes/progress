import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:progress/services/database_service.dart'; 

class NotificationService {
  // Singleton pattern
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('progress_notifications'); 
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);
  }

  // Ask for notification permissions (required for Android 13+)
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ==========================================
  // MAIN FUNCTION TO UPDATE ALL NOTIFICATIONS
  // ==========================================
  Future<void> updateAllNotifications() async {
    // 1. Cancel all existing notifications to avoid duplicates
    await cancelAllNotifications();

    // 2. Fetch all categories from the database
    final categories = await DatabaseService.instance.getCategories();

    const androidDetails = AndroidNotificationDetails(
      'progress_reminders', // Unique ID for the channel
      'Progress Reminders', 
      channelDescription: 'Reminds you to log your progress',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    // 3. Loop through each category and schedule notifications based on its settings
    for (var cat in categories) {
      final name = cat.name;
      final type = cat.reminderType;

      // If the reminder type is 'none', skip scheduling for this category
      if (type == 'none') continue;

      final hour = cat.reminderHour;
      final minute = cat.reminderMinute;

      // Vi will use the hash code of the category name as a unique notification ID. 
      final notificationId = name.hashCode & 0x7FFFFFFF;

      if (type == 'daily') {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Update $name',
          body: 'Time to log your daily progress for $name.',
          scheduledDate: _nextInstanceOfTime(hour, minute),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // This tells Android: "Repeat every day at this time"
          matchDateTimeComponents: DateTimeComponents.time, 
        );
      } else if (type == 'weekly') {
        final dayOfWeek = cat.reminderDay;
        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Update $name',
          body: 'Time to log your weekly progress for $name.',
          scheduledDate: _nextInstanceOfWeeklyTime(dayOfWeek, hour, minute),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // This tells Android: "Repeat every week on this day and time"
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, 
        );
      }
    }
  }

  // ==========================================
  // HELPER FUNCTIONS
  // ==========================================

  // Helper: Finds the next time this hour/minute occurs
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Helper: Pushes the date forward until it hits the correct day of the week
  tz.TZDateTime _nextInstanceOfWeeklyTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}