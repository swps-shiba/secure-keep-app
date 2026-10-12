import 'package:flutter/material.dart';
import 'package:secure_keep_app/screens/lock_screen.dart';
import 'package:secure_keep_app/screens/memo_list_screen.dart';
import 'package:secure_keep_app/screens/recovery_screen.dart';
import 'package:secure_keep_app/screens/setup_screen.dart';
import 'package:secure_keep_app/services/auth_service.dart';
import 'package:secure_keep_app/services/encryption_service.dart';
import 'package:secure_keep_app/services/google_auth_service.dart';
import 'package:secure_keep_app/services/google_drive_service.dart';
import 'package:secure_keep_app/services/memo_storage_service.dart';
import 'package:secure_keep_app/services/vault_service.dart';
import 'package:secure_keep_app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final encryption = EncryptionService();
  final googleAuth = GoogleAuthService();
  final drive = GoogleDriveService(authService: googleAuth);
  final vault = VaultService(
    encryption: encryption,
    googleAuth: googleAuth,
    drive: drive,
  );
  final auth = AuthService();
  final storage = MemoStorageService(
    encryptionService: encryption,
    driveService: drive,
  );

  runApp(
    SecureKeepApp(
      authService: auth,
      vault: vault,
      storage: storage,
    ),
  );
}

class SecureKeepApp extends StatelessWidget {
  const SecureKeepApp({
    super.key,
    required this.authService,
    required this.vault,
    required this.storage,
  });

  final AuthService authService;
  final VaultService vault;
  final MemoStorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Keep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _AppGate(
        authService: authService,
        vault: vault,
        storage: storage,
      ),
    );
  }
}

enum _GateView { loading, setup, recovery, lock, home }

class _AppGate extends StatefulWidget {
  const _AppGate({
    required this.authService,
    required this.vault,
    required this.storage,
  });

  final AuthService authService;
  final VaultService vault;
  final MemoStorageService storage;

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> with WidgetsBindingObserver {
  _GateView _view = _GateView.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final setupDone = await widget.vault.isSetupComplete();
    if (!mounted) {
      return;
    }
    setState(() {
      _view = setupDone ? _GateView.lock : _GateView.setup;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock only when fully backgrounded. Avoid `inactive` so the
    // system biometric / PIN / Google sheets do not immediately re-lock.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_view == _GateView.home) {
        widget.vault.lock();
        setState(() => _view = _GateView.lock);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _GateView.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _GateView.setup:
        return SetupScreen(
          vault: widget.vault,
          onCompleted: () => setState(() => _view = _GateView.home),
          onRestoreRequested: () => setState(() => _view = _GateView.recovery),
        );
      case _GateView.recovery:
        return RecoveryScreen(
          vault: widget.vault,
          onRestored: () => setState(() => _view = _GateView.home),
          onBack: () async {
            final setupDone = await widget.vault.isSetupComplete();
            if (!mounted) {
              return;
            }
            setState(() {
              _view = setupDone ? _GateView.lock : _GateView.setup;
            });
          },
        );
      case _GateView.lock:
        return LockScreen(
          authService: widget.authService,
          vault: widget.vault,
          onUnlocked: () => setState(() => _view = _GateView.home),
          onRecoveryRequested: () =>
              setState(() => _view = _GateView.recovery),
        );
      case _GateView.home:
        return MemoListScreen(
          storage: widget.storage,
          onLock: () {
            widget.vault.lock();
            setState(() => _view = _GateView.lock);
          },
        );
    }
  }
}
