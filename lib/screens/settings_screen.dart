import 'package:flutter/material.dart';
import 'package:progress/services/backup_service.dart';
import 'package:progress/services/database_service.dart';
import 'package:progress/services/notification_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _categories = [];

  final Map<int, String> _daysOfWeek = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final categories = await DatabaseService.instance.getCategories();
    setState(() {
      _categories = categories;
    });
  }

  // --- KATEGORI LOGIKK MED VARSLER ---

  void _showCategoryDialog({Map<String, dynamic>? existingCategory}) {
    final isEditing = existingCategory != null;
    final oldName = existingCategory?['name'] as String?;
    
    final TextEditingController nameController = TextEditingController(text: oldName ?? '');
    
    // Hent eksisterende verdier, eller bruk standardverdier (Søndag kl 08:00)
    String reminderType = existingCategory?['reminder_type'] as String? ?? 'none';
    int selectedDay = existingCategory?['reminder_day'] as int? ?? 7; 
    int hour = existingCategory?['reminder_hour'] as int? ?? 8;
    int minute = existingCategory?['reminder_minute'] as int? ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              isEditing ? 'Edit Category' : 'Add Category',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navn på kategori
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Category Name (e.g., Right Leg)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Varslingsfrekvens
                  const Text('Reminder Frequency', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.grey[850],
                        value: reminderType,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => reminderType = val);
                        },
                      ),
                    ),
                  ),

                  // Vis valg av ukedag KUN hvis 'weekly' er valgt
                  if (reminderType == 'weekly') ...[
                    const SizedBox(height: 16),
                    const Text('Day of the Week', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          dropdownColor: Colors.grey[850],
                          value: selectedDay,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: _daysOfWeek.entries.map((e) {
                            return DropdownMenuItem<int>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedDay = val);
                          },
                        ),
                      ),
                    ),
                  ],

                  // Vis valg av klokkeslett hvis varsel IKKE er 'none'
                  if (reminderType != 'none') ...[
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Time of Day', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(
                        selectedTime.format(context),
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(LucideIcons.clock, color: Colors.white54),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setDialogState(() => selectedTime = time);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;

                  if (isEditing && oldName != null) {
                    await DatabaseService.instance.updateCategory(
                      oldName, newName, reminderType, selectedDay, selectedTime.hour, selectedTime.minute
                    );
                  } else {
                    await DatabaseService.instance.insertCategory(
                      newName, reminderType, selectedDay, selectedTime.hour, selectedTime.minute
                    );
                  }
                  
                  await NotificationService.instance.requestPermissions(); // Spør om lov første gang
                  await NotificationService.instance.updateAllNotifications(); // Oppdaterer alle alarmer
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadSettings();
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Category?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nWARNING: This will also permanently delete all photos inside this category.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteCategory(name);
      await NotificationService.instance.updateAllNotifications(); // Oppdaterer alle alarmer
      _loadSettings();
    }
  }

  IconData _getReminderIcon(String type) {
    switch (type) {
      case 'daily': return LucideIcons.calendarCheck;
      case 'weekly': return LucideIcons.calendarDays;
      default: return LucideIcons.bellOff;
    }
  }

  String _formatReminderText(Map<String, dynamic> cat) {
    final type = cat['reminder_type'] as String;
    if (type == 'none') return 'No reminder';
    
    final hour = (cat['reminder_hour'] as int).toString().padLeft(2, '0');
    final minute = (cat['reminder_minute'] as int).toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    if (type == 'daily') return 'Every day at $timeStr';
    
    final dayInt = cat['reminder_day'] as int;
    final dayStr = _daysOfWeek[dayInt] ?? 'Unknown';
    return 'Every $dayStr at $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- CATEGORIES SECTION ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories & Reminders', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(LucideIcons.plus, color: Colors.greenAccent, size: 18),
                label: const Text('Add', style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No categories yet. Add one to get started!', style: TextStyle(color: Colors.grey)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final name = cat['name'] as String;
                  final type = cat['reminder_type'] as String;

                  return ListTile(
                    leading: Icon(_getReminderIcon(type), color: type == 'none' ? Colors.grey : Colors.greenAccent),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      _formatReminderText(cat), 
                      style: const TextStyle(color: Colors.grey, fontSize: 12)
                    ),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDeleteCategory(name),
                    ),
                    onTap: () => _showCategoryDialog(existingCategory: cat),
                  );
                },
              ),
            ),
          const SizedBox(height: 40),

          // --- DATA MANAGEMENT SECTION ---
          const Text('Data & Backup', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.download, color: Colors.white),
                  title: const Text('Export Backup', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Save your data to a ZIP file', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () async => await BackupService.instance.exportData(),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.upload, color: Colors.white),
                  title: const Text('Import Backup', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Restore data from a ZIP file', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () async {
                    final success = await BackupService.instance.importData();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup restored successfully!')),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}