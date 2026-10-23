import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:progress/services/database_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraScreen extends StatefulWidget {
  final String category;

  const CameraScreen({super.key, required this.category});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _ghostImagePath;
  bool _isReady = false;
  String? _errorMessage;

  // Camera controls
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  int _timerSeconds = 0; // Can be 0, 3, or 10
  bool _isCountingDown = false;
  int _currentCountdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      // If no cameras are found (or missing permission)
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No camera found, or permission was denied. Please check your app settings.';
          });
        }
        return;
      }

      _controller = CameraController(
        _cameras[_selectedCameraIndex], 
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      _ghostImagePath = await DatabaseService.instance.getLatestGhostOverlay(widget.category);

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      // If the camera initialization fails (e.g., security lockdown from Android)
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start camera. Please ensure permissions are granted.';
        });
      }
    }
  }

  // --- CAMERA FUNCTIONS ---

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      return; // Must have at least front and back cameras
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    await _controller?.dispose();
    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    await _controller!.setFlashMode(_flashMode);

    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    setState(() {
      _flashMode = _flashMode == FlashMode.off
          ? FlashMode.always
          : FlashMode.off;
    });
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(_flashMode);
    }
  }

  void _toggleTimer() {
    setState(() {
      if (_timerSeconds == 0) {
        _timerSeconds = 3;
      } else if (_timerSeconds == 3) {
        _timerSeconds = 10;
      } else {
        _timerSeconds = 0;
      }
    });
  }

  // --- PICTURE TAKING WITH TIMER ---

  Future<void> _takePictureWithTimer() async {
    if (!_controller!.value.isInitialized || _isCountingDown) return;

    if (_timerSeconds == 0) {
      await _captureAndSave();
      return;
    }

    // Start countdown
    setState(() {
      _isCountingDown = true;
      _currentCountdown = _timerSeconds;
    });

    for (int i = _timerSeconds; i > 0; i--) {
      if (!mounted) return;
      setState(() => _currentCountdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    setState(() => _isCountingDown = false);

    await _captureAndSave();
  }

  Future<void> _captureAndSave() async {
    try {
      final XFile image = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(directory.path, fileName);

      await image.saveTo(savedPath);

      await DatabaseService.instance.insertEntry(
        fileName,
        widget.category,
        DateTime.now(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  // --- APP LIFECYCLE STATE CHANGES ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // If the camera is not initialized, we don't need to do anything
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // App is minimized or the screen is locked. Dispose of the camera to free resources.
      setState(() {
        _isReady = false; 
        cameraController.dispose();
        _controller = null; 
      });
    } else if (state == AppLifecycleState.resumed) {
      // User has returned to the app!
      // Start the camera again with the usual initialization function.
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.cameraOff, color: Colors.redAccent, size: 64),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Portrait mode
    final cameraRatio = 1 / _controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // LAYER 1 & 2: Camera preview and ghost overlay (if available), in the same "box" to maintain aspect ratio
          Center(
            child: AspectRatio(
              aspectRatio: cameraRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The camera preview
                  CameraPreview(_controller!),

                  // Ghost-overlay
                  if (_ghostImagePath != null)
                    Opacity(
                      opacity: 0.4,
                      child: Image.file(
                        File(_ghostImagePath!),
                        fit: BoxFit.cover, // Cover the camera preview, not the entire screen
                      ),
                    ),
                ],
              ),
            ),
          ),

          // LAYER 3: The large countdown number
          if (_isCountingDown)
            Positioned.fill(
              child: Center(
                child: Text(
                  '$_currentCountdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 140,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                  ),
                ),
              ),
            ),

          // LAYER 4: UI Controls 
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row (Back button + Category name)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          LucideIcons.arrowLeft,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        widget.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom (Tools + Trigger)
                Column(
                  children: [
                    // Tools row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Timer Toggle
                        IconButton(
                          icon: Icon(
                            _timerSeconds == 0
                                ? LucideIcons.timerOff
                                : LucideIcons.timer,
                            color: _timerSeconds == 0
                                ? Colors.white
                                : Colors.greenAccent,
                            size: 28,
                          ),
                          onPressed: _isCountingDown ? null : _toggleTimer,
                        ),

                        // Timer Indicator Text
                        if (_timerSeconds > 0)
                          Text(
                            '${_timerSeconds}s',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        // Flash Toggle
                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? LucideIcons.zapOff
                                : LucideIcons.zap,
                            color: _flashMode == FlashMode.off
                                ? Colors.white
                                : Colors.amberAccent,
                            size: 28,
                          ),
                          onPressed: _isCountingDown ? null : _toggleFlash,
                        ),

                        // Switch Camera Toggle
                        IconButton(
                          icon: const Icon(
                            LucideIcons.switchCamera,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _isCountingDown ? null : _switchCamera,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Shutter Button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40.0),
                      child: GestureDetector(
                        onTap: _takePictureWithTimer,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: _isCountingDown ? 60 : 80,
                          width: _isCountingDown ? 60 : 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isCountingDown
                                  ? Colors.redAccent
                                  : Colors.white,
                              width: 4,
                            ),
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
