import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:progress/models/category.dart';
import 'package:progress/services/database_service.dart';
import 'package:progress/services/notification_service.dart';


class CategoryDialog extends StatefulWidget {
  final ProgressCategory? existingCategory;

  const CategoryDialog({super.key, this.existingCategory});

  /// Helper function so callers can just do:
  /// final saved = await CategoryDialog.show(context);
  static Future<bool?> show(BuildContext context, {ProgressCategory? existingCategory}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => CategoryDialog(existingCategory: existingCategory),
    );
  }

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late TextEditingController _nameController;
  late String _reminderType;
  late int _selectedDay;
  late TimeOfDay _selectedTime;

  final Map<int, String> _daysOfWeek = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
    4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _reminderType = cat?.reminderType ?? 'none';
    _selectedDay = cat?.reminderDay ?? 7;
    _selectedTime = TimeOfDay(
      hour: cat?.reminderHour ?? 8, 
      minute: cat?.reminderMinute ?? 0,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCategory != null;

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
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category Name (e.g., Right Leg)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 24),
            
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
                  value: _reminderType,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reminderType = val);
                  },
                ),
              ),
            ),

            if (_reminderType == 'weekly') ...[
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
                    value: _selectedDay,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    items: _daysOfWeek.entries.map((e) {
                      return DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ),
              ),
            ],

            if (_reminderType != 'none') ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time of Day', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(LucideIcons.clock, color: Colors.white54),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            final newName = _nameController.text.trim();
            if (newName.isEmpty) return;

            if (!isEditing || (isEditing && newName.toLowerCase() != widget.existingCategory!.name.toLowerCase())) {
              final existingCategories = await DatabaseService.instance.getCategories();
              if (existingCategories.any((c) => c.name.toLowerCase() == newName.toLowerCase())) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A category with this name already exists!'), 
                      backgroundColor: Colors.orange
                    ),
                  );
                }
                return;
              }
            }

            if (isEditing) {
              await DatabaseService.instance.updateCategory(
                widget.existingCategory!.name, newName, _reminderType, _selectedDay, _selectedTime.hour, _selectedTime.minute
              );
            } else {
              await DatabaseService.instance.insertCategory(
                newName, _reminderType, _selectedDay, _selectedTime.hour, _selectedTime.minute
              );
            }
            
            await NotificationService.instance.requestPermissions();
            await NotificationService.instance.updateAllNotifications();
            
            if (context.mounted) {
              Navigator.pop(context, true);
            }
          },
          child: const Text('Save', style: TextStyle(color: Colors.greenAccent)),
        ),
      ],
    );
  }
}