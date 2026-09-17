export interface Env {
  AI: { run(model: string, input: unknown): Promise<{ response?: string }> };
  niems_db: D1Database;
  CHANNEL_SECRET: string;
  CHANNEL_ACCESS_TOKEN: string;
  DASHBOARD_API_TOKEN: string;
  ALLOWED_ORIGIN?: string;
}

type LineEvent = {
  type?: string;
  replyToken?: string;
  message?: { type?: string; text?: string };
};

const MAX_BODY_BYTES = 128 * 1024;
const MAX_EVENTS = 20;
const MAX_MESSAGE_CHARS = 4000;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ status: 'ok' });
    }

    if (request.method === 'GET' && (url.pathname === '/json' || url.pathname === '/api/notes')) {
      if (!isAuthorized(request, env.DASHBOARD_API_TOKEN)) {
        return json({ error: 'unauthorized' }, 401);
      }

      const { results } = await env.niems_db
        .prepare('SELECT id, subject, activity_date, activity_type_code, created_at FROM activity_instances ORDER BY created_at DESC LIMIT 100')
        .all();
      return json({ results }, 200, env.ALLOWED_ORIGIN);
    }

    if (request.method === 'POST' && url.pathname === '/webhook') {
      const declaredLength = Number(request.headers.get('content-length') || 0);
      if (declaredLength > MAX_BODY_BYTES) return json({ error: 'payload_too_large' }, 413);

      const rawBody = await request.text();
      if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
        return json({ error: 'payload_too_large' }, 413);
      }

      const signature = request.headers.get('x-line-signature') || '';
      if (!(await verifyLineSignature(rawBody, signature, env.CHANNEL_SECRET))) {
        return json({ error: 'invalid_signature' }, 401);
      }

      let payload: { events?: LineEvent[] };
      try {
        payload = JSON.parse(rawBody);
      } catch {
        return json({ error: 'invalid_json' }, 400);
      }

      const events = Array.isArray(payload.events) ? payload.events.slice(0, MAX_EVENTS) : [];
      ctx.waitUntil(Promise.all(events.map((event) => handleEvent(event, env))).then(() => undefined));
      return json({ accepted: events.length }, 202);
    }

    return json({ error: 'not_found' }, 404);
  },
};

function isAuthorized(request: Request, expectedToken: string): boolean {
  if (!expectedToken) return false;
  return request.headers.get('authorization') === `Bearer ${expectedToken}`;
}

export async function verifyLineSignature(body: string, signature: string, secret: string): Promise<boolean> {
  if (!signature || !secret) return false;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  const expected = btoa(String.fromCharCode(...new Uint8Array(digest)));
  return timingSafeEqual(signature, expected);
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}

async function handleEvent(event: LineEvent, env: Env): Promise<void> {
  if (event.type !== 'message' || event.message?.type !== 'text' || !event.replyToken) return;
  const message = (event.message.text || '').slice(0, MAX_MESSAGE_CHARS);
  if (!message) return;

  const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [
      { role: 'system', content: 'Extract the Thai activity report as one JSON object with keys: what, when, where, who_person, who_org, with_whom, quantity, curriculum, why, project, activity_type. Return JSON only.' },
      { role: 'user', content: message },
    ],
  });

  const parsed = parseAiJson(response.response || '');
  const evidenceId = crypto.randomUUID();
  const activityId = crypto.randomUUID();

  await env.niems_db.prepare(
    "INSERT INTO evidence_assets (id, evidence_type, title, created_at) VALUES (?, 'document', ?, datetime('now'))",
  ).bind(evidenceId, stringValue(parsed.what, 'LINE activity')).run();

  await env.niems_db.prepare(
    `INSERT INTO activity_instances
      (id, subject, activity_date, description_raw, location_text, participant_count,
       activity_type_code, evidence_asset_id, extracted_entities, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
  ).bind(
    activityId,
    stringValue(parsed.what, 'Untitled activity'),
    validDate(parsed.when),
    message,
    stringValue(parsed.where, null),
    integerValue(parsed.quantity),
    stringValue(parsed.activity_type, 'other'),
    evidenceId,
    JSON.stringify({
      who_person: parsed.who_person ?? null,
      who_org: parsed.who_org ?? null,
      with_whom: parsed.with_whom ?? null,
      curriculum: parsed.curriculum ?? null,
      why: parsed.why ?? null,
      project: parsed.project ?? null,
    }),
  ).run();

  await replyToLine(env.CHANNEL_ACCESS_TOKEN, event.replyToken, 'บันทึกกิจกรรมเรียบร้อย');
}

function parseAiJson(value: string): Record<string, unknown> {
  const start = value.indexOf('{');
  const end = value.lastIndexOf('}');
  if (start < 0 || end < start) throw new Error('AI response did not contain JSON');
  const parsed = JSON.parse(value.slice(start, end + 1));
  if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') throw new Error('AI response was not an object');
  return parsed as Record<string, unknown>;
}

function stringValue(value: unknown, fallback: string | null): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().slice(0, 500) : fallback;
}

function integerValue(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function validDate(value: unknown): string | null {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`)) ? value : null;
}

async function replyToLine(accessToken: string, replyToken: string, text: string): Promise<void> {
  if (!accessToken) return;
  const response = await fetch('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ replyToken, messages: [{ type: 'text', text }] }),
  });
  if (!response.ok) throw new Error(`LINE reply failed with status ${response.status}`);
}

function json(body: unknown, status = 200, allowedOrigin?: string): Response {
  const headers = new Headers({ 'content-type': 'application/json; charset=utf-8' });
  if (allowedOrigin) headers.set('access-control-allow-origin', allowedOrigin);
  return new Response(JSON.stringify(body), { status, headers });
}
