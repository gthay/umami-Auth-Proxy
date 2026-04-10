# Umami Proxy for Railway

Single-repo nginx proxy image for Railway that can run in three modes:

- `collector`: public tracking surface only
- `admin`: protected dashboard and admin API
- `combined`: legacy single-host mode

For the split deployment, run **two Railway services from this same repo**:

- one service with `PROXY_MODE=collector`
- one service with `PROXY_MODE=admin`

Both talk to the same private Umami service over Railway private networking.

## Why Split The Hostnames

The public tracking host only needs collector routes. The admin host needs the dashboard, `/_next/*`, and privileged `/api/*`.

If you expose both on one hostname, most of Umami's authenticated API surface is still internet-reachable. Splitting the hostnames lets the public host deny everything except collectors, while the admin host protects the full dashboard and admin API.

## Modes

| `PROXY_MODE` | Purpose | Auth required | Public routes |
|---|---|---|---|
| `collector` | Public tracking endpoint | No | `/script.js`, `/umami.js`, `/tracker.js`, `/api/send`, `/api/batch`, `/p/*`, `/q/*`, `/health` |
| `admin` | Protected dashboard and admin API | Yes | `/health` only |
| `combined` | Backward-compatible single-host mode | Yes | Collector routes plus protected dashboard |

`combined` is kept as a migration fallback. For the stronger setup, use `collector` + `admin`.

## Security Model

### `collector` mode

- Public collector routes are rate-limited.
- All non-collector paths return `404`.
- No dashboard pages or privileged `/api/*` routes are exposed.

### `admin` mode

- HTTP Basic Auth protects the full Umami app surface.
- `/api/*`, `/_next/*`, pages, and assets are all behind the same auth boundary.
- `/api/auth/login` gets a tighter rate limit than the rest of the app.

### Common hardening

- Client IP is extracted from the first `X-Forwarded-For` hop and validated before use.
- `X-Forwarded-Proto` preserves Railway's original upstream protocol instead of nginx's internal HTTP hop.
- `server_tokens off`
- Security headers on all responses
- Proxy timeouts
- `UMAMI_HOST` format validation before templating

## Railway Deployment

### 1. Keep Umami private

On the Umami Railway service:

- remove any public domain
- keep private networking enabled

### 2. Create two proxy services from this repo

Create both in the same Railway project:

- `umami-collector-proxy`
- `umami-admin-proxy`

Both should point at the same repo.

### 3. Set environment variables

#### Collector proxy

| Variable | Example | Notes |
|---|---|---|
| `PROXY_MODE` | `collector` | Required |
| `UMAMI_HOST` | `umami.railway.internal:3000` | Required |

#### Admin proxy

| Variable | Example | Notes |
|---|---|---|
| `PROXY_MODE` | `admin` | Required |
| `UMAMI_HOST` | `umami.railway.internal:3000` | Required |
| `AUTH_USER` | `admin` | Required |
| `AUTH_PASS` | `s3cureP@ssw0rd!` | Required |

#### Legacy single-host mode

| Variable | Example | Notes |
|---|---|---|
| `PROXY_MODE` | `combined` | Optional, default if unset |
| `UMAMI_HOST` | `umami.railway.internal:3000` | Required |
| `AUTH_USER` | `admin` | Required |
| `AUTH_PASS` | `s3cureP@ssw0rd!` | Required |

### 4. Give each proxy its own public domain

Recommended DNS layout:

- `collect.example.com` -> collector proxy
- `admin.example.com` -> admin proxy

### 5. Use the collector hostname in your tracking snippet

```html
<script defer src="https://collect.example.com/script.js"
        data-website-id="your-website-id"></script>
```

Use the collector hostname explicitly. In split mode, do **not** rely on the dashboard origin for the tracking snippet unless you have separately configured Umami to emit the collector host.

## Local Examples

### Collector mode

```bash
docker build -t umami-proxy .
docker run -p 8080:8080 \
  -e PROXY_MODE=collector \
  -e UMAMI_HOST=host.docker.internal:3000 \
  umami-proxy
```

### Admin mode

```bash
docker build -t umami-proxy .
docker run -p 8080:8080 \
  -e PROXY_MODE=admin \
  -e AUTH_USER=admin \
  -e AUTH_PASS=testpass \
  -e UMAMI_HOST=host.docker.internal:3000 \
  umami-proxy
```

## Files

- `nginx.conf`: combined legacy mode
- `nginx.admin.conf`: protected admin host
- `nginx.collect.conf`: public collector host
- `entrypoint.sh`: mode selection and config templating

## Limitations

- Public collectors are still public. This design reduces privileged attack surface; it does not stop fake analytics submission.
- Railway-specific forwarding assumptions should not be copied unchanged to other platforms.
- If you need public share links, they are not exposed in `collector` mode today. Keep them on the admin host or add a separate public-share mode intentionally.
- This is not a WAF. Collector routes are still application-exposed.
