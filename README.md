# Umami Auth Proxy for Railway

Hardened nginx reverse proxy that adds **HTTP Basic Auth**, **per-IP rate limiting**, and **request size caps** in front of your Umami dashboard, while keeping the tracking endpoints public.

## Security model

### What stays public (no auth)

| Path | Rate limit | Body limit | Why |
|---|---|---|---|
| `/api/send` | 30 req/s per IP | 4 KB | Tracking data ingestion |
| `/script.js`, `/umami.js`, `/tracker.js` | 30 req/s per IP | — | Tracking script |
| `/share/*` | 20 req/s per IP | — | Shared dashboard links |
| `/health` | — | — | Railway health check |
| `/_next/*`, `/favicon.ico`, `/site.webmanifest` | — | — | Static assets |

### What requires HTTP Basic Auth

| Path | Rate limit | Body limit | Purpose |
|---|---|---|---|
| `/api/auth/login` | **2 req/s per IP** | 1 KB | Umami login — tightest limit |
| `/` (all dashboard pages) | 20 req/s per IP | 8 KB | Dashboard UI |

### What is protected by Umami's own JWT

| Path | Rate limit | Body limit |
|---|---|---|
| `/api/*` (except login + send) | 20 req/s per IP | 64 KB |

### Hardening measures

- **Real client IP extraction**: Rate limits key on `X-Forwarded-For`, not Railway's internal proxy IP
- **`server_tokens off`**: Hides nginx version from `Server` header and error pages
- **Security headers**: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`
- **Proxy timeouts**: 10s connect, 30s read/send — prevents slowloris-style stalling
- **Input validation**: `UMAMI_HOST` is validated against `host:port` format before templating
- **No credentials in logs**: Username and upstream host are not logged

### Known limitations

- **`/api/*` without Basic Auth**: Umami's frontend JS doesn't reliably forward Basic Auth on fetch() calls, so the API relies on Umami's own JWT session auth. If Umami has an auth bypass zero-day, the API is exposed.
- **X-Forwarded-For spoofing**: The first IP in `X-Forwarded-For` is trusted for rate limiting. Railway's edge should always set this correctly, but be aware of this in other environments.
- **No WAF**: This proxy doesn't inspect request bodies for SQL injection, XSS, etc. For that level of protection, consider Cloudflare or a dedicated WAF in front.

---

## Deploy on Railway

### 1. Push this folder to a GitHub repo

### 2. Add a new service in your Railway project

In the same project where your Umami template is running:
**"+ New"** → **"GitHub Repo"** → select the repo

### 3. Set environment variables on the proxy service

| Variable | Value | Example |
|---|---|---|
| `AUTH_USER` | Your chosen username | `admin` |
| `AUTH_PASS` | A strong password | `s3cureP@ssw0rd!` |
| `UMAMI_HOST` | Umami's internal hostname + port | `umami.railway.internal:8080` |
| `PORT` | Must be `8080` | `8080` |

> **Finding UMAMI_HOST:** Click on the Umami service → Settings → Networking. Check the private DNS name and the port Umami is listening on (visible in Umami's deploy logs, e.g. `http://[::]:8080`).

### 4. Configure networking

**On the proxy service:**
- Settings → Networking → **Generate Domain** (public URL)

**On the Umami service:**
- Settings → Networking → **Remove the public domain**
- Ensure **Private Networking** is enabled

### 5. Update your tracking script

```html
<script defer src="https://your-proxy.up.railway.app/script.js"
        data-website-id="your-website-id"></script>
```

---

## Local testing

```bash
docker build -t umami-proxy .
docker run -p 8080:8080 \
  -e AUTH_USER=admin \
  -e AUTH_PASS=testpass \
  -e UMAMI_HOST=host.docker.internal:3000 \
  umami-proxy
```
