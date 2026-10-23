# Progress 📈

A Flutter application designed for tracking personal progress through categorized photo timelines. During development we focused on data integrity, memory management, and biometric security.

## ✨ Core Features
* **Categorized Timelines:** Organize progress photos by custom categories (e.g., "Right Leg", "Living Room Renovation").
* **Smart Reminders:** Local notifications for daily or weekly logging routines.
* **Photo Comparison:** Select two photos from a timeline to compare them side-by-side.
* **Bank-Grade Security:** Biometric app locking with a privacy shield that obscures the app in the Android task switcher.
* **Robust Backup System:** Export and import complete app data (database + images) as a ZIP file.

---

## 🏗 Tech Stack
* **Framework:** Flutter (Dart)
* **Database:** SQFlite (SQLite)
* **Security:** local_auth
* **Notifications:** flutter_local_notifications & timezone
* **File Management:** file_picker, path_provider, archive (ZIP)

---

## 🧠 Architecture & Key Technical Decisions

During development, we made several architectural choices to ensure the app is crash-proof and optimized:

### 1. Type Safety (Data Models)
Initially built with dynamic `Map<String, dynamic>` objects, the app was refactored to use typed models (`ProgressCategory` and `ProgressEntry`). 
* **Why:** This prevents silent runtime crashes caused by typos in Map keys and provides full compile-time safety across the UI.

### 2. App Lifecycle & Biometric Security
The lock screen (`main.dart`) is managed by a `WidgetsBindingObserver`.
* **Privacy Shield:** The app instantly locks on `AppLifecycleState.paused` so sensitive photos are never visible in the OS app switcher.
* **15-Second Grace Period:** If the user minimizes the app and returns within 15 seconds, the shield is removed automatically without requiring a fingerprint. 
* **System Dialog Fix:** We explicitly ignore `AppLifecycleState.inactive` to prevent system dialogs (like the file picker or the biometric prompt itself) from triggering an endless re-lock loop.

### 3. SQLite Data Integrity (WAL Checkpointing)
SQLite on Android uses Write-Ahead Logging (WAL). 
* **The Problem:** If a user takes a photo and immediately exports a backup, the new data might still live in the `-wal` cache file instead of the main `.db` file.
* **The Fix:** The `BackupService` executes `PRAGMA wal_checkpoint(FULL);` before zipping to guarantee 0% data loss during exports.

### 4. Memory Leak Prevention
* **Camera Controller Race Conditions:** The `CameraController` is disposed of and set to `null` the exact millisecond the app goes into the background, preventing `CameraController was used after being disposed` crashes upon resuming.
* **Dialog State Management:** UI elements like the "Add Category" dialog were extracted into their own `StatefulWidget`s. This gives them a proper `dispose()` lifecycle, preventing `TextEditingController` memory leaks.

### 5. Cross-Device Backup Compatibility
* **Storage Bloat Prevention:** Backups are exported to `getTemporaryDirectory()` (cache) rather than the permanent Documents directory so Android can automatically clear old ZIPs to free up space.
* **Absolute Path Fallbacks:** When restoring a backup from an older device, absolute paths (`/data/user/0/...`) will mismatch. The `DatabaseService` handles this by falling back to `basename()` extraction and rebuilding the path for the current device.
* **Android OEM Quirks:** We use `FileType.any` with manual `.endsWith('.zip')` validation during import, bypassing a bug on Samsung/Xiaomi devices where `.zip` files get grayed out in the native file picker.

---

## 🚀 Getting Started

1. Ensure you have the Flutter SDK installed.
2. Clone the repository and run `flutter pub get`.
3. Run the app on a physical device (Biometrics and Camera features require a real device, not an emulator).
