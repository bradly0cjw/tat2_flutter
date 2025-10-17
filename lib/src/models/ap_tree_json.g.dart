// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ap_tree_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

APTreeJson _$APTreeJsonFromJson(Map<String, dynamic> json) => APTreeJson(
      apList: (json['apList'] as List<dynamic>)
          .map((e) => APListJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      parentDn: json['parentDn'] as String?,
    );

Map<String, dynamic> _$APTreeJsonToJson(APTreeJson instance) =>
    <String, dynamic>{
      'apList': instance.apList,
      'parentDn': instance.parentDn,
    };

APListJson _$APListJsonFromJson(Map<String, dynamic> json) => APListJson(
      apDn: json['apDn'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
      type: json['type'] as String,
      urlLink: json['urlLink'] as String,
      urlSource: json['urlSource'] as String?,
    );

Map<String, dynamic> _$APListJsonToJson(APListJson instance) =>
    <String, dynamic>{
      'apDn': instance.apDn,
      'icon': instance.icon,
      'urlSource': instance.urlSource,
      'description': instance.description,
      'type': instance.type,
      'urlLink': instance.urlLink,
    };
