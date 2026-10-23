import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:progress/screens/auth_screen.dart'; 
import 'package:progress/services/notification_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); 
  runApp(const ProgressApp());
}

class ProgressApp extends StatefulWidget {
  const ProgressApp({super.key});

  @override
  State<ProgressApp> createState() => _ProgressAppState();
}

class _ProgressAppState extends State<ProgressApp> with WidgetsBindingObserver {
  bool _isLocked = false;
  DateTime? _pausedTime; // Give the user a grace period of 15 seconds before requiring re-authentication
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
      
      if (!_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {

      if (_pausedTime != null) {

        final timeAway = DateTime.now().difference(_pausedTime!);
        
        if (timeAway < const Duration(seconds: 15)) {
          
          setState(() {
            _isLocked = false;
          });
        } else {
          
          if (_isLocked) _unlockApp();
        }
      } else if (_isLocked) {

        _unlockApp();
      }
      
      _pausedTime = null; 
    }
  }

  Future<void> _unlockApp() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock to view your progress',
        biometricOnly: false, 
        persistAcrossBackgrounding: true, 
        sensitiveTransaction: true,
      );

      if (didAuthenticate && mounted) {
        setState(() {
          _isLocked = false; 
        });
      }
    } catch (e) {
      debugPrint("Auth error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,

            if (_isLocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black, 
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 80, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          'Locked',
                          style: TextStyle(
                            color: Colors.white54, 
                            fontSize: 18, 
                            decoration: TextDecoration.none, 
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // FIKS 1.1: Knappen som redder deg hvis FaceID/Fingeravtrykk feiler!
                        ElevatedButton.icon(
                          onPressed: _unlockApp,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Unlock'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      home: const AuthScreen(), 
    );
  }
}