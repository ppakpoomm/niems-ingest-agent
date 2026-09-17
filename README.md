# NIEMS Ingest Agent

A privacy-conscious Cloudflare Worker prototype that receives signed LINE webhook events, extracts structured activity data with Workers AI, stores evidence-linked records in D1, and exposes a token-protected dashboard API.

> Status: early open-source prototype. It is not an official NIEMS production service and contains no production credentials or operational data.

## Security properties

- Verifies `x-line-signature` before processing webhook data
- Limits request size, event count, and message length
- Protects `/json` and `/api/notes` with `DASHBOARD_API_TOKEN`
- Uses Wrangler secrets for LINE and dashboard credentials
- Returns only a minimal activity projection from dashboard endpoints

## Local development

Requirements: Node.js 20+ and npm 10+.

```powershell
npm ci
npm run typecheck
npm test
Copy-Item .env.example .dev.vars
npm run dev
```

Replace the placeholder D1 `database_id` in `wrangler.toml` for your own account. Configure secrets without committing them:

```powershell
npx wrangler secret put CHANNEL_SECRET
npx wrangler secret put CHANNEL_ACCESS_TOKEN
npx wrangler secret put DASHBOARD_API_TOKEN
```

Initialize a local database with `schema.sql`. `schema_full_v1.1.1.sql` is an experimental broader data model and is not required by the worker.

## Endpoints

| Method | Path | Access | Purpose |
|---|---|---|---|
| `GET` | `/health` | Public | Health signal |
| `POST` | `/webhook` | Valid LINE signature | Ingest events |
| `GET` | `/api/notes` | Dashboard bearer token | Latest activity projection |
| `GET` | `/json` | Dashboard bearer token | Compatibility alias |

## Data handling

LINE messages may contain personal or operational information. Operators are responsible for consent, retention, access control, and applicable law. Never use production payloads as test fixtures or include them in issues.

See [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
