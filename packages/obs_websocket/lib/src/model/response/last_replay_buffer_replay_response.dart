import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'last_replay_buffer_replay_response.g.dart';

@JsonSerializable()
class LastReplayBufferReplayResponse {
  /// File path of the last saved replay buffer file
  final String savedReplayPath;

  LastReplayBufferReplayResponse({required this.savedReplayPath});

  factory LastReplayBufferReplayResponse.fromJson(Map<String, dynamic> json) =>
      _$LastReplayBufferReplayResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LastReplayBufferReplayResponseToJson(this);

  @override
  String toString() => json.encode(toJson());
}
