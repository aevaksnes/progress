import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:progress/models/category.dart';
import 'package:progress/services/database_service.dart';


class ImportPhotoDialog extends StatefulWidget {
  final String originalImagePath;
  final List<ProgressCategory> categories;

  const ImportPhotoDialog({
    super.key,
    required this.originalImagePath,
    required this.categories,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String originalImagePath,
    required List<ProgressCategory> categories,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportPhotoDialog(
        originalImagePath: originalImagePath,
        categories: categories,
      ),
    );
  }

  @override
  State<ImportPhotoDialog> createState() => _ImportPhotoDialogState();
}

class _ImportPhotoDialogState extends State<ImportPhotoDialog> {
  ProgressCategory? _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // First category is selected by default if available
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first;
    }

    // Try to guess the date from the file (fallback to today)
    try {
      final fileStat = File(widget.originalImagePath).statSync();
      _selectedDate = fileStat.modified;
    } catch (e) {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.greenAccent,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveImportedPhoto() async {
    if (_selectedCategory == null) return;

    setState(() => _isSaving = true);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().millisecondsSinceEpoch; // Avoid name conflicts
      final extension = path.extension(widget.originalImagePath);

      // We use 'import_' prefix to indicate this is an imported photo
      final newFileName = 'import_$timestamp$extension';
      final savedImagePath = path.join(docDir.path, newFileName);

      // Copy the original image to the app's documents directory
      await File(widget.originalImagePath).copy(savedImagePath);

      // Save the entry in the database
      await DatabaseService.instance.insertEntry(
        newFileName,
        _selectedCategory!.name,
        _selectedDate,
      );

      if (mounted) Navigator.pop(context, true); // Return success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const AlertDialog(
        backgroundColor: Colors.black,
        title: Text('No Categories', style: TextStyle(color: Colors.white)),
        content: Text(
          'Please create a category first before importing photos.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Import Past Photo',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liten forhåndsvisning av bildet
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.originalImagePath),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Category',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProgressCategory>(
                  dropdownColor: Colors.grey[850],
                  value: _selectedCategory,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat.name));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Date Taken',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                LucideIcons.calendarDays,
                color: Colors.white54,
              ),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _isSaving ? null : _saveImportedPhoto,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.greenAccent,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Import',
                  style: TextStyle(color: Colors.greenAccent),
                ),
        ),
      ],
    );
  }
}