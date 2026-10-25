/**
 * Browser environment smoke test — verifies the facade works under happy-dom
 * with the same stubbed handle as the Node tests. Real browser E2E needs a
 * dart2js build step and is covered manually in CI.
 *
 * @vitest-environment happy-dom
 */

import { describe, expect, it, vi } from 'vitest';
import type { ObsEvent, ObsJsHandle } from '../src/types.js';
import { ObsWebSocket } from '../src/index.js';

class TestableObs extends ObsWebSocket {
  static fromHandle(h: ObsJsHandle) {
    return new TestableObs(h);
  }
}

describe('ObsWebSocket facade (browser)', () => {
  it('runs under happy-dom and emits events', () => {
    expect(typeof window).toBe('object');
    let fallback: ((e: ObsEvent) => void) | undefined;

    const handle: ObsJsHandle = {
      send: vi.fn(),
      sendBatch: vi.fn(),
      subscribe: vi.fn(),
      on: vi.fn(),
      off: vi.fn(),
      onAny: vi.fn((cb: (e: ObsEvent) => void) => {
        fallback = cb;
      }),
      offAny: vi.fn(),
      onStateChanged: vi.fn(),
      offStateChanged: vi.fn(),
      close: vi.fn(),
      negotiatedRpcVersion: 1,
    };
    const obs = TestableObs.fromHandle(handle);

    const received: ObsEvent[] = [];
    obs.on('*', (e: ObsEvent) => received.push(e));

    fallback!({
      eventType: 'InputMuteStateChanged',
      eventIntent: 8,
      eventData: { inputName: 'Mic', inputMuted: true },
    });

    expect(received).toHaveLength(1);
    expect(received[0]!.eventType).toBe('InputMuteStateChanged');
  });
});
