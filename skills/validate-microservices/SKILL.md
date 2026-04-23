---
name: validate-microservices
description: >
  Use this skill when code changes need to be exercised against real microservice
  dependencies running in a Kubernetes cluster — databases, queues, upstream and
  downstream services — without pushing images for every iteration. The skill does
  not prescribe a workflow; it documents the concrete signals Signadot gives you
  (cluster reachability, streamed service logs, sandbox status and endpoints,
  routing-key isolation) and the command that produces each one, so you can pull
  exactly the feedback you need while iterating.
---

# Signadot: Signals for Microservice Validation

You already know how to iterate: implement, test, read the failure, fix, retest.
What this skill gives you is a map of the feedback Signadot can surface while you
do that against a real cluster — so you can choose the cheapest signal for the
question you're asking instead of defaulting to image builds or `kubectl`.

## Signadot MCP Server

A Signadot MCP server may be available directly in this Claude Code session.
**When it is, use it autonomously** — don't ask the user to run CLI commands for
anything the MCP server can do. Discover tools, call them, read the results, and
act on them without pausing for confirmation. The only exceptions are operations
that touch the user's local network stack (see below).

### How to discover available tools

Use `ToolSearch` to find relevant tools before acting. Search by intent, not by
assumed tool name — the MCP tool list can change between sessions:

- `ToolSearch("signadot cluster")` — tools for listing or inspecting clusters
- `ToolSearch("signadot sandbox")` — tools for creating, reading, or updating sandboxes
- `ToolSearch("signadot routegroup")` — tools for managing routegroups
- `ToolSearch("signadot workload endpoint")` — tools for resolving workloads and endpoints
- `ToolSearch("signadot auth")` — tools for checking authentication

Always load a tool's schema via `ToolSearch` before calling it — calling a tool
without a loaded schema will fail with `InputValidationError`.

### When to act autonomously vs delegate to the user

- **Act autonomously via MCP** for anything on the control plane: list clusters,
  inspect or create or update sandboxes and routegroups, resolve workloads and
  endpoints. Do not ask — just do it and report what you found or changed.
- **Delegate to the user** only for commands that touch the local network stack:
  `signadot local connect/disconnect` require sudo on the user's machine. Print
  the command with a leading `!` and wait for confirmation before proceeding.
- **Run directly** (no delegation needed) for `signadot local proxy` and
  `signadot local status` — these are local processes with no sudo requirement.

## What Signadot exposes as signal

| Signal | Where it comes from | Useful for |
|---|---|---|
| **Local process receives real cluster traffic** | **Local-mapped sandbox** (service runs locally, routing key directs traffic to it) | **Default first choice — validate changes against real deps with no image build** |
| Cluster DNS/IP resolvable from your machine | `signadot local connect` | Reaching cluster services by their in-cluster name from a local process or curl |
| Your modified service's stdout/stderr streaming live | Local sandbox | Watching a request land in your code, seeing panics/logs immediately, attaching a debugger |
| Cluster service endpoints mapped to `localhost:<port>` | `signadot local proxy --map http://svc:port@localhost:port` | Hitting an in-cluster service with curl without changing client code |
| Readiness, forks, and routing state of an in-cluster fork | MCP or `signadot sandbox get <name>` | Knowing whether your sandbox is actually up and routing before you test |
| Preview endpoints that deterministically hit your fork | MCP or `signadot sandbox get <name>` (endpoints block) | Driving your forked service with curl from anywhere, no routing header needed |
| Routing-key isolation (header → fork, no header → baseline) | Any sandbox | Proving the change is scoped to your sandbox and not affecting shared traffic |

Reach for an image build only when the service genuinely can't run locally.
Otherwise the local-mapped sandbox is faster and higher-signal.

## Sandbox creation workflow

### Step 1 — resolve cluster and workload

Use MCP tools. Always check `requiresConfirmation` on every response:
- If true on clusters: show list, ask user to pick one.
- If true on workloads: show candidates, ask user to confirm. Never auto-select.
- If true on devboxes: show list, ask user to confirm.

```
ToolSearch("signadot cluster")  → list_clusters
ToolSearch("signadot workload") → resolve_workload  (single-term query only)
ToolSearch("signadot workload") → resolve_workload_port
ToolSearch("signadot sandbox")  → list_devboxes
```

### Step 2 — check if the Claude Code environment is the devbox

`list_devboxes` often returns a devbox whose `metadata.name` matches the current
hostname. **If you are running inside a Claude Code sandbox** (check `hostname`),
look for a matching devbox — if found, you can run the service right here without
needing `signadot local connect` or any user interaction for the tunnel.

```bash
hostname   # compare against devbox metadata.name in list_devboxes output
```

If the current environment is the devbox, use its `id` as `connection.devboxId`
and run the service locally in this session.

### Step 3 — check for existing sandbox definitions

Before creating a sandbox from scratch, check whether the repo already ships
sandbox definitions. Look in `.signadot/` (the standard location):

```bash
ls .signadot/          # top-level: cluster config, CI/PR templates
ls .signadot/dev/      # per-service local dev sandboxes, if present
```

If a matching definition exists, use it (substituting `@{devbox-id}` with the
devbox ID from `list_devboxes`) rather than building the spec from scratch. This
keeps sandbox names and port mappings consistent with what the team expects.

### Step 4 — create the sandbox via MCP

Call `get_workflow_docs` with `topic: "creating_sandbox"` for the full protocol,
then call `create_sandbox` directly. Key points:

- `connection.devboxId` is required whenever `local` workloads are present.
- The `from` workload must come from `resolve_workload` output — never guess names.
- The `port` in mappings must come from `resolve_workload_port` — never guess.

### Step 5 — wait for ready

After creating, poll `get_sandbox` until `status.ready = true` AND the tunnel
shows `connected: true`. A sandbox that is ready but whose tunnel is not connected
will not route traffic to your local process.

### Step 6 — pull env and config

**First, check the repo README and CLAUDE.md** for documented run commands. Teams
often document the exact env vars and their format (e.g. `MYSQL_ADDR`, `REDIS_ADDR`,
`KAFKA_BROKER_ADDR`). These are ground truth for what the service expects.

Then attempt the automated pull:

```bash
eval $(signadot sandbox get-env <sandbox-name>)
signadot sandbox get-files <sandbox-name>
```

`get-env` requires `~/.kube/config` to be present. **If it fails or is unavailable,
reconstruct env vars via MCP** — do not skip them:

#### MCP-based env reconstruction

**1. Fetch the workload spec via MCP:**

```
ToolSearch("signadot workload") → get_workload_object
```

Call `get_workload_object` with the workload name and namespace. The response
contains the full container spec including `env` and `envFrom` entries.

**2. Classify each env entry and resolve its value:**

| Entry type | How to resolve |
|---|---|
| `value: "literal"` | Use the literal value directly |
| `valueFrom.configMapKeyRef` | Call `get_workload_object` with `kind: ConfigMap`, same namespace, the named key |
| `valueFrom.secretKeyRef` | Call `get_workload_object` with `kind: Secret`, same namespace — values are base64; decode with `echo <val> \| base64 -d` |
| `envFrom.configMapRef` | Call `get_workload_object` with `kind: ConfigMap` — all keys become env vars |
| `envFrom.secretRef` | Call `get_workload_object` with `kind: Secret` — all keys become env vars |

**3. Resolve in-cluster hostnames** from `/etc/hosts` (the devbox injects entries
in the `242.242.x.x` range as `<svc>.<namespace>` and `<svc>.<namespace>.svc`).
Use these addresses for any `*_ADDR`, `*_HOST`, or `*_URL` vars that reference
cluster services.

**4. Export each var explicitly** before starting the service:

```bash
export VAR1=value1
export VAR2=value2
# ...
<start command — see Step 7>
```

Missing env vars (DB addresses, credentials, feature flags) cause silent failures
that look like code bugs — always resolve them fully before concluding the service
is broken.

### Step 7 — find and run the service

Before running, locate the correct entrypoint and start command. Read the repo:
- `Makefile`, `package.json` scripts, `Dockerfile`, `README`, `CLAUDE.md` — these
  reveal how the service is normally started
- Never guess the start command — always derive it from the repo

Compile/build before backgrounding so errors surface immediately rather than
silently dying in the background.

**Backgrounding in a devbox:** plain `&` can receive SIGHUP and silently die
(exit code 144). Use `setsid` with a wrapper script instead:

```bash
cat > /tmp/start_svc.sh << 'EOF'
#!/bin/bash
export VAR=value
exec ./my-service --flag
EOF
chmod +x /tmp/start_svc.sh
setsid /tmp/start_svc.sh >> /tmp/svc.log 2>&1 &
```

After starting, verify the process is alive and the port is listening before
proceeding to validation.

## Validation: hitting the service

### The cardinal rule: never test against `localhost:<port>` directly

**Do not use localhost URLs for validation — not even via `signadot local
proxy`.** Hitting `localhost:<port>` (whether the service port directly or a
proxy port) bypasses the cluster routing path. Downstream calls from your local
service go to the cluster **without** the routing key, so sandboxed consumers
never fire and you are only proving your code runs in isolation.

**Always send traffic to the cluster's in-cluster `.svc` URL with the routing
key header.** The devbox `/etc/hosts` has `<svc>.<namespace>.svc` entries in
the `242.242.x.x` range — use these directly:

```bash
# curl: pass routing key via baggage header on the cluster .svc URL
curl -s http://<svc>.<namespace>.svc:<port>/path \
  -H "baggage: sd-routing-key=<routing-key>"

# gRPC
grpcurl -plaintext \
  -H "baggage: sd-routing-key=<routing-key>" \
  -d '{"field":"value"}' \
  <svc>.<namespace>.svc:<port> package.Service/Method
```

The routing key comes from the sandbox's `routingKey` field in the MCP
`create_sandbox` / `get_sandbox` response.

### Routing key propagation through async protocols

The routing key only reaches downstream services if every intermediate hop
forwards it. For synchronous HTTP/gRPC this is usually automatic via baggage
propagation. **For async protocols (Kafka, SQS, RabbitMQ, etc.) it is not.**

Before testing, read the producer code and confirm the routing key is written
into the message headers/metadata. If it is not, messages dispatched without
the key will be consumed by the baseline cluster service — the sandboxed
consumer will never fire — and tests will appear to work but actually validate
the wrong code path.

Signs that the key is missing from async messages:
- The sandboxed downstream service log shows no activity after a request
- The response looks correct but comes too fast (baseline handled it)
- A feature you know you changed behaves as the old baseline

### Frontend / UI validation — mandatory for any UI-touching change

**API-only checks are not enough.** Even if the backend API returns the correct
response, the UI can still be broken (wrong field name in TypeScript, missing
component update, broken render logic). Always validate the full user flow in a
browser for any change that touches an API contract consumed by the frontend.

**1. Scope: include the frontend in the sandbox.** If you changed backend code
that the frontend consumes (JSON field names, API shape, new endpoints), the
frontend service must be in the sandbox too — running locally with the updated
code. The cluster's old frontend binary will decode the new API incorrectly.

**2. Find how the team runs the frontend locally.** Check `CLAUDE.md`, `Makefile`,
`docker-compose.yml`, or ask the user. **Do not guess the startup command or env
vars.** Wrong service addresses or missing env vars cause silent failures that
look like code bugs.

**3. Inject the routing key into browser requests.** Use Playwright's
`page.setExtraHTTPHeaders()` to inject the routing key on every request, then
navigate to the cluster's in-cluster frontend `.svc` URL:

```js
// Playwright: inject routing key on all requests
await page.setExtraHTTPHeaders({
  'baggage': 'sd-routing-key=<routing-key>'
});
await page.goto('http://<frontend-svc>.<namespace>.svc:<port>/');
```

**4. Exercise the golden path.** Don't just check the page loads. Actually use
the feature: fill in forms, click buttons, trigger the changed behavior, verify
the result renders correctly.

## Iteration loop

The sandbox is where you discover what's broken — not before. Make your change,
sandbox the service, run e2e, and let failures tell you what else needs fixing.

**Loop until all checks pass:**

1. Create a sandbox with the changed service(s) running locally.
2. Hit the e2e path: browser golden path first, then API checks if needed.
3. If a check fails:
   - Read the failure: wrong field, missing data, blank UI element, error response.
   - Determine the cause: service code, wrong env var, a consumer that also needs updating, routing not carrying the key.
   - Fix it. If a consumer service (e.g. frontend) also needs updated code, add it to the sandbox and run it locally too.
   - Restart the affected local service(s) and re-run — **keep the same sandbox** so the routing key stays stable.
4. Only declare done when the full golden path passes end-to-end: correct API response **and** correct UI render.

A passing API check with a blank or broken UI is not done.

## Operational notes

- **Sudo-gated commands must be delegated to the user.** `signadot local
  connect` and `signadot local disconnect` modify the local network stack and
  fall in this bucket. Print the command with a leading `!` and wait.
- **A sandbox only needs to contain the services you changed.** Everything else
  is shared from the baseline cluster. If you changed multiple services, put
  them in the same sandbox so they share one routing key.
- **Update, don't recreate.** Re-run sandbox apply or use MCP update with the
  same name. Deleting and recreating churns the routing key and any tests pinned
  to it.
- **When a test fails, check sandbox state first.** Use MCP `get_sandbox` or
  `signadot sandbox get` to verify `ready: true` and tunnel `connected: true`
  before concluding the code is wrong.
- **Clean up:**
  ```bash
  signadot sandbox delete <sandbox-name>
  ! signadot local disconnect   # if user ran connect
  ```

## Quick reference

| Want to… | How |
|---|---|
| List registered clusters | MCP (search: "signadot cluster") |
| List / inspect sandboxes | MCP (search: "signadot sandbox") |
| Create a sandbox | MCP (search: "signadot sandbox") — call `get_workflow_docs` first |
| Update a sandbox | MCP (search: "signadot sandbox") — call `get_workflow_docs` first |
| Resolve workloads | MCP (search: "signadot workload") — single-term query |
| Resolve endpoints | MCP (search: "signadot workload endpoint") |
| Check if this env is a devbox | `hostname` then compare against `list_devboxes` output |
| Make the cluster reachable locally | `! sudo signadot local connect --cluster <cluster>` (**user runs**) |
| Check the tunnel is up | `signadot local status` |
| Pull env vars for local service | `eval $(signadot sandbox get-env <name>)` — requires kubeconfig; fallback: MCP `get_workload_object` on workload + Secrets/ConfigMaps, then resolve hostnames from `/etc/hosts` (devbox `242.242.x.x` range) |
| Pull config files for local service | `signadot sandbox get-files <name>` |
| Send request with routing key (curl) | `curl -H "baggage: sd-routing-key=<key>" http://<svc>.<ns>.svc:<port>/path` |
| Send request with routing key (grpc) | `grpcurl -H "baggage: sd-routing-key=<key>" -plaintext <svc>.<ns>.svc:<port> Svc/Method` |
| Test browser UI with routing key | Playwright `page.setExtraHTTPHeaders({'baggage':'sd-routing-key=<key>'})` then navigate to cluster `.svc` URL |
| Background a service safely | `setsid /tmp/start.sh >> /tmp/svc.log 2>&1 &` (plain `&` can SIGHUP) |
| Tear down a sandbox | `signadot sandbox delete <sandbox-name>` |
| Disconnect | `! signadot local disconnect` (**user runs**) |
