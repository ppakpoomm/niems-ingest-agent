import { describe, expect, it } from 'vitest';
import worker, { verifyLineSignature, type Env } from '../src/index';

function context(): ExecutionContext {
  return { waitUntil: () => undefined, passThroughOnException: () => undefined, props: {} } as ExecutionContext;
}

function env(): Env {
  return {
    AI: { run: async () => ({ response: '{"what":"ทดสอบ","when":"2026-09-17"}' }) },
    niems_db: { prepare: () => ({ all: async () => ({ results: [] }) }) } as unknown as D1Database,
    CHANNEL_SECRET: 'secret',
    CHANNEL_ACCESS_TOKEN: '',
    DASHBOARD_API_TOKEN: 'dashboard-token',
  };
}

describe('worker', () => {
  it('exposes a health endpoint', async () => {
    const response = await worker.fetch(new Request('https://example.test/health'), env(), context());
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'ok' });
  });

  it('protects dashboard data', async () => {
    const unauthorized = await worker.fetch(new Request('https://example.test/api/notes'), env(), context());
    expect(unauthorized.status).toBe(401);

    const authorized = await worker.fetch(new Request('https://example.test/api/notes', {
      headers: { authorization: 'Bearer dashboard-token' },
    }), env(), context());
    expect(authorized.status).toBe(200);
  });

  it('rejects an unsigned webhook', async () => {
    const response = await worker.fetch(new Request('https://example.test/webhook', {
      method: 'POST',
      body: '{"events":[]}',
    }), env(), context());
    expect(response.status).toBe(401);
  });

  it('verifies a LINE HMAC signature', async () => {
    const body = '{"events":[]}';
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode('secret'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const digest = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
    const signature = btoa(String.fromCharCode(...new Uint8Array(digest)));
    expect(await verifyLineSignature(body, signature, 'secret')).toBe(true);
    expect(await verifyLineSignature(body, `${signature}x`, 'secret')).toBe(false);
  });
});
