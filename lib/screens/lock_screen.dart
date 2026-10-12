import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:secure_keep_app/services/auth_service.dart';
import 'package:secure_keep_app/services/vault_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.authService,
    required this.vault,
    required this.onUnlocked,
    this.onRecoveryRequested,
  });

  final AuthService authService;
  final VaultService vault;
  final VoidCallback onUnlocked;
  final VoidCallback? onRecoveryRequested;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
    }
  }

  Future<void> _tryUnlock() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!kIsWeb) {
        final canAuth = await widget.authService.canAuthenticate();
        if (!canAuth) {
          if (!mounted) {
            return;
          }
          setState(() {
            _busy = false;
            _error = 'この端末では生体認証・画面ロックが利用できません。設定でPINまたは生体認証を有効にしてください。';
          });
          return;
        }

        final ok = await widget.authService.authenticate();
        if (!mounted) {
          return;
        }

        if (!ok) {
          setState(() {
            _busy = false;
            _error = '認証に失敗しました。もう一度お試しください。';
          });
          return;
        }
      }

      await widget.vault.unlockFromDevice();
      if (!mounted) {
        return;
      }
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = kIsWeb
            ? 'ブラウザーのロック解除または Google ドライブとの同期に失敗しました。\n$e'
            : 'ボールトの解除に失敗しました。リカバリーコードで復元してください。\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Icon(Icons.lock_rounded, size: 72, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Secure Keep',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kIsWeb
                      ? 'ブラウザーに保存された暗号鍵でロックを解除します\n'
                            '解除後、暗号化メモを Google ドライブから同期します'
                      : '指紋・顔認証、またはデバイスのPINでロックを解除します\n'
                            '解除後、暗号化メモを Google ドライブから同期します',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xFF5F6368), height: 1.4),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, height: 1.4),
                  ),
                ],
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _tryUnlock,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(kIsWeb ? Icons.lock_open : Icons.fingerprint),
                    label: Text(
                      _busy ? (kIsWeb ? 'ロック解除・同期中…' : '認証・同期中…') : 'ロックを解除',
                    ),
                  ),
                ),
                if (widget.onRecoveryRequested != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : widget.onRecoveryRequested,
                    child: const Text('リカバリーコードで復元'),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
