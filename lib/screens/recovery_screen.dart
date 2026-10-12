import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:secure_keep_app/services/vault_service.dart';

/// Restore vault on a new device using the 12-word recovery phrase.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.vault,
    required this.onRestored,
    this.onBack,
  });

  final VaultService vault;
  final VoidCallback onRestored;
  final VoidCallback? onBack;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _passkeyReady = !kIsWeb;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await widget.vault.prepareWebRecovery(_controller.text);
        _controller.clear();
        if (!mounted) {
          return;
        }
        setState(() {
          _passkeyReady = true;
          _busy = false;
        });
        return;
      }
      await widget.vault.restoreFromRecoveryPhrase(_controller.text);
      if (!mounted) {
        return;
      }
      widget.onRestored();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '復元に失敗しました: $e';
      });
    }
  }

  Future<void> _finishWebRecovery() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vault.completeWebRecovery();
      if (!mounted) {
        return;
      }
      widget.onRestored();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Google Drive への接続に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ボールトを復元'),
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _busy ? null : widget.onBack,
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _passkeyReady && kIsWeb
                    ? 'パスキーで暗号鍵を保護しました。続けて Google アカウントへ接続します。'
                    : '12個の英単語（リカバリーコード）をスペース区切りで入力し、'
                          '同じ Google アカウントでサインインしてください。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.4, color: const Color(0xFF5F6368)),
              ),
              const SizedBox(height: 20),
              if (!_passkeyReady || !kIsWeb)
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 5,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'リカバリーコード',
                    hintText: 'word1 word2 … word12',
                    alignLabelWithHint: true,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: scheme.error, height: 1.4),
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : kIsWeb && _passkeyReady
                    ? _finishWebRecovery
                    : _restore,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open),
                label: Text(
                  _busy
                      ? '復元中…'
                      : kIsWeb && _passkeyReady
                      ? 'Google Drive に接続'
                      : kIsWeb
                      ? 'パスキーを登録して続行'
                      : '復元して同期',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
