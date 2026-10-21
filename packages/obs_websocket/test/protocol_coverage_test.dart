import 'dart:convert';

import 'package:obs_websocket/obs_websocket.dart';
import 'package:test/test.dart';

void main() {
  group('LastReplayBufferReplayResponse', () {
    test('parses savedReplayPath', () {
      final response = LastReplayBufferReplayResponse.fromJson({
        'savedReplayPath': '/Users/test/Videos/Replay 2026-10-21.mkv',
      });

      expect(
        response.savedReplayPath,
        '/Users/test/Videos/Replay 2026-10-21.mkv',
      );
      expect(
        json.decode(response.toString())['savedReplayPath'],
        '/Users/test/Videos/Replay 2026-10-21.mkv',
      );
    });
  });

  group('SceneListResponse', () {
    test('parses canvas UUID fields', () {
      final response = SceneListResponse.fromJson({
        'currentProgramSceneName': 'Main',
        'currentProgramSceneUuid': 'program-uuid',
        'currentPreviewSceneName': 'Preview',
        'currentPreviewSceneUuid': 'preview-uuid',
        'scenes': [
          {'sceneName': 'Main', 'sceneIndex': 0, 'sceneUuid': 'main-uuid'},
        ],
      });

      expect(response.currentProgramSceneUuid, 'program-uuid');
      expect(response.currentPreviewSceneUuid, 'preview-uuid');
      expect(response.scenes.single.sceneUuid, 'main-uuid');
    });

    test('tolerates responses without UUID fields', () {
      final response = SceneListResponse.fromJson({
        'currentProgramSceneName': 'Main',
        'scenes': [
          {'sceneName': 'Main', 'sceneIndex': 0},
        ],
      });

      expect(response.currentProgramSceneName, 'Main');
      expect(response.currentProgramSceneUuid, isNull);
      expect(response.currentPreviewSceneUuid, isNull);
    });
  });

  group('RequestStatusCode', () {
    test('includes newly documented codes', () {
      expect(RequestStatusCode.notReady.code, 207);
      expect(RequestStatusCode.outputDisabled.code, 503);
      expect(RequestStatusCode.studioModeActive.code, 504);
      expect(RequestStatusCode.invalidInputKind.code, 608);
    });
  });
}
