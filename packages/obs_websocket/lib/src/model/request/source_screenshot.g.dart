// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_screenshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceScreenshot _$SourceScreenshotFromJson(Map<String, dynamic> json) =>
    SourceScreenshot(
      sourceName: json['sourceName'] as String?,
      sourceUuid: json['sourceUuid'] as String?,
      canvasUuid: json['canvasUuid'] as String?,
      imageFormat: json['imageFormat'] as String,
      imageFilePath: json['imageFilePath'] as String?,
      imageWidth: (json['imageWidth'] as num?)?.toInt(),
      imageHeight: (json['imageHeight'] as num?)?.toInt(),
      imageCompressionQuality: (json['imageCompressionQuality'] as num?)
          ?.toInt(),
    );

Map<String, dynamic> _$SourceScreenshotToJson(SourceScreenshot instance) =>
    <String, dynamic>{
      'sourceName': instance.sourceName,
      'sourceUuid': instance.sourceUuid,
      'canvasUuid': instance.canvasUuid,
      'imageFormat': instance.imageFormat,
      'imageFilePath': instance.imageFilePath,
      'imageWidth': instance.imageWidth,
      'imageHeight': instance.imageHeight,
      'imageCompressionQuality': instance.imageCompressionQuality,
    };
