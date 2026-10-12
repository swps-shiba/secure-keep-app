import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:secure_keep_app/services/vault_service.dart';

/// First-run: Google Sign-In → generate 12-word recovery phrase → confirm.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.vault,
    required this.onCompleted,
    this.onRestoreRequested,
  });

  final VaultService vault;
  final VoidCallback onCompleted;
  final VoidCallback? onRestoreRequested;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0;
  bool _busy = false;
  String? _error;
  String? _mnemonic;
  bool _confirmedSaved = false;
  bool _passkeyReady = !kIsWeb;

  Future<void> _startSetup() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final mnemonic = await widget.vault.completeInitialSetup();
      if (!mounted) {
        return;
      }
      setState(() {
        _mnemonic = mnemonic;
        _step = 1;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.toString();
      setState(() {
        _busy = false;
        if (message.contains('ClientID not set') ||
            message.contains('Client ID が未設定') ||
            message.contains('appClientId')) {
          _error =
              'セットアップに失敗しました。\n'
              'ブラウザ実行には Google の Web Client ID が必要です。\n\n'
              '1. Google Cloud Console で「ウェブアプリケーション」の OAuth クライアントを作成\n'
              '2. lib/config/google_oauth_config.dart の webClientId に貼り付け\n'
              '3. web/index.html の google-signin-client_id も同じ値に更新\n'
              '4. アプリを再起動（ホットリロードでは足りません）';
        } else {
          _error = 'セットアップに失敗しました: $e';
        }
      });
    }
  }

  Future<void> _finish() async {
    if (!_passkeyReady) {
      setState(() {
        _error = '先にパスキーを登録してください';
      });
      return;
    }
    if (!_confirmedSaved) {
      setState(() {
        _error = 'リカバリーコードを安全な場所に控えたことを確認してください';
      });
      return;
    }
    if (kIsWeb) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await widget.vault.finishWebSetup();
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _busy = false;
          _error = 'セットアップを完了できませんでした: $e';
        });
        return;
      }
    }
    if (!mounted) {
      return;
    }
    widget.onCompleted();
  }

  Future<void> _enablePasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vault.completeWebSetup();
      if (!mounted) {
        return;
      }
      setState(() {
        _passkeyReady = true;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'パスキーの登録に失敗しました: $e';
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _step == 0
                ? _buildWelcome(scheme)
                : _passkeyReady
                ? _buildPhrase(scheme)
                : _buildPasskeySetup(scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildPasskeySetup(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.fingerprint, size: 64, color: scheme.primary),
        const SizedBox(height: 20),
        Text(
          'パスキーで暗号鍵を保護',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          'このブラウザーに暗号鍵をそのまま保存せず、パスキーで保護します。'
          '端末の指紋・顔認証、または画面ロック PIN で確認します。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF5F6368), height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error, height: 1.4),
          ),
        ],
        const Spacer(),
        FilledButton.icon(
          onPressed: _busy ? null : _enablePasskey,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint),
          label: Text(_busy ? '登録中…' : 'パスキーを登録'),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildWelcome(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.lock_outline, size: 72, color: scheme.primary),
        const SizedBox(height: 20),
        Text(
          'Secure Keep',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'メモは端末で AES-256 暗号化されたあと、Google ドライブの専用フォルダへ同期されます。\n'
          'Google だけでは解読できません（ゼロナレッジ）。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF5F6368), height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error, height: 1.4),
          ),
        ],
        const Spacer(),
        FilledButton.icon(
          onPressed: _busy ? null : _startSetup,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.g_mobiledata),
          label: Text(_busy ? '準備中…' : 'Google で開始'),
        ),
        if (widget.onRestoreRequested != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : widget.onRestoreRequested,
            child: const Text('既にリカバリーコードがある（復元）'),
          ),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPhrase(ColorScheme scheme) {
    final words = (_mnemonic ?? '').split(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'リカバリーコード（12語）',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'この12語がないと、スマホ紛失時や PC からの復号ができません。'
          '紙などに控えて安全に保管してください。アプリには再表示されません。',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF5F6368), height: 1.4),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: GridView.builder(
              itemCount: words.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${index + 1}. ${words[index]}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _mnemonic ?? ''));
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('クリップボードにコピーしました（保管後は消してください）')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('コピー'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmedSaved,
          onChanged: (v) => setState(() {
            _confirmedSaved = v ?? false;
            _error = null;
          }),
          title: const Text('安全な場所に控えました'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: scheme.error)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _finish,
          child: Text(_busy ? '完了中…' : '暗号化メモを始める'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
