import 'package:equatable/equatable.dart';

class MeasurementEntry extends Equatable {
  const MeasurementEntry({
    required this.date,
    required this.values,
  });

  final String date; // yyyyMMdd
  final Map<int, double> values;

  MeasurementEntry copyWith({
    String? date,
    Map<int, double>? values,
  }) {
    return MeasurementEntry(
      date: date ?? this.date,
      values: values ?? this.values,
    );
  }

  @override
  List<Object?> get props => [date, values];
}

class MeasurementDataPoint extends Equatable {
  const MeasurementDataPoint({required this.date, required this.value});

  final DateTime date;
  final double value;

  @override
  List<Object?> get props => [date, value];
}
