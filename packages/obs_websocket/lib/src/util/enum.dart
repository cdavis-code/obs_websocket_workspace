enum WebSocketOpCode {
  hello(0),
  identify(1),
  identified(2),
  reIdentify(3),
  event(5),
  request(6),
  requestResponse(7),
  requestBatch(8),
  requestBatchResponse(9);

  final int code;
  const WebSocketOpCode(this.code);
}

enum RequestStatusCode {
  unknown(0),
  noError(10),
  success(100),
  missingRequestType(203),
  unknownRequestType(204),
  genericError(205),
  unsupportedRequestBatchExecutionType(206),
  notReady(207),
  missingRequestField(300),
  missingRequestData(301),
  invalidRequestField(400),
  invalidRequestFieldType(401),
  requestFieldOutOfRange(402),
  requestFieldEmpty(403),
  tooManyRequestFields(404),
  outputRunning(500),
  outputNotRunning(501),
  outputPaused(502),
  outputDisabled(503),
  studioModeActive(504),
  outputNotPaused(505),
  studioModeNotActive(506),
  resourceNotFound(600),
  resourceAlreadyExists(601),
  invalidResourceType(602),
  notEnoughResources(603),
  invalidResourceState(604),
  resourceNotConfigurable(606),
  invalidFilterKind(607),
  invalidInputKind(608),
  resourceCreationFailed(700),
  resourceActionFailed(701),
  requestProcessingFailed(702),
  cannotAct(703);

  final int code;
  const RequestStatusCode(this.code);
}

enum RequestBatchExecutionType {
  none(-1),
  serialRealtime(0),
  serialFrame(1),
  parallel(2);

  final int code;
  const RequestBatchExecutionType(this.code);
}

enum EventSubscription {
  none(0),
  general(1),
  config(2),
  scenes(4),
  inputs(8),
  transitions(16),
  filters(32),
  outputs(64),
  sceneItems(128),
  mediaInputs(256),
  vendors(512),
  ui(1024),
  canvases(2048),
  all(4095),
  inputVolumeMeters(65536),
  inputActiveStateChanged(131072),
  inputShowStateChanged(262144),
  sceneItemTransformChanged(524288);

  final int code;

  const EventSubscription(this.code);

  /// Combines two event subscriptions using bitwise OR
  int operator |(EventSubscription other) => code | other.code;
}
