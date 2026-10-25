/**
 * Minimal Node.js test — verifies the Promise/EventEmitter facade against a
 * stubbed low-level handle. Full integration tests would require building
 * the dart2js runtime (`npm run build:dart`) and running a real OBS mock
 * server; those are left for CI and are opt-in via `OBS_JS_E2E=1`.
 */

import { describe, expect, it, vi } from 'vitest';
import type {
  BatchRequest,
  ObsConnectionState,
  ObsEvent,
  ObsJsHandle,
  RequestBatchResponse,
  RequestResponse,
} from '../src/types.js';
import { ObsWebSocket } from '../src/index.js';

// Expose the protected constructor for testability.
class TestableObs extends ObsWebSocket {
  static fromHandle(h: ObsJsHandle) {
    return new TestableObs(h);
  }
}

const makeStubHandle = (): ObsJsHandle & {
  lastSend?: { command: string; args?: Record<string, any> };
  emitEvent?: (event: ObsEvent) => void;
  emitState?: (state: ObsConnectionState) => void;
} => {
  let fallbackCb: ((e: ObsEvent) => void) | undefined;
  let stateCb: ((s: ObsConnectionState) => void) | undefined;
  return {
    send: vi.fn(async function (
      this: any,
      command: string,
      args?: Record<string, any>,
    ) {
      this.lastSend = { command, args };
      return {
        requestType: command,
        requestId: 'test-id',
        requestStatus: { result: true, code: 100 },
        responseData: { echo: args ?? {} },
      } as RequestResponse;
    }),
    sendBatch: vi.fn(
      async (_: BatchRequest[]): Promise<RequestBatchResponse> => ({
        requestId: 'batch-id',
        results: [],
      }),
    ),
    subscribe: vi.fn(async (_: number) => undefined),
    on: vi.fn(),
    off: vi.fn(),
    onAny: vi.fn((cb: (e: ObsEvent) => void) => {
      fallbackCb = cb;
    }),
    offAny: vi.fn(),
    onStateChanged: vi.fn((cb: (s: ObsConnectionState) => void) => {
      stateCb = cb;
    }),
    offStateChanged: vi.fn(),
    close: vi.fn(async () => undefined),
    negotiatedRpcVersion: 1,
    get emitEvent() {
      return fallbackCb;
    },
    get emitState() {
      return stateCb;
    },
  };
};

describe('ObsWebSocket facade (node)', () => {
  it('delegates .send() to the Dart handle', async () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    const res = await obs.send('GetVersion');
    expect(res?.requestType).toBe('GetVersion');
    expect(handle.send).toHaveBeenCalledWith('GetVersion', undefined);
  });

  it('scenes.getSceneList() issues GetSceneList', async () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    await obs.scenes.getSceneList();
    expect(handle.send).toHaveBeenCalledWith('GetSceneList', undefined);
  });

  it('inputs.setInputMute(name, true) issues SetInputMute', async () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    await obs.inputs.setInputMute(true, 'Mic');
    expect(handle.send).toHaveBeenCalledWith('SetInputMute', {
      inputName: 'Mic',
      inputMuted: true,
    });
  });

  it('forwards onAny events through the EventEmitter', async () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    const received: ObsEvent[] = [];
    obs.on('SceneCreated', (e: ObsEvent) => received.push(e));

    const fire = (handle as any).emitEvent as (e: ObsEvent) => void;
    fire({
      eventType: 'SceneCreated',
      eventIntent: 4,
      eventData: { sceneName: 'Foo' },
    });

    expect(received).toHaveLength(1);
    expect(received[0]!.eventData.sceneName).toBe('Foo');
  });

  it('forwards connection state changes through the EventEmitter', () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    const states: ObsConnectionState[] = [];
    obs.on('connectionStateChange', (s: ObsConnectionState) => states.push(s));

    const fire = (handle as any).emitState as (s: ObsConnectionState) => void;
    fire('reconnecting');
    fire('connected');

    expect(states).toEqual(['reconnecting', 'connected']);
  });

  it('connect() forwards autoReconnect options to the Dart runtime', async () => {
    const connect = vi.fn(async () => makeStubHandle());
    (globalThis as any).ObsWebSocketJs = { connect, version: '5.7.4' };

    await ObsWebSocket.connect(
      'ws://localhost:4455',
      {
        password: 'pw',
        autoReconnect: true,
        maxReconnectAttempts: 3,
        reconnectBaseDelayMs: 500,
        reconnectMaxDelayMs: 9000,
      },
      async () => {},
    );

    expect(connect).toHaveBeenCalledWith(
      'ws://localhost:4455',
      'pw',
      120,
      undefined,
      true,
      3,
      500,
      9000,
    );
  });

  it('disconnect() closes the handle and removes listeners', async () => {
    const handle = makeStubHandle();
    const obs = TestableObs.fromHandle(handle);
    obs.on('SceneCreated', () => {});
    await obs.disconnect();
    expect(handle.close).toHaveBeenCalled();
    expect(obs.listenerCount('SceneCreated')).toBe(0);
  });
});
