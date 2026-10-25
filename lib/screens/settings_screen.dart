import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:progress/services/backup_service.dart';
import 'package:progress/services/database_service.dart';
import 'package:progress/services/notification_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:progress/models/category.dart';
import 'package:progress/widgets/category_dialog.dart';
import 'package:progress/widgets/import_photo_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ProgressCategory> _categories = [];
  bool _isLoading = false;

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

  // --- BACKUP AND IMPORT ---

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    try {
      await BackupService.instance.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
            const SnackBar(
              content: Text('Backup imported! App will now use restored data.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Import cancelled.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImportPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (pickedFile != null && mounted) {
      final success = await ImportPhotoDialog.show(
        context,
        originalImagePath: pickedFile.path,
        categories: _categories,
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // --- CATEGORY MANAGEMENT ---

  Future<void> _showCategoryDialog({ProgressCategory? existingCategory}) async {
    final didSave = await CategoryDialog.show(
      context,
      existingCategory: existingCategory,
    );

    if (didSave == true) {
      _loadSettings();
    }
  }

  Future<void> _confirmDeleteCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Category?',
          style: TextStyle(color: Colors.white),
        ),
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
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
      case 'daily':
        return LucideIcons.calendarCheck;
      case 'weekly':
        return LucideIcons.calendarDays;
      default:
        return LucideIcons.bellOff;
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
                  const Text(
                    'Categories & Reminders',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(
                      LucideIcons.plus,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No categories yet. Add one to get started!',
                    style: TextStyle(color: Colors.grey),
                  ),
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
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final category = _categories[index];

                      return ListTile(
                        leading: Icon(
                          _getReminderIcon(category.reminderType),
                          color: category.reminderType == 'none'
                              ? Colors.grey
                              : Colors.greenAccent,
                        ),
                        title: Text(
                          category.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _formatReminderText(category),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () =>
                              _confirmDeleteCategory(category.name),
                        ),
                        onTap: () =>
                            _showCategoryDialog(existingCategory: category),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 40),

              const Text(
                'Data & Backup',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        LucideIcons.imagePlus,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Import from Gallery',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Add past photos to a category timeline',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: _isLoading ? null : _handleImportPhoto,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.download,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Export Backup',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Save your data to a ZIP file',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: _isLoading ? null : _handleExport,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.upload,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Import Backup',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Restore data from a ZIP file',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
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
