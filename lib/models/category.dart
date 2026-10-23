class ProgressCategory {
  final String name;
  final String reminderType;
  final int reminderDay;
  final int reminderHour;
  final int reminderMinute;

  ProgressCategory({
    required this.name,
    required this.reminderType,
    required this.reminderDay,
    required this.reminderHour,
    required this.reminderMinute,
  });

  // Fetch data from SQLite and convert it to a complete object
  factory ProgressCategory.fromMap(Map<String, dynamic> map) {
    return ProgressCategory(
      name: map['name'] as String,
      reminderType: map['reminder_type'] as String,
      reminderDay: map['reminder_day'] as int,
      reminderHour: map['reminder_hour'] as int,
      reminderMinute: map['reminder_minute'] as int,
    );
  }

  // Convert the object to a Map for storage in SQLite
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'reminder_type': reminderType,
      'reminder_day': reminderDay,
      'reminder_hour': reminderHour,
      'reminder_minute': reminderMinute,
    };
  }
}