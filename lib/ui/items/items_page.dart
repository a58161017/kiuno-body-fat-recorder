import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/items_provider.dart';

class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增項目'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '項目名稱',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入名稱';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      final name = controller.text.trim();
      await ref.read(itemsProvider.notifier).addItem(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已新增 $name')),
        );
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final controller = TextEditingController(text: name);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重新命名'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '項目名稱'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入名稱';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      final newName = controller.text.trim();
      await ref.read(itemsProvider.notifier).renameItem(id, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已更新 $newName')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除項目'),
          content: Text('確定要刪除「$name」嗎？相關的紀錄資料也會一併刪除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      await ref.read(itemsProvider.notifier).deleteItem(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已刪除 $name')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);
    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('讀取失敗：$error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('尚未建立任何項目'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ReorderableListView.builder(
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(itemsProvider.notifier).reorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  key: ValueKey(item.id),
                  child: ListTile(
                    title: Text(item.name),
                    leading: const Icon(Icons.drag_handle),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: '重新命名',
                          onPressed: () => _showRenameDialog(
                            context,
                            ref,
                            item.id,
                            item.name,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '刪除',
                          onPressed: () => _confirmDelete(
                            context,
                            ref,
                            item.id,
                            item.name,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新增項目'),
      ),
    );
  }
}
