import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:progress/models/progress_entry.dart';

class CompareScreen extends StatelessWidget {
  final ProgressEntry entry1;
  final ProgressEntry entry2;

  const CompareScreen({super.key, required this.entry1, required this.entry2});

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return 'Unknown Date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildImagePane(ProgressEntry entry, Color dateColor) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              _formatDate(entry.dateTaken),
              style: TextStyle(color: dateColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              // ClipRect tvinger bildet til å holde seg innenfor sin halvdel av skjermen
              child: ClipRect(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Center(
                    child: Image.file(
                      File(entry.imagePath),
                      fit: BoxFit.contain, // Viser hele bildet uten å kutte
                      cacheHeight: 800,    // Senket for å sikre at emulatoren ikke krasjer av minnemangel
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(LucideIcons.imageOff, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date1 = DateTime.tryParse(entry1.dateTaken) ?? DateTime.now();
    final date2 = DateTime.tryParse(entry2.dateTaken) ?? DateTime.now();

    final olderEntry = date1.isBefore(date2) ? entry1 : entry2;
    final newerEntry = date1.isBefore(date2) ? entry2 : entry1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Compare', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildImagePane(olderEntry, Colors.grey),
          const Divider(height: 2, color: Colors.white24),
          _buildImagePane(newerEntry, Colors.greenAccent),
        ],
      ),
    );
  }
}