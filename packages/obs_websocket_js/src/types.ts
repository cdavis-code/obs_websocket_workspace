/**
 * Shared TypeScript types for obs_websocket_js.
 *
 * These mirror the response DTOs from the Dart `obs_websocket` package.
 * Kept deliberately loose (Record<string, any>) where OBS-side shapes vary
 * by request; specific helpers in `apis/*` tighten types per-call.
 */

export interface Scene {
  sceneName: string;
  sceneIndex: number;
  sceneUuid?: string;
}

export interface SceneItem {
  sceneItemId: number;
  sceneItemIndex: number;
  sourceName: string;
  sourceType: string;
  inputKind?: string;
  isGroup: boolean;
  sceneItemEnabled: boolean;
  sceneItemLocked: boolean;
  sceneItemTransform: SceneItemTransform;
  sceneItemBlendMode?: string;
}

export interface SceneItemTransform {
  alignment: number;
  boundsAlignment: number;
  boundsHeight: number;
  boundsType: string;
  boundsWidth: number;
  cropBottom: number;
  cropLeft: number;
  cropRight: number;
  cropTop: number;
  height: number;
  positionX: number;
  positionY: number;
  rotation: number;
  scaleX: number;
  scaleY: number;
  sourceHeight: number;
  sourceWidth: number;
  width: number;
}

export interface Input {
  inputName: string;
  inputKind: string;
  unversionedInputKind: string;
  inputUuid?: string;
}

export interface RequestStatus {
  result: boolean;
  code: number;
  comment?: string;
}

export interface RequestResponse<T = Record<string, any>> {
  requestType: string;
  requestId: string;
  requestStatus: RequestStatus;
  responseData: T;
}

export interface BatchRequest {
  requestType: string;
  requestData?: Record<string, any>;
}

export interface RequestBatchResponse {
  requestId: string;
  results: RequestResponse[];
}

export interface ConnectOptions {
  password?: string;
  /** Timeout in seconds (default 120). */
  timeout?: number;
  logLevel?: 'all' | 'debug' | 'info' | 'warning' | 'error';
  /**
   * Reconnect automatically when the socket drops (default false). Retries
   * use exponential backoff and surface as `connectionStateChange` events.
   */
  autoReconnect?: boolean;
  /** Consecutive failed attempts before giving up (default 5). */
  maxReconnectAttempts?: number;
  /** First retry delay in milliseconds; doubles each attempt (default 200). */
  reconnectBaseDelayMs?: number;
  /** Backoff ceiling in milliseconds (default 5000). */
  reconnectMaxDelayMs?: number;
}

/** Connection lifecycle states carried by the `connectionStateChange` event. */
export type ObsConnectionState =
  | 'disconnected'
  | 'connected'
  | 'reconnecting'
  | 'failed';

/**
 * EventSubscription bitmask (must match Dart `EventSubscription` enum).
 */
export const EventSubscription = {
  None: 0,
  General: 1 << 0,
  Config: 1 << 1,
  Scenes: 1 << 2,
  Inputs: 1 << 3,
  Transitions: 1 << 4,
  Filters: 1 << 5,
  Outputs: 1 << 6,
  SceneItems: 1 << 7,
  MediaInputs: 1 << 8,
  Vendors: 1 << 9,
  Ui: 1 << 10,
  All: (1 << 11) - 1,
  InputVolumeMeters: 1 << 16,
  InputActiveStateChanged: 1 << 17,
  InputShowStateChanged: 1 << 18,
  SceneItemTransformChanged: 1 << 19,
} as const;

export type ObsEvent = {
  eventType: string;
  eventIntent: number;
  eventData: Record<string, any>;
};

/** Low-level handle exposed by the dart2js runtime. Internal use. */
export interface ObsJsHandle {
  send(
    command: string,
    args?: Record<string, any>,
  ): Promise<RequestResponse | null>;
  sendBatch(requests: BatchRequest[]): Promise<RequestBatchResponse>;
  subscribe(mask: number): Promise<void>;
  on(eventType: string, cb: (event: ObsEvent) => void): void;
  off(eventType: string, cb?: (event: ObsEvent) => void): void;
  onAny(cb: (event: ObsEvent) => void): void;
  offAny(cb?: (event: ObsEvent) => void): void;
  onStateChanged(cb: (state: ObsConnectionState) => void): void;
  offStateChanged(cb?: (state: ObsConnectionState) => void): void;
  close(): Promise<void>;
  negotiatedRpcVersion: number;
}

export interface ObsJsNamespace {
  connect(
    url: string,
    password?: string,
    timeoutSeconds?: number,
    logLevel?: string,
    autoReconnect?: boolean,
    maxReconnectAttempts?: number,
    reconnectBaseDelayMs?: number,
    reconnectMaxDelayMs?: number,
  ): Promise<ObsJsHandle>;
  version: string;
}
