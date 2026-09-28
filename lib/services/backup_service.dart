import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  Future<String> _getDatabasePath() async {
    final dbFolder = await getDatabasesPath();
    return path.join(dbFolder, 'progress_database.db'); // Match the DB name you use in database_helper.dart
  }

  Future<void> exportData() async {
    final archive = Archive();
    final dbPath = await _getDatabasePath();
    final docDir = await getApplicationDocumentsDirectory();

    // 1. Add Database to ZIP
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));
    }

    // 2. Add all JPG images to ZIP
    final files = docDir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.jpg')) {
        final bytes = await file.readAsBytes();
        final fileName = path.basename(file.path);
        archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
      }
    }

    // 3. Encode ZIP
    final zipData = ZipEncoder().encode(archive);

    // 4. Save locally and Share
    final tempDir = await getTemporaryDirectory();
    final zipFile = File(path.join(tempDir.path, 'progress_backup.zip'));
    await zipFile.writeAsBytes(zipData);

    // Opens the native share sheet (Google Drive, Files, Email, etc.)
    await SharePlus.instance.share(
        ShareParams(files: [XFile(zipFile.path)], text: 'Progress App Backup'),
      );
  }

  Future<bool> importData() async {
    try {
      // 1. Let user pick the ZIP file
      final result = await FilePicker.pickFiles(
        type: FileType.any, // Using 'any' as Android can struggle with 'zip' mime types
      );

      if (result.isEmpty) return false;

      final zipPath = result.first.path;
      if (zipPath == null || !zipPath.endsWith('.zip')) return false;

      // 2. Decode ZIP
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dbPath = await _getDatabasePath();
      final docDir = await getApplicationDocumentsDirectory();

      // 3. Extract and overwrite files
      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'database.db') {
            await File(dbPath).writeAsBytes(file.content as List<int>);
          } else if (file.name.startsWith('images/')) {
            final fileName = file.name.split('/').last;
            final imageFile = File(path.join(docDir.path, fileName));
            await imageFile.writeAsBytes(file.content as List<int>);
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}