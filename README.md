# Middleman

Middleman is a simple proxy and stubbing server built on OpenResty. 

The goal of this project is to provide a way to proxy requests from an application running in a web browser to another server running remotely. I have found this useful when developing front-end applications because you don't need to run the entire stack. This is especially useful when iterating and designing in the browser - it's possible to prototype UIs in the application without getting bogged down with the details of a production web server. 

I also wanted a way to stub endpoints locally, while still hitting the remote API for things like authentication. These are configured in Middleman using Lua tables: 

```lua
return {
  {
    name = "health",
    method = "GET",
    path = "/health",
    response = {
      status = 200,
      json = { status = "ok", source = "stub" },
    },
  },
}
```
If a stub is defined locally, Middleman will use the stub to respond to incoming requests. Otherwise, the request is passed through to the proxy server. 

## Prerequisites

- Docker Desktop (or Docker Engine) with Docker Compose v2 (`docker compose`)

You do not need OpenResty or OpenSSL installed locally.

## First-time setup

1. Create `.env`:

```sh
cp .env.example .env
```

2. Edit `.env` and set your upstream:

```env
UPSTREAM_BASE_URL=https://your-upstream.example.com
```

3. Generate local TLS certs:

```sh
docker run --rm -v "${PWD}:/work" alpine:3.20 sh /work/scripts/generate-certs.sh
```

4. Start:

```sh
docker compose up --build
```

5. Verify:

```sh
curl -k https://localhost:3001/_health
```

## How configuration works

Middleman is configured via `config/project.local.lua` and `config/stubs.local.lua`:

```
touch config/project.local.lua
touch config/stubs.local.lua
```

### `config/project.local.lua`

Override project-level settings. Must return a table.

```lua
return {
  -- Optional: ordered URL rewrite rules (PCRE syntax, first match wins).
  rewrites = {
    { from = "^/local-api/(.*)$", to = "/api/$1" },
    { from = "^/old-path/(.*)$",  to = "/new-path/$1", options = "jo" },
  },

  -- Optional: absolute path to a custom stubs file inside the container.
  -- Defaults to /app/config/stubs.local.lua when not set.
  -- stubs_file = "/app/config/my-stubs.lua",
}
```

Fields:

- `rewrites` (table, optional) — ordered list of rewrite rules. Each rule:
  - `from` (string, required) — PCRE pattern matched against the request path.
  - `to` (string, required) — replacement string (supports capture groups like `$1`).
  - `options` (string, optional) — PCRE options, defaults to `"jo"`.
- `stubs_file` (string, optional) — absolute container path to a custom stubs file.
  When set explicitly, the file must exist or startup will fail.

### `config/stubs.local.lua`

Override stub rules. Must return a table (list of stub definitions).

```lua
return {
  {
    name = "health",
    method = "GET",
    path = "/_health",
    response = {
      status = 200,
      json = { status = "ok", source = "stub" },
    },
  },
  {
    name = "example-post",
    method = "POST",
    path = "/api/example",
    response = {
      status = 201,
      json = { id = 1, created = true },
    },
  },
}
```

Each stub definition:

- `name` (string, optional) — identifier for logging.
- `method` (string, optional) — HTTP method, defaults to `"GET"`.
- `path` (string, required) — exact path to match.
- `enabled` (boolean, optional) — set to `false` to disable a stub without removing it.
- `body_contains` (string, optional) — substring to match in the request body.
- `response` (table, required):
  - `status` (number, optional) — HTTP status code, defaults to `200`.
  - `headers` (table, optional) — map of response headers.
  - `json` (table, optional) — JSON response body.
  - `text` (string, optional) — plain text response body.
  - `file` (string, optional) — file path relative to `/app/` to serve as the response body.

#### Built-in defaults

When no override files exist, Middleman uses these defaults:

- **Project config** — empty (`{}`): no rewrites, default stubs path.
- **Stubs** — a single health-check endpoint:
  `GET /_health` returns `200 { "status": "middleman ok", "source": "stub" }`.

When you create an override file it replaces the defaults entirely (no merging).

### Nginx configuration

The nginx config files under `config/nginx/` are committed to the repository and provide working defaults. Edit them directly when you need to change server blocks, listeners, or proxy behaviour.

- `config/nginx/servers/default.conf` — server blocks (HTTPS on 3001, HTTP on 50010).
- `config/nginx/snippets/proxy-app.conf` — shared CORS headers, Lua hooks, proxy_pass.

If you add a listener on a new container port, also update the `ports` mapping in `docker-compose.yml`.

## Hot reload

Lua hot-reload is enabled (`lua_code_cache off`):

- changes to `config/stubs.local.lua` apply without restart
- changes to `lua/stub_engine/*` apply without restart

Restart required for:

- `.env`
- `docker-compose.yml`
- `nginx/nginx.conf.template`
- `config/project.local.lua`
- `config/nginx/**/*.conf`

## What not to commit

These paths are in `.gitignore`:

- `.env`
- `certs/*.pem`
- `config/*.local.lua`

## Troubleshooting

- **Stubs not matching**: check method, path, and stub name in `config/stubs.local.lua`.
- **No rewrite happening**: rewrites require `config/project.local.lua` with a `rewrites` table. First matching rule wins.
- **nginx starts but no listeners**: check `config/nginx/servers/default.conf` exists and has valid `listen` directives.
- **`no resolver defined to resolve ...`**: restart after pulling latest template; this setup expects Docker DNS (`127.0.0.11`) for variable upstream hosts.
- **Cert errors**: regenerate certs with `docker run --rm -v "${PWD}:/work" alpine:3.20 sh /work/scripts/generate-certs.sh`.
