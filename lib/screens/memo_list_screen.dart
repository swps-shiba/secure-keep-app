import 'package:flutter/material.dart';
import 'package:secure_keep_app/models/memo.dart';
import 'package:secure_keep_app/screens/memo_edit_screen.dart';
import 'package:secure_keep_app/services/memo_storage_service.dart';
import 'package:secure_keep_app/theme/app_theme.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({
    super.key,
    required this.storage,
    this.onLock,
  });

  final MemoStorageService storage;
  final VoidCallback? onLock;

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  late Future<List<Memo>> _memosFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _memosFuture = widget.storage.loadAll();
    });
  }

  Future<void> _openEditor({Memo? memo}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          storage: widget.storage,
          memo: memo,
        ),
      ),
    );
    if (changed == true) {
      _reload();
    }
  }

  List<Memo> _filter(List<Memo> memos) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return memos;
    }
    return memos.where((m) {
      return m.title.toLowerCase().contains(q) ||
          m.accountId.toLowerCase().contains(q) ||
          m.content.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Keep'),
        actions: [
          IconButton(
            tooltip: 'Drive と同期',
            onPressed: _reload,
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          if (widget.onLock != null)
            IconButton(
              tooltip: 'ロック',
              onPressed: widget.onLock,
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '新規メモ',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'メモを検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Memo>>(
              future: _memosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('読み込みに失敗しました\n${snapshot.error}'),
                  );
                }

                final memos = _filter(snapshot.data ?? const []);
                if (memos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'メモはまだありません'
                              : '一致するメモがありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '右下の + から追加。保存時に Drive へ暗号化同期します',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: memos.length,
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return _MemoCard(
                        memo: memo,
                        onTap: () => _openEditor(memo: memo),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.onTap,
  });

  final Memo memo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = MemoColors.forIndex(memo.colorIndex);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                memo.title.isEmpty ? '(無題)' : memo.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (memo.accountId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'ID: ${memo.accountId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                ),
              ],
              if (memo.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    memo.content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '暗号化 · Drive 同期',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
