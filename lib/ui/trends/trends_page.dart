import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/measurement_entry.dart';
import '../../providers/entry_providers.dart';
import '../../providers/items_provider.dart';

enum TrendRange {
  oneMonth(Duration(days: 30), label: '一個月'),
  threeMonths(Duration(days: 90), label: '一季'),
  sixMonths(Duration(days: 180), label: '半年'),
  oneYear(Duration(days: 365), label: '一年');

  const TrendRange(this.duration, {required this.label});

  final Duration duration;
  final String label;
}

class TrendsPage extends ConsumerStatefulWidget {
  const TrendsPage({super.key});

  @override
  ConsumerState<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends ConsumerState<TrendsPage> {
  TrendRange _range = TrendRange.oneMonth;
  int? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('讀取項目失敗：$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('尚未建立任何項目')); // same message
        }
        if (_selectedItemId == null ||
            !items.any((item) => item.id == _selectedItemId)) {
          _selectedItemId = items.first.id;
        }
        final selectedItem = items.firstWhere(
          (item) => item.id == _selectedItemId,
          orElse: () => items.first,
        );
        final now = DateTime.now();
        final end = DateTime(now.year, now.month, now.day);
        final start = DateTime(end.year, end.month, end.day).subtract(_range.duration);
        final query = ChartQuery(
          itemId: selectedItem.id,
          start: start,
          end: end,
        );
        final chartAsync = ref.watch(chartDataProvider(query));
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedItem.id,
                      isExpanded: true,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedItemId = value;
                        });
                      },
                      items: items
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<TrendRange>(
                        segments: TrendRange.values
                            .map(
                              (range) => ButtonSegment(
                                value: range,
                                label: Text(range.label),
                              ),
                            )
                            .toList(),
                        selected: <TrendRange>{_range},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _range = selection.first;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: chartAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(child: Text('讀取資料失敗：$error')),
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(child: Text('此期間尚無資料'));
                    }
                    final minX = data.first.date.millisecondsSinceEpoch.toDouble();
                    final maxX = data.last.date.millisecondsSinceEpoch.toDouble();
                    double minY = data.first.value;
                    double maxY = data.first.value;
                    for (final point in data.skip(1)) {
                      minY = math.min(minY, point.value);
                      maxY = math.max(maxY, point.value);
                    }
                    final range = maxY - minY;
                    if (range == 0) {
                      minY -= 1;
                      maxY += 1;
                    } else {
                      minY -= range * 0.1;
                      maxY += range * 0.1;
                    }
                    final spots = data
                        .map(
                          (point) => FlSpot(
                            point.date.millisecondsSinceEpoch.toDouble(),
                            point.value,
                          ),
                        )
                        .toList();
                    final dateFormatter = DateFormat('MM/dd');
                    return LineChart(
                      LineChartData(
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(),
                            bottom: BorderSide(),
                            right: BorderSide(color: Colors.transparent),
                            top: BorderSide(color: Colors.transparent),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(dateFormatter.format(date)),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
