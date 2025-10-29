import 'package:equatable/equatable.dart';

class MeasurementItem extends Equatable {
  const MeasurementItem({
    required this.id,
    required this.name,
    required this.position,
  });

  final int id;
  final String name;
  final int position;

  MeasurementItem copyWith({
    int? id,
    String? name,
    int? position,
  }) {
    return MeasurementItem(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
    );
  }

  factory MeasurementItem.fromMap(Map<String, Object?> map) {
    return MeasurementItem(
      id: map['id'] as int,
      name: map['name'] as String,
      position: map['position'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
    };
  }

  @override
  List<Object?> get props => [id, name, position];
}
