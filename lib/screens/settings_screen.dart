import 'package:flutter/material.dart';
import 'package:progress/services/backup_service.dart';
import 'package:progress/services/database_service.dart';
import 'package:progress/services/notification_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:progress/models/category.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ProgressCategory> _categories = [];
  bool _isLoading = false;

  final Map<int, String> _daysOfWeek = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
    4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
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

  // --- BACKUP AND IMPORT ---

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    try {
      await BackupService.instance.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isLoading = true);
    try {
      final success = await BackupService.instance.importData();
      
      if (success) {
  
        await NotificationService.instance.updateAllNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup imported! App will now use restored data.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import cancelled.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CATEGORY MANAGEMENT ---

  Future<void> _showCategoryDialog({ProgressCategory? existingCategory}) async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryDialog(existingCategory: existingCategory),
    );

    // Database is updated, so we reload the settings to reflect changes
    if (didSave == true) {
      _loadSettings();
    }
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
      await NotificationService.instance.updateAllNotifications();
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

  String _formatReminderText(ProgressCategory cat) {
    if (cat.reminderType == 'none') return 'No reminder';
    
    final hour = cat.reminderHour.toString().padLeft(2, '0');
    final minute = cat.reminderMinute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    if (cat.reminderType == 'daily') return 'Every day at $timeStr';
    
    final dayStr = _daysOfWeek[cat.reminderDay] ?? 'Unknown';
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
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
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
                      final category = _categories[index];

                      return ListTile(
                        leading: Icon(_getReminderIcon(category.reminderType), color: category.reminderType == 'none' ? Colors.grey : Colors.greenAccent),
                        title: Text(category.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          _formatReminderText(category), 
                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                        ),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDeleteCategory(category.name),
                        ),
                        onTap: () => _showCategoryDialog(existingCategory: category),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 40),

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
                      onTap: _isLoading ? null : _handleExport,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(LucideIcons.upload, color: Colors.white),
                      title: const Text('Import Backup', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Restore data from a ZIP file', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: _isLoading ? null : _handleImport,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// StatefulWidget to prevent data leaks
// =========================================================================
class _CategoryDialog extends StatefulWidget {
  final ProgressCategory? existingCategory;

  const _CategoryDialog({this.existingCategory});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
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
    // Fetch existing category data if editing, otherwise set defaults
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
          onPressed: () => Navigator.pop(context, false), // Returner false (ikke lagret)
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
                return; // Stop the save process
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
              Navigator.pop(context, true); // Return true (data saved)
            }
          },
          child: const Text('Save', style: TextStyle(color: Colors.greenAccent)),
        ),
      ],
    );
  }
}