import 'dart:io';

import 'package:flutter/material.dart';
import 'package:progress/services/database_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:progress/models/category.dart';
import 'package:progress/models/progress_entry.dart';

import 'camera_screen.dart';
import 'compare_screen.dart';
import 'settings_screen.dart';
import 'full_screen_image_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<ProgressCategory> _categories = [];
  ProgressCategory? _selectedCategory;

  List<ProgressEntry> _entries = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final List<ProgressEntry> _selectedEntries = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final loadedCategories = await DatabaseService.instance.getCategories();

    setState(() {
      _categories = loadedCategories;

      if (_categories.isNotEmpty) {
        // Check if the previously selected category still exists in the updated list
        final stillExists = _categories.any(
          (c) => c.name == _selectedCategory?.name,
        );
        if (!stillExists) {
          _selectedCategory = _categories.first;
        }
      } else {
        _selectedCategory = null;
      }
    });

    await _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (_selectedCategory == null) {
      setState(() {
        _isLoading = false; 
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final entries = await DatabaseService.instance.getEntriesByCategory(
      _selectedCategory!.name,
    );

    setState(() {
      _entries = entries;
      _isLoading = false;
      _cancelSelection();
    });
  }

  Future<void> _openCamera() async {
    if (_selectedCategory == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(category: _selectedCategory!.name),
      ),
    );

    _loadEntries();
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- SELECTION & DELETE ---
  // Select images for deletion or comparison

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedEntries.clear();
    });
  }

  void _onItemLongPress(ProgressEntry entry) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedEntries.add(entry);
      });
    }
  }

  void _onItemTap(ProgressEntry entry) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedEntries.contains(entry)) {
          _selectedEntries.remove(entry);
          if (_selectedEntries.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedEntries.add(entry);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImageScreen(
            imagePath: entry.imagePath,
            dateTaken: entry.dateTaken,
          ),
        ),
      );
    }
  }

  Future<void> _deleteSelectedEntries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Photos?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedEntries.length} photo(s)? This cannot be undone.',
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
      for (var entry in _selectedEntries) {
        await DatabaseService.instance.deleteProgressImage(
          entry.id,
          entry.imagePath,
        );
      }
      _cancelSelection();
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white),
                onPressed: _cancelSelection,
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedEntries.length} selected' : 'Timeline',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _isSelectionMode ? Colors.grey[900] : Colors.black,
        elevation: 0,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              onPressed: _deleteSelectedEntries,
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.settings, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadInitialData()),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                if (!_isSelectionMode)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected =
                            category.name == _selectedCategory?.name;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(category.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                                _loadEntries();
                              }
                            },
                            selectedColor: Colors.white,
                            backgroundColor: Colors.grey[900],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: _categories.isEmpty 
                      ? const Center(
                          child: Text(
                            'Welcome to Progress!\nTap the gear icon to create your first category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : _entries.isEmpty
                          ? const Center(
                              child: Text(
                                'No entries yet.\nTap the camera button to start!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final imagePath = entry.imagePath;
                            final dateTaken = entry.dateTaken;

                            final isSelected = _selectedEntries.contains(entry);

                            return GestureDetector(
                              onLongPress: () => _onItemLongPress(entry),
                              onTap: () => _onItemTap(entry),
                              child: Card(
                                color: Colors.grey[900],
                                margin: const EdgeInsets.only(bottom: 16.0),
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isSelected
                                      ? const BorderSide(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                      : BorderSide.none,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Stack(
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 200,
                                            maxHeight: 500,
                                          ),
                                          child: Container(
                                            color: Colors.black26,
                                            alignment: Alignment.center,
                                            child: Image.file(
                                              File(imagePath),
                                              width: double.infinity,
                                              fit: BoxFit.contain,
                                              cacheHeight: 1200,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Center(
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        32.0,
                                                      ),
                                                      child: Icon(
                                                        LucideIcons.imageOff,
                                                        color: Colors.grey,
                                                        size: 48,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned.fill(
                                            child: Container(
                                              color: Colors.black54,
                                              child: const Center(
                                                child: Icon(
                                                  LucideIcons.checkCircle,
                                                  color: Colors.white,
                                                  size: 60,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        _formatDate(dateTaken),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? (_selectedEntries.length == 2
                ? FloatingActionButton.extended(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    onPressed: () {
                      final firstImage = _selectedEntries[0];
                      final secondImage = _selectedEntries[1];

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompareScreen(
                            entry1: firstImage,
                            entry2: secondImage,
                          ),
                        ),
                      );
                      _cancelSelection();
                    },
                    icon: const Icon(LucideIcons.arrowLeftRight),
                    label: const Text('Compare'),
                  )
                : null)
          : FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: _openCamera,
              child: const Icon(LucideIcons.camera),
            ),
    );
  }
}
