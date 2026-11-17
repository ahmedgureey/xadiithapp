# Deploying the Xadiis API on Coolify

> **Status: nothing has been deployed yet.** This is a step-by-step plan. It was written against Coolify v4. Menu names can differ slightly between Coolify versions.
> The Docker image has **not** been built locally (Docker was not available on the dev machine). The build will happen for the first time on the Coolify server.

The API lives in `backend/` of this repository. Coolify builds it from `backend/Dockerfile`. On every start the container runs `prisma migrate deploy` and then `node dist/main.js`.

---

## 0. What you must provide yourself

| Item | Notes |
| --- | --- |
| A server with Coolify v4 installed | Ubuntu 22.04/24.04, at least 2 GB RAM recommended. Install: <https://coolify.io/docs/get-started/installation> |
| A domain and DNS access | Create an `A` (and/or `AAAA`) record, e.g. `api.example.com` pointing to the server's public IP |
| The GitHub repository | Connected to Coolify through the GitHub App (private repos) or as a public repo URL |
| Secrets | Generate locally, store only in Coolify. Never commit them (see below) |
| S3-compatible bucket (recommended) | For automated Postgres backups (AWS S3, Cloudflare R2, Backblaze B2, MinIO, ...) |

Generate secrets:

```bash
openssl rand -base64 48   # JWT_ACCESS_SECRET
openssl rand -base64 32   # PostgreSQL password (if you set it yourself)
```

Firewall: only ports 22, 80 and 443 (plus 8000 for the Coolify UI, ideally restricted to your IP) should be open. **Do not open 5432.**

---

## 1. Create a project

1. Coolify UI, then **Projects**, then **+ Add**. Name it `xadiis`.
2. Open the `production` environment (created by default).

## 2. Add the PostgreSQL resource (internal only)

1. In the environment: **+ New**, then **Databases**, then **PostgreSQL**. Pick version **16**.
2. Set (or keep the generated values):
   - Username: `xadiis`
   - Password: a strong random value
   - Initial database: `xadiis`
3. Leave **"Make it publicly available" OFF**. The database is then reachable only on Coolify's internal Docker network.
4. **Start** the database.
5. Copy the **"Postgres URL (internal)"** shown on the database page. It looks like
   `postgresql://xadiis:<password>@<internal-hostname>:5432/xadiis`.
   The hostname is Coolify's internal container name (a uuid-like string), **not** `localhost` or the public IP.

> `pg_trgm` is created by the app's migration. It is a trusted extension, so the database owner (`xadiis`) can create it. Nothing extra is needed on the official Postgres image.

## 3. Add the API application

1. In the same environment: **+ New**, then **Public Repository** (or **Private Repository (with GitHub App)**). Select this repo and the branch, e.g. `main`.
2. **Build Pack: `Dockerfile`**
3. **Base Directory: `/backend`**
4. **Dockerfile Location: `/Dockerfile`** (relative to the base directory)
5. **Ports Exposes: `3000`**
6. Save.

### Environment variables

Under the application, go to **Environment Variables** (mark the secrets as *secret/locked*):

| Name | Value |
| --- | --- |
| `DATABASE_URL` | the **internal** Postgres URL from step 2.5 |
| `JWT_ACCESS_SECRET` | output of `openssl rand -base64 48` |
| `JWT_ACCESS_TTL` | `900` |
| `JWT_REFRESH_TTL_DAYS` | `30` |
| `NODE_ENV` | `production` |
| `PORT` | `3000` |
| `TRUST_PROXY` | `true` (Coolify's Traefik proxy sits in front, so rate limits use the real client IP) |
| `CORS_ORIGINS` | empty (the mobile app doesn't need CORS). Set e.g. `https://admin.example.com` only if a browser front-end calls the API |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | optional, only for the first seed (see step 6). Remove them afterwards |

The app refuses to start if `DATABASE_URL` or `JWT_ACCESS_SECRET` is missing, or if the secret is shorter than 32 characters. In that case check the deployment logs.

### Domain and HTTPS

1. In the application's **Domains** field enter `https://api.example.com`. The `https://` scheme matters: it tells Coolify's proxy to request a Let's Encrypt certificate automatically.
2. Make sure the DNS record from step 0 already points to the server, otherwise the ACME challenge fails.
3. Coolify's proxy (Traefik) terminates TLS and redirects HTTP to HTTPS.

### Health check

- The image has a Docker `HEALTHCHECK` (`wget http://127.0.0.1:3000/api/v1/health`).
- In Coolify, **Configuration**, then **Healthcheck**, you can enable it with **Path `/api/v1/health`**, **Port `3000`**, method GET, expected status 200.
- The endpoint returns `503` with `"database": "down"` when Postgres is unreachable, so Coolify marks the container unhealthy.

## 4. Deploy

Click **Deploy**. Coolify clones the repo, builds `backend/Dockerfile` (multi-stage, `node:24-alpine`, `prisma generate`, `nest build`, non-root `node` user) and starts the container.

**Migrations run automatically** on every container start via `docker-entrypoint.sh`:

```
prisma migrate deploy   # applies any pending migrations in prisma/migrations
node dist/main.js
```

Set `RUN_MIGRATIONS=false` if you ever run several replicas and prefer to migrate from a one-off command.

Verify:

```bash
curl https://api.example.com/api/v1/health
# {"status":"ok","database":"up","version":"1.0.0","timestamp":"..."}
open https://api.example.com/api/docs     # Swagger UI
```

Enable **Auto Deploy** (on push) in the application settings if you want continuous deployment from the branch.

## 5. Seed reference data (books and categories)

The seed is idempotent. It inserts the 6 book records and 10 categories, and **no hadith content**.

Application, then **Terminal** (or `docker exec` on the server):

```bash
npm run seed:prod
```

## 6. Create the first admin

Option A: set `SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD` (at least 12 chars) as env vars, redeploy, run `npm run seed:prod` in the terminal, then **remove both variables** and redeploy.

Option B: register normally through `POST /api/v1/auth/register`, then promote the account in the database:

```sql
UPDATE users SET role = 'ADMIN' WHERE email = 'you@example.com';
```

(Open a SQL shell from the Postgres resource's **Terminal**: `psql -U xadiis -d xadiis`.) The new role takes effect at the next login or token refresh.

## 7. Backups

### Scheduled backups (Coolify, to S3)

1. **Settings**, then **S3 Storages** (or **Storages**): add your S3-compatible bucket (endpoint, region, bucket, access key, secret) and click **Validate**.
2. Open the PostgreSQL resource, then **Backups**, then **+ Add**:
   - Frequency: e.g. `0 3 * * *` (daily 03:00) or `@daily`
   - Enable **Save to S3** and choose the storage
   - Set retention (number of backups to keep locally and on S3)
3. Click **Backup Now** once and check that the file shows up in the bucket.
4. **Test a restore** into a scratch database at least once.

### Manual dump and restore

On the server (find the container name with `docker ps | grep postgres`):

```bash
# Dump (custom format, compressed)
docker exec -t <postgres-container> pg_dump -U xadiis -d xadiis -Fc -f /tmp/xadiis.dump
docker cp <postgres-container>:/tmp/xadiis.dump ./xadiis-$(date +%F).dump

# Restore into an existing (empty or to-be-overwritten) database
docker cp ./xadiis-YYYY-MM-DD.dump <postgres-container>:/tmp/restore.dump
docker exec -t <postgres-container> pg_restore -U xadiis -d xadiis --clean --if-exists --no-owner /tmp/restore.dump
```

Stop the API (or scale it to 0) during a restore, then start it again. Migrations that are already recorded in `_prisma_migrations` are skipped.

## 8. Rollback

- **Application code:** Coolify keeps previous images. In the application, open **Deployments** and redeploy/rollback to an earlier deployment, or redeploy a specific earlier commit.
- **Database schema:** Prisma migrations are forward-only. If a release added a migration, rolling the code back does **not** undo it. Either:
  - keep migrations backward-compatible (add columns/tables first, remove them in a later release), so the old code still works with the new schema, or
  - restore the pre-deploy backup (take a manual **Backup Now** before risky releases).
- Never edit or delete a migration that has already been applied in production.

## 9. Alternative: Docker Compose build pack

`backend/docker-compose.yml` defines `db` (postgres:16-alpine, named volume, **no published ports**) and `api`. In Coolify you can choose **Build Pack: Docker Compose**, base directory `/backend`, then set `POSTGRES_PASSWORD` and `JWT_ACCESS_SECRET` in the env UI and assign the domain to the `api` service (port 3000). The separate PostgreSQL resource (steps 2-3) is still recommended, because Coolify's one-click backups apply to database resources.

## 10. Checklist

- [ ] DNS `api.example.com` points to the server
- [ ] Postgres resource running, public port **disabled**
- [ ] API env vars set (`DATABASE_URL` internal, `JWT_ACCESS_SECRET`, `TRUST_PROXY=true`)
- [ ] Domain set with `https://`, certificate issued
- [ ] `/api/v1/health` returns `ok` / `up`
- [ ] `npm run seed:prod` executed
- [ ] Admin account created, `SEED_ADMIN_*` removed
- [ ] S3 backups scheduled and a restore tested
- [ ] Flutter app configured with base URL `https://api.example.com/api/v1`
