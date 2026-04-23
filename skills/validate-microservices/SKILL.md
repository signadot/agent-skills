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

```bash
eval $(signadot sandbox get-env <sandbox-name>)
signadot sandbox get-files <sandbox-name>
```

`get-env` requires `~/.kube/config` to be present. If it fails, do not skip env
vars — reconstruct them manually:
1. Use `get_workload_object` MCP to read the workload's container env and pull
   value names and any `valueFrom` references (Secrets, ConfigMaps).
2. Resolve in-cluster hostnames from `/etc/hosts` (devbox injects them as
   `<svc>.<namespace>` entries in the `242.242.x.x` range).
3. Export each var explicitly before starting the service. Missing env vars
   (DB addresses, credentials, feature flags) will cause silent failures that
   look like code bugs.

### Step 7 — find and run the service

Before running, locate the correct entrypoint. Read the repo structure:
- `Makefile`, `package.json` scripts, `Dockerfile`, `README` — these reveal how
  the service is normally started
- `cmd/`, `main.go`, `src/index.*`, `app.py`, `server.*` — language-specific
  entrypoint patterns

Compile/build before backgrounding so errors surface immediately rather than
silently dying in the background. The exact command depends on the language —
read the Makefile or README rather than guessing.

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

Hitting the local service port directly (`curl http://localhost:8080/...`,
`browser → http://localhost:8080`) **bypasses Signadot routing entirely**. The
request goes straight to the local process and never touches the cluster — so
you are only proving your code runs, not that the sandbox routes correctly, and
any downstream calls that go through the cluster will do so **without** the
routing key. In services that use async protocols (Kafka, queues, gRPC streams),
this means the routing key is absent from those messages and downstream sandboxed
consumers will never process them — instead the baseline cluster service handles
the message, and your sandbox code is never exercised end-to-end.

**Always send traffic through the cluster routing path via `signadot local
proxy`.** The proxy injects the routing key on every request automatically:

```bash
signadot local proxy --sandbox <name> \
  --map http://<svc>.<namespace>.svc:<port>@localhost:<local-port> &
# then test via the proxy port:
curl http://localhost:<local-port>/path
```

### Routing key header conventions

The routing key must be sent with the request so Signadot can route it to your
local process. How it's injected depends on the protocol:

- **`signadot local proxy` with `http://` or `grpc://` scheme** — injects the
  routing key automatically. No manual header needed. **Prefer this over direct
  curl for all validation.**
- **Direct curl (when proxy isn't suitable)** — pass it in the `baggage` header:
  ```bash
  curl -s http://localhost:<port>/api \
    -H "baggage: sd-routing-key=<routing-key>"
  ```
- **gRPC (grpcurl)** — same baggage header:
  ```bash
  grpcurl -plaintext \
    -H "baggage: sd-routing-key=<routing-key>" \
    -d '{"field":"value"}' \
    localhost:<port> package.Service/Method
  ```

The routing key comes from the sandbox's `routingKey` field in the MCP response
or `signadot sandbox get` output.

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

### Frontend / UI validation

When a change involves a frontend service, validate interactivity and visual
behavior directly — not just the underlying API. The goal is to confirm that UI
elements render correctly, buttons are clickable, and user flows complete end to
end against real backend dependencies.

**1. Look for existing test infrastructure first.** Before writing new tests,
check the repo for `playwright-tests/`, `cypress/`, `postman/`, `smart-tests/`,
or similar directories. Reuse what's there.

**2. Always use `signadot local proxy` as the browser's target URL**, not the
local service's direct port. The proxy injects the routing key on every request
the browser makes. Navigating to `http://localhost:<service-port>` directly
means the routing key is absent from all requests — dispatched events go to the
baseline cluster services, not the sandboxed ones.

```bash
signadot local proxy --sandbox <name> \
  --map http://<frontend-svc>.<namespace>.svc:<port>@localhost:<proxy-port> &
# then navigate the browser to:
#   http://localhost:<proxy-port>
```

**3. Use a browser tool or script to exercise the UI.** Use whatever is
available in the session — a browser MCP server, a headless browser script
(Playwright, Cypress, Puppeteer, etc.), or an existing test suite in the repo.
The key requirement regardless of tool: the routing key is injected via the
proxy URL — if you navigate directly to the local service port instead, no
routing key is sent.

**4. If a headless browser isn't available** (e.g., download blocked by network
policy), fall back to the app's HTTP API directly with curl via the proxy. This
gives the same signal for most feature validations.

### Proving isolation

Always send one request *with* the routing key and one *without*. The results
must differ — the one without the key must return baseline behavior. If both
return the same result, the routing is not working and the test result is invalid.

To test without the routing key, send a request directly to the cluster service
by its in-cluster DNS name (e.g. `http://frontend.hotrod-istio.svc:8080/path`)
without any baggage header. This requires cluster DNS to be reachable, which
`signadot local connect` provides. Ask the user to run it if not already done:

```
! sudo signadot local connect --cluster <cluster>
```

Once connected, `curl http://<svc>.<namespace>.svc:<port>/path` (no routing key
header) hits the baseline cluster pod directly.

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
| Pull env vars for local service | `eval $(signadot sandbox get-env <name>)` — requires kubeconfig; fallback: `get_workload_object` + `/etc/hosts` |
| Pull config files for local service | `signadot sandbox get-files <name>` |
| Proxy a cluster service to localhost | `signadot local proxy --sandbox <name> --map http://svc:port@localhost:port` |
| Send request with routing key (curl) | `curl -H "baggage: sd-routing-key=<key>" http://localhost:<port>/path` |
| Send request with routing key (grpc) | `grpcurl -H "baggage: sd-routing-key=<key>" -plaintext localhost:<port> Svc/Method` |
| Test browser UI with routing key | Use proxy URL (`localhost:<proxy-port>`), not direct service port |
| Background a service safely | `setsid /tmp/start.sh >> /tmp/svc.log 2>&1 &` (plain `&` can SIGHUP) |
| Tear down a sandbox | `signadot sandbox delete <sandbox-name>` |
| Disconnect | `! signadot local disconnect` (**user runs**) |
