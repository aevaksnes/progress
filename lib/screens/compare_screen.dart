import 'dart:io';
import 'package:flutter/material.dart';
import 'package:progress/models/progress_entry.dart';

class CompareScreen extends StatelessWidget {
  final ProgressEntry entry1;
  final ProgressEntry entry2;

  const CompareScreen({
    super.key,
    required this.entry1,
    required this.entry2,
  });

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Determine which image is older to show it on the left
    final date1 = DateTime.parse(entry1.dateTaken);
    final date2 = DateTime.parse(entry2.dateTaken);

    final olderEntry = date1.isBefore(date2) ? entry1 : entry2;
    final newerEntry = date1.isBefore(date2) ? entry2 : entry1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Compare', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Left side (Older image)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _formatDate(olderEntry.dateTaken),
                      style: const TextStyle(
                        color: Colors.grey, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    // Allow zooming and panning of the image using InteractiveViewer
                    child: InteractiveViewer(
                      minScale: 1.0, // Minimum zoom level (1x)
                      maxScale: 5.0, // Maximum zoom level (5x)
                      child: Image.file(
                        File(olderEntry.imagePath),
                        fit: BoxFit.contain, // Shows the entire image without cropping
                        width: double.infinity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // A subtle divider in the middle
            Container(width: 2, color: Colors.white24),

            // Right side (Newer image)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _formatDate(newerEntry.dateTaken),
                      style: const TextStyle(
                        color: Colors.greenAccent, // Highlights the newer date
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InteractiveViewer( 
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Image.file(
                        File(newerEntry.imagePath),
                        fit: BoxFit.contain, // Shows the entire image without cropping
                        width: double.infinity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}