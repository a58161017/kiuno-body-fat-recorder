import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database_helper.dart';
import '../data/measurement_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final measurementsRepositoryProvider = Provider<MeasurementsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return MeasurementsRepository(database);
});
