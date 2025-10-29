import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/measurement_repository.dart';
import '../models/measurement_item.dart';
import 'database_providers.dart';

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, List<MeasurementItem>>(
  ItemsNotifier.new,
);

class ItemsNotifier extends AsyncNotifier<List<MeasurementItem>> {
  late final MeasurementsRepository _repository;

  @override
  Future<List<MeasurementItem>> build() async {
    _repository = ref.watch(measurementsRepositoryProvider);
    return _repository.loadItems();
  }

  Future<void> addItem(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.addItem(name);
      return _repository.loadItems();
    });
  }

  Future<void> renameItem(int id, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.renameItem(id, name);
      return _repository.loadItems();
    });
  }

  Future<void> deleteItem(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteItem(id);
      return _repository.loadItems();
    });
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final currentItems = state.value ?? await build();
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final updated = [...currentItems];
    final item = updated.removeAt(oldIndex);
    updated.insert(adjustedNewIndex, item);
    state = AsyncValue.data(updated);
    await _repository.reorderItems(updated.map((e) => e.id).toList());
    state = AsyncValue.data(await _repository.loadItems());
  }
}
