# Deployment package for Curatering

This folder explains how to build the web app and backend services and how to package artifacts for deployment.

Prerequisites
- Install Flutter (stable) and ensure `flutter` on PATH.
- Install Docker (for `ai-service` image) if you plan to run the AI service in a container.
- Install Node.js/npm to run the `server` locally (optional for packaging if `node_modules` already present).

Build steps (local)

1. Build Flutter web

```powershell
cd curatering
flutter pub get
flutter build web --release --web-renderer html --tree-shake-icons --source-maps --pwa-strategy none
```

Output: `curatering/build/web` (static files to serve)

2. Prepare Node server

If you have `npm` available:

```powershell
cd server
npm ci
# or: npm install
```

The server entrypoint is `server/src/index.js`. Use environment variables from `.env` or `.env.example`.

3. Build AI service (Docker)

From repository root:

```bash
cd ai-service
docker build -t curatering-ai:latest .
```

This builds a container exposing port 8000 by default (see `ai-service/Dockerfile`).

Packaging

From repository root you can run the provided PowerShell script which collects the web build, server files, and AI service files into a zip:

```powershell
.
\scripts\package_deploy.ps1
# Produces deploy_package.zip in repo root
```

Deployment notes
- Serve the web static files from any static host (Netlify, Vercel, S3+CloudFront, nginx, etc.).
- Run the Node server on a host with access to your database. This project uses Supabase-managed Postgres by default — set `DATABASE_URL` to your Supabase project's PostgreSQL connection string (the "Connection string (pg)" or pooler URL). See `server/.env.example` for an example.
- Supabase notes: use the pooler connection string (contains `pooler.supabase.com`) for better connection pooling. The server's DB helper enables SSL for Supabase connections automatically. If you use a different host, ensure `DATABASE_URL` or the `DB_*` vars are set.
- Run the AI service container where GPUs/CPU resources are available. The Dockerfile installs CPU PyTorch wheels by default; adjust for GPU if needed.

Supabase-specific guidance
- Provide the full `DATABASE_URL` in your production environment (example format):

```
postgresql://USER:PASSWORD@aws-1-ap-southeast-2.pooler.supabase.com:5432/postgres
```

- If you deploy to a platform that injects connection pools or requires SSL enforcement, the server respects `DATABASE_URL` and will enable `ssl: { rejectUnauthorized: false }` for known Supabase hosts.
- The server runs `initDb()` on startup and will create required tables automatically; ensure the service has permission to run migrations against your Supabase DB (the default DB connection string from Supabase works for this).
- For sensitive operations or Supabase Admin API usage, keep service keys out of source control and store them in your host's secret manager.

If you want, I can:
- Build and test the Docker image for `ai-service` (requires Docker available here).
- Create a `docker-compose.yml` to run `server` + `ai-service` + Postgres for local staging.
