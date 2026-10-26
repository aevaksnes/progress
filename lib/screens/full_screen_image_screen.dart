import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;
  final String dateTaken;

  const FullScreenImageScreen({
    super.key,
    required this.imagePath,
    required this.dateTaken,
  });

  @override
  Widget build(BuildContext context) {
    // Formaterer datoen pent til tittellinjen
    final parsedDate = DateTime.tryParse(dateTaken);
    final dateString = parsedDate != null
        ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
        : 'Unknown Date';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(dateString, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.imageOff, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text('Image not found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}