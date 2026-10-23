import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:progress/services/database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  Future<void> exportData() async {
    try {

      // Ensure the database is in a consistent state before backing up
      final db = await DatabaseService.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
      
      final docDir = await getApplicationDocumentsDirectory();
      final zipFilePath = path.join(docDir.path, 'progress_backup.zip');

      // Starts an encoder to create a ZIP file, to not keep everything in RAM as it is being added
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      // 1. Add the database file to the ZIP
      final dbDir = await getDatabasesPath();
      final dbPath = path.join(dbDir, 'progress_database.db');
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        encoder.addFile(dbFile, 'progress_database.db');
      }

      // 2. Add the images to the ZIP
      final files = docDir.listSync();
      for (var file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.jpg')) {
          encoder.addFile(file, 'images/${path.basename(file.path)}');
        }
      }

      // Close the encoder to finalize the ZIP file
      encoder.close();

      // 3. Share the file via share_plus
      await SharePlus.instance.share(
        ShareParams(files: [XFile(zipFilePath)], text: 'Progress App Backup'),
      );

    } catch (e) {

      throw Exception('Failed to create backup: $e');
    }
  }

  Future<bool> importData() async {
    try {
      // 1. Let the user pick a ZIP file
      final files = await FilePicker.pickFiles(
        type: FileType.any, 
      );

      if (files.isNotEmpty && files.first.path != null) {
        final zipFilePath = files.first.path!;
        
        // --- Check the file type ---
        if (!zipFilePath.toLowerCase().endsWith('.zip')) {
          throw Exception('Selected file is not a valid .zip backup.');
        }
        // --------------------------------------

        final docDir = await getApplicationDocumentsDirectory();
        
        // Unzip the file to a temporary directory
        final tempExtractDir = Directory(path.join(docDir.path, 'temp_extract'));
        if (await tempExtractDir.exists()) {
          await tempExtractDir.delete(recursive: true);
        }
        await tempExtractDir.create();

        extractFileToDisk(zipFilePath, tempExtractDir.path);

        // 2. Move the database file to the app's database directory
        final extractedDbFile = File(path.join(tempExtractDir.path, 'progress_database.db'));
        if (await extractedDbFile.exists()) {
          final dbDir = await getDatabasesPath();
          final activeDbPath = path.join(dbDir, 'progress_database.db');
          
          // A: Close the current database connection to ensure no operations are pending, release the file
          await DatabaseService.instance.close();
          
          // B: Delete SQLite's temporary log files (WAL and SHM) to prevent corruption
          final walFile = File('$activeDbPath-wal');
          final shmFile = File('$activeDbPath-shm');
          if (await walFile.exists()) await walFile.delete();
          if (await shmFile.exists()) await shmFile.delete();

          // C: Safely copy the extracted database file to the active database path
          await extractedDbFile.copy(activeDbPath);
        }

        // 3. Move all images from the 'images' folder to the app's document directory
        final extractedImagesDir = Directory(path.join(tempExtractDir.path, 'images'));
        if (await extractedImagesDir.exists()) {
          final extractedImages = extractedImagesDir.listSync();
          for (var image in extractedImages) {
            if (image is File) {
              final newPath = path.join(docDir.path, path.basename(image.path));
              await image.copy(newPath);
            }
          }
        }

        // Clean up the temporary extraction directory
        await tempExtractDir.delete(recursive: true);
        
        return true; // Successful import
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
    return false; // User cancelled or something failed
  }
}