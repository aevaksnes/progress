import 'dart:io';
import 'package:flutter/material.dart';

class CompareScreen extends StatelessWidget {
  final Map<String, dynamic> entry1;
  final Map<String, dynamic> entry2;

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
    final date1 = DateTime.parse(entry1['date_taken']);
    final date2 = DateTime.parse(entry2['date_taken']);
    
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
                      _formatDate(olderEntry['date_taken']),
                      style: const TextStyle(
                        color: Colors.grey, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Image.file(
                      File(olderEntry['image_path']),
                      fit: BoxFit.cover,
                      width: double.infinity,
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
                      _formatDate(newerEntry['date_taken']),
                      style: const TextStyle(
                        color: Colors.greenAccent, // Highlights the newer date
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Image.file(
                      File(newerEntry['image_path']),
                      fit: BoxFit.cover,
                      width: double.infinity,
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