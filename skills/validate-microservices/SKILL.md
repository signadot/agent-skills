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

## What Signadot exposes as signal

| Signal | Where it comes from | Useful for |
|---|---|---|
| Cluster DNS/IP resolvable from your laptop | `signadot local connect` | Reaching cluster services by their in-cluster name from a local process or curl |
| Your modified service's stdout/stderr streaming live to your terminal | Local sandbox (service runs on your laptop, traffic routed in) | Watching a request land in your code, seeing panics/logs immediately, attaching a debugger |
| Cluster service endpoints mapped to `localhost:<port>` | `signadot local proxy --map http://svc:port@localhost:port` | Hitting an in-cluster service with curl without changing client code |
| Readiness, forks, and routing state of an in-cluster fork | `signadot sandbox get <name>` | Knowing whether your sandbox is actually up and routing before you test |
| Preview endpoints that deterministically hit your fork | `signadot sandbox get <name>` (endpoints block) | Driving your forked service with curl from anywhere, no routing header needed |
| Routing-key isolation (header → fork, no header → baseline) | Any sandbox | Proving the change is scoped to your sandbox and not affecting shared traffic |

If none of these answers the question you have, then reach for `kubectl` or an
image build. Otherwise prefer these — they're faster and higher-signal.

## How to get each signal

### Cluster reachability (`signadot local connect`)

Establishes a VPN-like tunnel so cluster DNS resolves locally and `signadot
local proxy` / local sandboxes can route traffic. Without this, none of the
local workflows below can reach cluster services.

**You cannot run this yourself** — it modifies the local network stack and
requires sudo. Ask:

> Please run this command in your terminal (it needs sudo):
> `! signadot local connect --cluster <cluster-name>`

If the cluster name isn't known, `signadot cluster list` will show the
registered clusters. Wait for the user to confirm the tunnel is up before
using any of the signals below — `signadot local status` will also report it.

### Live service logs via a local sandbox

A local sandbox runs your modified service as a regular process on your laptop
(via `signadot local connect` plus a `local` workload entry in the sandbox
spec) while Signadot routes matching cluster traffic to it. The upside: your
service's logs print straight to the terminal as requests arrive, so you can
read them without `kubectl logs`, and you can attach a debugger. Use this
when the question is "is my code actually being hit, and what does it see?".

The sandbox spec is usually committed in the repo — look under `.signadot/` or
for `*.sandbox.yaml`. Apply it the same way as any sandbox
(`signadot sandbox apply -f <file> --set name=<name> --wait`). While the local
process is running, requests that carry the sandbox's routing key land on it;
everything else continues to hit the baseline service in the cluster.

### Direct curl access via local proxy

```bash
signadot local proxy --sandbox <sandbox-name> \
  --map http://<service>:<port>@localhost:<local-port>

curl -s http://localhost:<local-port>/api/endpoint | jq .
```

Use this when the question is "what does this endpoint return right now?". No
need to run the service locally — the proxy just makes the cluster endpoint
reachable.

### Sandbox status and endpoints

```bash
signadot sandbox get <sandbox-name>
```

Returns readiness of each fork plus the preview endpoint URLs. Always read this
before curling — a sandbox that isn't Ready yet will give misleading errors.

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
- **When a test fails, `signadot sandbox get` and the local-sandbox terminal
  output will usually tell you more than `kubectl` will.** Check fork readiness
  (`Status: Ready`) and streamed logs before widening the search to `kubectl`.
- **Update, don't recreate.** Re-run `signadot sandbox apply` with the same
  `--set name=<name>` to update an existing sandbox. Deleting and recreating
  churns the routing key and any tests you've pinned to it.
- **Clean up once the user confirms the change is good:**
  ```bash
  signadot sandbox delete <sandbox-name>
  ```
  Ask the user to run `! signadot local disconnect` if they were the ones who
  connected.

## Quick reference

| Want to… | Command |
|---|---|
| List registered clusters | `signadot cluster list` |
| Make the cluster reachable locally | `! signadot local connect --cluster <cluster>` (**user runs**) |
| Check the tunnel is up | `signadot local status` |
| Expose a cluster service on localhost | `signadot local proxy --sandbox <name> --map http://svc:port@localhost:port` |
| Hit an endpoint | `curl -s http://localhost:<port>/path \| jq .` |
| Create/update a sandbox (local or in-cluster) | `signadot sandbox apply --set name=<n> -f spec.yaml --wait` |
| Check sandbox readiness and endpoints | `signadot sandbox get <name>` |
| Tear down a sandbox | `signadot sandbox delete <name>` |
| Disconnect | `! signadot local disconnect` (**user runs**) |
