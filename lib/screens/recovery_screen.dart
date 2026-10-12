import 'package:flutter/material.dart';
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
                '12個の英単語（リカバリーコード）をスペース区切りで入力し、'
                '同じ Google アカウントでサインインしてください。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: const Color(0xFF5F6368),
                    ),
              ),
              const SizedBox(height: 20),
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
                onPressed: _busy ? null : _restore,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open),
                label: Text(_busy ? '復元中…' : '復元して同期'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
