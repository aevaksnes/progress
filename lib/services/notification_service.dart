import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:progress/services/database_service.dart'; // Ny import for å lese fra databasen

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
  // DEN NYE "MASTER"-FUNKSJONEN
  // ==========================================
  Future<void> updateAllNotifications() async {
    // 1. Slett alt det gamle for å unngå duplikater eller "spøkelsesalarmer"
    await cancelAllNotifications();

    // 2. Hent alle kategorier fra databasen
    final categories = await DatabaseService.instance.getCategories();

    const androidDetails = AndroidNotificationDetails(
      'progress_reminders', // Unique ID for kanalen
      'Progress Reminders', 
      channelDescription: 'Reminds you to log your progress',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    // 3. Gå gjennom alle kategorier og sett opp alarmer
    for (var cat in categories) {
      final name = cat['name'] as String;
      final type = cat['reminder_type'] as String;

      // Hvis varselet er av, hopp over denne og gå til neste
      if (type == 'none') continue;

      final hour = cat['reminder_hour'] as int;
      final minute = cat['reminder_minute'] as int;
      
      // Vi bruker navnet på kategorien (f.eks "Flåttbitt") sin innebygde hashkode som ID
      final notificationId = name.hashCode; 

      if (type == 'daily') {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Update $name',
          body: 'Time to log your daily progress for $name.',
          scheduledDate: _nextInstanceOfTime(hour, minute),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Dette sier til Android: "Gjenta hver dag på dette klokkeslettet"
          matchDateTimeComponents: DateTimeComponents.time, 
        );
      } else if (type == 'weekly') {
        final dayOfWeek = cat['reminder_day'] as int;
        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Update $name',
          body: 'Time to log your weekly progress for $name.',
          scheduledDate: _nextInstanceOfWeeklyTime(dayOfWeek, hour, minute),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Dette sier til Android: "Gjenta hver uke på denne ukedagen og klokkeslettet"
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, 
        );
      }
    }
  }

  // ==========================================
  // HJELPEFUNKSJONER (Akkurat som du hadde dem)
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