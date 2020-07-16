import 'package:json_annotation/json_annotation.dart';
import 'package:minsk8/import.dart';

part 'give.g.dart';

@JsonSerializable()
class GiveModel {
  final DateTime createdAt;
  ItemModel item;

  GiveModel({
    this.createdAt,
    this.item,
  });

  factory GiveModel.fromJson(Map<String, dynamic> json) =>
      _$GiveModelFromJson(json);

  Map<String, dynamic> toJson() => _$GiveModelToJson(this);
}