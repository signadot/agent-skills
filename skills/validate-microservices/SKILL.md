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
| **Local process receives real cluster traffic** | **Local-mapped sandbox** (service runs on laptop, routing key directs traffic to it) | **Default first choice — validate changes against real deps with no image build** |
| Cluster DNS/IP resolvable from your laptop | `signadot local connect` | Reaching cluster services by their in-cluster name from a local process or curl |
| Your modified service's stdout/stderr streaming live to your terminal | Local sandbox | Watching a request land in your code, seeing panics/logs immediately, attaching a debugger |
| Cluster service endpoints mapped to `localhost:<port>` | `signadot local proxy --map http://svc:port@localhost:port` | Hitting an in-cluster service with curl without changing client code |
| Readiness, forks, and routing state of an in-cluster fork | MCP or `signadot sandbox get <name>` | Knowing whether your sandbox is actually up and routing before you test |
| Preview endpoints that deterministically hit your fork | MCP or `signadot sandbox get <name>` (endpoints block) | Driving your forked service with curl from anywhere, no routing header needed |
| Routing-key isolation (header → fork, no header → baseline) | Any sandbox | Proving the change is scoped to your sandbox and not affecting shared traffic |

Reach for an image build only when the service genuinely can't run on your
laptop. Otherwise the local-mapped sandbox is faster and higher-signal.

## How to get each signal

### Local-mapped sandbox: fastest path to validation

**This is the default approach.** Before building images or provisioning
in-cluster forks, run your modified service locally and map it into the cluster
via a local sandbox. No image builds, live logs, debugger access.

**How it works:**
1. The sandbox spec declares a `local` workload entry pointing at a port on your
   laptop.
2. `signadot local connect` establishes the tunnel so cluster traffic can reach
   your machine.
3. Your service runs as a plain local process (`go run .`, `node server.js`, etc.).
4. Requests carrying the sandbox routing key are routed to your local process;
   everything else hits the baseline in-cluster service.

**Sandbox spec format:**

```yaml
# local-sandbox.yaml
name: my-local-dev
spec:
  cluster: <cluster-name>
  description: "Local dev for my-service"
  local:
  - name: local-my-service
    from:
      kind: Deployment
      namespace: <namespace>
      name: <service-name>
    mappings:
    - port: 8080           # in-cluster port
      toLocal: localhost:3000  # your local port
```

Look for an existing spec under `.signadot/` or `*.sandbox.yaml` first and reuse
it. If none exists, use the MCP sandbox tools (search: "signadot sandbox") to
create one, or write the YAML above.

**Typical workflow:**

```bash
# 1. User connects (needs sudo — ask them to run this)
! sudo signadot local connect --cluster <cluster>

# 2. Apply the sandbox
signadot sandbox apply -f local-sandbox.yaml

# 3. Pull in the environment variables the in-cluster workload uses
eval $(signadot sandbox get-env my-local-dev)

# 4. Pull any config files the workload mounts
signadot sandbox get-files my-local-dev
# Files land under ~/.signadot/sandboxes/<name>/local/files/

# 5. Run your service locally on the mapped port
go run ./cmd/server --port 3000

# 6. Test — route requests via the routing key or preview URL

# 7. Clean up
signadot sandbox delete my-local-dev
! signadot local disconnect
```

`get-env` and `get-files` are easy to miss but important — without them the
local process is missing DB credentials, feature flags, and config that the
in-cluster workload gets automatically.

### Cluster reachability (`signadot local connect`)

Establishes a VPN-like tunnel so cluster DNS resolves locally and `signadot
local proxy` / local sandboxes can route traffic. Without this, none of the
local workflows below can reach cluster services.

**You cannot run this yourself** — it modifies the local network stack and
requires sudo. Ask:

> Please run this command in your terminal (it needs sudo):
> `! sudo signadot local connect --cluster <cluster-name>`

Use MCP (search: "signadot cluster") to resolve the cluster name if unknown.
Wait for the user to confirm the tunnel is up before proceeding —
`signadot local status` will also report it.

### Direct curl access via local proxy

Makes a cluster service reachable on a local port without running anything
locally. Use when the question is "what does this endpoint return right now?"

```bash
signadot local proxy --sandbox <sandbox-name> \
  --map http://<service>.<namespace>.svc:<port>@localhost:<local-port>

curl -s http://localhost:<local-port>/api/endpoint | jq .
```

**Map format:** `<scheme>://<cluster-host>:<port>@<local-host>:<local-port>`
- Left of `@` — URL resolved inside the cluster
- Right of `@` — local bind address
- Schemes: `http` or `grpc` (injects routing key header), `tcp` (raw, no injection)

You can also scope the proxy to a routegroup or bare cluster:

```bash
signadot local proxy --routegroup <name> --map http://svc:port@localhost:port
signadot local proxy --cluster <name>   --map tcp://postgres.db.svc:5432@localhost:5432
```

### Sandbox status and endpoints

Use MCP (search: "signadot sandbox") to get readiness and endpoint URLs without
leaving Claude Code. Fall back to CLI if MCP is unavailable:

```bash
signadot sandbox get <sandbox-name>
```

Always check readiness before curling — a sandbox that isn't Ready yet will give
misleading errors.

### In-cluster sandbox (when a container is required)

Only when the service genuinely can't run on your laptop (hard-to-reproduce
runtime, platform-specific sidecar, etc.) build an image and create an in-cluster
fork:

```bash
signadot sandbox apply --set name=<sandbox-name> -f sandbox.yaml --wait
signadot sandbox get <sandbox-name>
```

If `.signadot/` or a `*.sandbox.yaml` already exists in the repo, reuse it. If
you modify multiple services at once, include them in the same sandbox so they
share the routing key. Update with another `signadot sandbox apply` using the
same name — don't delete and recreate.

## Operational notes

- **Sudo-gated commands must be delegated to the user.** `signadot local
  connect` and `signadot local disconnect` modify the local network stack and
  fall in this bucket. Print the command with a leading `!` and wait.
- **Routing keys isolate your fork from baseline traffic.** Requests carrying
  the sandbox's routing key (usually via a header set by `signadot local
  proxy` or an explicit header) hit your fork; everything else hits baseline.
  Prove this before claiming a test result — otherwise you may be reading
  baseline behavior.
- **A sandbox only needs to contain the services you changed.** Everything else
  is shared from the baseline environment, and that is the point. If you
  changed more than one service, put them in the same sandbox so they share
  one routing key instead of creating a sandbox per service.
- **When a test fails, check sandbox state and streamed logs before `kubectl`.**
  Use MCP or `signadot sandbox get` for fork readiness (`Status: Ready`).
- **Update, don't recreate.** Re-run `signadot sandbox apply` with the same
  `--set name=<name>` to update an existing sandbox. Deleting and recreating
  churns the routing key and any tests you've pinned to it.
- **Clean up once the user confirms the change is good:**
  ```bash
  signadot sandbox delete <sandbox-name>
  ```
  Ask the user to run `! signadot local disconnect` if they were connected.

## Quick reference

| Want to… | How |
|---|---|
| List registered clusters | MCP (search: "signadot cluster") |
| List / inspect sandboxes | MCP (search: "signadot sandbox") |
| Create or update a sandbox | MCP (search: "signadot sandbox") or `signadot sandbox apply -f <spec> --set name=<n> --wait` |
| Resolve workloads and endpoints | MCP (search: "signadot workload endpoint") |
| Manage routegroups | MCP (search: "signadot routegroup") |
| Make the cluster reachable locally | `! sudo signadot local connect --cluster <cluster>` (**user runs**) |
| Check the tunnel is up | `signadot local status` |
| Pull env vars for local service | `eval $(signadot sandbox get-env <name>)` |
| Pull config files for local service | `signadot sandbox get-files <name>` |
| Expose a cluster service on localhost | `signadot local proxy --sandbox <name> --map http://svc:port@localhost:port` |
| Hit an endpoint | `curl -s http://localhost:<port>/path \| jq .` |
| Tear down a sandbox | `signadot sandbox delete <sandbox-name>` |
| Disconnect | `! signadot local disconnect` (**user runs**) |
