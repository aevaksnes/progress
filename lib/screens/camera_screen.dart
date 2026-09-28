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

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _ghostImagePath;
  bool _isReady = false;

  // --- NYE VARIABLER FOR KAMERAKONTROLL ---
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  int _timerSeconds = 0; // Kan være 0, 3 eller 10
  bool _isCountingDown = false;
  int _currentCountdown = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras[_selectedCameraIndex], 
      ResolutionPreset.high,
      enableAudio: false, // Vi trenger ikke mikrofon for bilder
    );
    await _controller!.initialize();
    
    // Sett blitsen til av som standard
    await _controller!.setFlashMode(_flashMode);

    _ghostImagePath = await DatabaseService.instance.getLatestGhostOverlay(widget.category);

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  // --- KAMERAFUNKSJONER ---

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return; // Må ha minst foran og bak
    
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
      _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
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

  // --- OPPTAKS-LOGIKK ---

  Future<void> _takePictureWithTimer() async {
    if (!_controller!.value.isInitialized || _isCountingDown) return;

    if (_timerSeconds == 0) {
      await _captureAndSave();
      return;
    }

    // Start nedtelling
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
        savedPath, 
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // LAYER 1: Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // LAYER 2: Ghost Overlay
          if (_ghostImagePath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.4, 
                child: Image.file(
                  File(_ghostImagePath!),
                  fit: BoxFit.cover, 
                ),
              ),
            ),

          // LAYER 3: Det store nedtellingstallet i midten
          if (_isCountingDown)
            Positioned.fill(
              child: Center(
                child: Text(
                  '$_currentCountdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 140, // Kjempestort tall
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 20)
                    ],
                  ),
                ),
              ),
            ),

          // LAYER 4: UI Controls
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row (Tilbake og Tittel)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        widget.category,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                        ),
                      ),
                    ],
                  ),
                ),

                // Bunnen (Verktøy + Utløser)
                Column(
                  children: [
                    // Verktøylinje
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Timer Toggle
                        IconButton(
                          icon: Icon(
                            _timerSeconds == 0 ? LucideIcons.timerOff : LucideIcons.timer,
                            color: _timerSeconds == 0 ? Colors.white : Colors.greenAccent,
                            size: 28,
                          ),
                          onPressed: _isCountingDown ? null : _toggleTimer,
                        ),
                        
                        // Timer Indicator Text (viser 3s eller 10s under ikonet)
                        if (_timerSeconds > 0)
                          Text('${_timerSeconds}s', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        
                        // Flash Toggle
                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off ? LucideIcons.zapOff : LucideIcons.zap,
                            color: _flashMode == FlashMode.off ? Colors.white : Colors.amberAccent,
                            size: 28,
                          ),
                          onPressed: _isCountingDown ? null : _toggleFlash,
                        ),

                        // Switch Camera Toggle
                        IconButton(
                          icon: const Icon(LucideIcons.switchCamera, color: Colors.white, size: 28),
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
                          height: _isCountingDown ? 60 : 80, // Krymper litt mens den teller ned
                          width: _isCountingDown ? 60 : 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isCountingDown ? Colors.redAccent : Colors.white, 
                              width: 4
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