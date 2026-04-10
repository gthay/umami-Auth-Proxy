# Umami Auth Proxy for Railway

Nginx reverse proxy that adds **HTTP Basic Auth** and **rate limiting** in front of your Umami dashboard, while keeping the tracking endpoints public.

## What stays public (no auth)

| Path | Purpose |
|---|---|
| `/script.js`, `/umami.js`, `/tracker.js` | Tracking script |
| `/api/send` | Event collection endpoint |
| `/share/*` | Shared dashboard links |
| `/health` | Health check for Railway |

## What gets protected

Everything else — the dashboard UI, all other API routes, and the Umami login endpoint (which gets an extra-tight rate limit).

## Rate limits

- **Login** (`/api/auth/login`): 5 req/s per IP, burst 10
- **Dashboard** (everything else): 20 req/s per IP, burst 40
- Exceeding the limit returns HTTP `429 Too Many Requests`

---

## Deploy on Railway

### 1. Push this folder to a GitHub repo

Or use Railway's "Deploy from GitHub" directly.

### 2. Add a new service in your Railway project

In the same project where your Umami template is running:

- Click **"+ New"** → **"GitHub Repo"** → select the repo with these files
- Or use **"+ New"** → **"Docker Image"** if you've built and pushed it to a registry

### 3. Set environment variables on the proxy service

| Variable | Value | Example |
|---|---|---|
| `AUTH_USER` | Your chosen username | `admin` |
| `AUTH_PASS` | A strong password | `s3cureP@ssw0rd!` |
| `UMAMI_HOST` | Umami's **internal** Railway hostname + port | `umami.railway.internal:3000` |
| `PORT` | Must be `8080` (matches nginx listen) | `8080` |

> **Finding UMAMI_HOST:** In your Railway project, click on the Umami service → Settings → Networking. The internal DNS name will look like `umami.railway.internal`. Umami's default port is `3000`.

### 4. Configure networking

**On the proxy service:**
- Go to Settings → Networking → **Generate Domain** (this becomes your public URL)

**On the Umami service:**
- Go to Settings → Networking → **Remove the public domain** (if one exists)
- Make sure **Private Networking** is enabled (it is by default)

Now the only way to reach Umami from the internet is through the proxy.

### 5. Update your tracking script

On your websites, update the Umami script tag to point to the proxy's public domain:

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

Then visit `http://localhost:8080` — you should get a browser auth prompt.
