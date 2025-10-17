import 'package:json_annotation/json_annotation.dart';

part 'ap_tree_json.g.dart';

/// 校務系統樹狀結構
@JsonSerializable()
class APTreeJson {
  @JsonKey(name: 'apList')
  final List<APListJson> apList;

  @JsonKey(name: 'parentDn')
  final String? parentDn;

  APTreeJson({required this.apList, this.parentDn});

  factory APTreeJson.fromJson(Map<String, dynamic> json) => _$APTreeJsonFromJson(json);
  Map<String, dynamic> toJson() => _$APTreeJsonToJson(this);
}

/// 校務系統項目
@JsonSerializable()
class APListJson {
  @JsonKey(name: 'apDn')
  final String apDn;
  
  @JsonKey(name: 'icon')
  final String? icon;
  
  @JsonKey(name: 'urlSource')
  final String? urlSource;
  
  @JsonKey(name: 'description')
  final String description;
  
  @JsonKey(name: 'type')
  final String type; // 'link' 或 'folder'
  
  @JsonKey(name: 'urlLink')
  final String urlLink;

  APListJson({
    required this.apDn,
    required this.description,
    this.icon,
    required this.type,
    required this.urlLink,
    this.urlSource,
  });

  factory APListJson.fromJson(Map<String, dynamic> json) => _$APListJsonFromJson(json);
  Map<String, dynamic> toJson() => _$APListJsonToJson(this);
}
