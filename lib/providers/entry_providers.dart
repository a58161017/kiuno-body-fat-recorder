import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/measurement_repository.dart';
import '../models/measurement_entry.dart';
import 'database_providers.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final dateFormatterProvider = Provider<DateFormat>((ref) {
  return DateFormat('yyyyMMdd');
});

String formatDateKey(DateFormat formatter, DateTime date) {
  return formatter.format(date);
}

final measurementsRevisionProvider = StateProvider<int>((ref) => 0);

final entryByDateProvider = FutureProvider.autoDispose
    .family<MeasurementEntry?, String>((ref, date) async {
  final repository = ref.watch(measurementsRepositoryProvider);
  return repository.fetchEntry(date);
});

final chartDataProvider = FutureProvider.autoDispose
    .family<List<MeasurementDataPoint>, ChartQuery>((ref, query) async {
  ref.watch(measurementsRevisionProvider);
  final repository = ref.watch(measurementsRepositoryProvider);
  return repository.fetchDataPoints(query.itemId, query.start, query.end);
});

class ChartQuery {
  ChartQuery({required this.itemId, required this.start, required this.end});

  final int itemId;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChartQuery &&
        other.itemId == itemId &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(itemId, start, end);
}
