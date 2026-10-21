import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:obs_websocket/obs_websocket.dart' show Scene;

part 'scene_list_response.g.dart';

@JsonSerializable()
class SceneListResponse {
  final String currentProgramSceneName;

  /// UUID of the current program scene. `null` if the scene is on a
  /// non-main canvas or OBS is internally desynced.
  final String? currentProgramSceneUuid;

  final String? currentPreviewSceneName;

  /// UUID of the current preview scene. `null` if not in studio mode, the
  /// scene is on a non-main canvas, or OBS is internally desynced.
  final String? currentPreviewSceneUuid;

  final List<Scene> scenes;

  SceneListResponse({
    required this.currentProgramSceneName,
    this.currentProgramSceneUuid,
    this.currentPreviewSceneName,
    this.currentPreviewSceneUuid,
    required this.scenes,
  });

  factory SceneListResponse.fromJson(Map<String, dynamic> json) =>
      _$SceneListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SceneListResponseToJson(this);

  @override
  String toString() => json.encode(toJson());
}
