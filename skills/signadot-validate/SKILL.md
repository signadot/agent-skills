---
name: signadot-validate
description: >
  Use this skill to validate code changes against real Kubernetes microservice
  dependencies with Signadot signals such as local sandboxes, cluster
  reachability, logs, endpoints, and routing-key isolation.
---

# Signadot: Validate Microservice Changes

Use Signadot to validate code changes against real cluster dependencies without
building an image unless the service cannot run locally. Prefer a local-mapped
sandbox: run the changed service locally, route cluster traffic to it with a
routing key, and iterate until the full validation path passes.

## Reference Map

Load these one-hop references only when the workflow reaches that topic:

- [references/sandbox-setup.md](references/sandbox-setup.md): cluster and
  workload resolution, sandbox reuse/create/update, devbox detection, env var
  reconstruction, process startup, and port rules.
- [references/validation-types.md](references/validation-types.md): how to run
  integration tests, existing e2e suites, ad-hoc browser automation, and
  existing tagged Signadot plans with routing-key injection.
- [references/troubleshooting.md](references/troubleshooting.md): fast
  diagnostics for 503s, baseline-looking responses, browser blanks, propagation
  failures, async hops, process exits, and gRPC DNS delays.
- [references/worked-example.md](references/worked-example.md): an end-to-end
  example of validating a UI change through a local sandbox.

## Core Workflow

The workflow has four phases: **A** (before coding), **B** (set up the
sandbox), **C** (run validation), **D** (iterate). Steps are numbered for
sequence; each links to the reference that owns its detail.

1. **Define what "validated" means before coding** (*Phase A*). If the user
   did not specify the validation type, ask one question and offer these
   choices: integration tests, existing e2e suite, ad-hoc browser
   automation, or existing tagged Signadot plan. The validation type affects
   implementation shape, sandbox ports, and routing-key plumbing. If they name
   another tool, such as Locust, Postman, or a custom Cypress script, use the
   same principle: find where its HTTP/gRPC client lives and how it will send
   the routing key.
   See [references/validation-types.md](references/validation-types.md).
2. **Resolve cluster and workload** (*Phase B*). Use the Signadot MCP server
   when available; otherwise use the CLI. Resolve names through tools or
   repo-owned Signadot specs, not guesses. If a tool response asks for
   confirmation because there are multiple clusters, workloads, or devboxes,
   ask the user to choose.
   See [references/sandbox-setup.md](references/sandbox-setup.md#discovery-and-confirmation).
3. **Reuse before creating** (*Phase B*). Look for a live sandbox for the same
   user and workload before making a new one. Reuse keeps the routing key
   stable across local test env vars, curls, and browser automation.
   See [references/sandbox-setup.md](references/sandbox-setup.md#reuse-before-create).
4. **Create or update the sandbox** (*Phase B*). Use the existing repo spec
   under `.signadot/` when one matches. Otherwise create the smallest
   local-mapped sandbox that contains only the service(s) changed or needed to
   follow the changed user-visible path.
   See [references/sandbox-setup.md](references/sandbox-setup.md#creating-or-updating-a-sandbox)
   for required fields, port rules, and the preview-endpoints policy.
5. **Pull env and start the service** (*Phase B*). Read the repo's normal run
   commands first. Export every required env var, especially service-to-service
   addresses, secrets, and feature flags. Build before backgrounding, then
   verify the process is alive and its port is listening.
   See [references/sandbox-setup.md](references/sandbox-setup.md#env-and-config-reconstruction)
   and the "Starting The Service" section.
6. **Validate through the cluster URL** (*Phase C*). Send traffic to
   `http://<svc>.<namespace>.svc:<service-port>/...` with routing-key headers.
   Do not validate by calling `localhost:<port>` directly.
   See [references/validation-types.md](references/validation-types.md) for
   the subsection matching the type chosen in Phase A.
7. **Iterate on failures** (*Phase D*). Read the exact failure, fix the
   smallest cause, restart affected services, and re-run the same validation
   against the same sandbox. Do not report success until the agreed validation
   path passes.
   See [references/troubleshooting.md](references/troubleshooting.md).
8. **Close out cleanly.** Report the sandbox name, cluster, routing key,
   target URL, validation command or browser path, and local processes
   stopped. Leave the sandbox up by default; surface the delete command as an
   option only.

## MCP And CLI Use

If a Signadot MCP server is available, use it for control-plane work: list and
inspect clusters, sandboxes, routegroups, workloads, endpoints, and devboxes;
create or update sandboxes when the side-effect policy below permits it. Search
by intent, load tool schemas before calling tools, and prefer tool output over
memory.

If MCP is unavailable, use CLI fallbacks:

```bash
signadot cluster list -o json
signadot sandbox list -o json
signadot sandbox get <name> -o json
signadot sandbox apply -f <spec.yaml>
signadot sandbox get-env <name>
signadot sandbox get-files <name>
```

Use `kubectl get <kind> <name> -n <ns> -o yaml` only when MCP cannot fetch the
same workload, ConfigMap, Secret, or Service data and the local environment has
cluster access.

## Signal Inventory

| Signal | Use |
|---|---|
| Local process receives real cluster traffic | Default first choice for validating changed services without an image build |
| Cluster DNS/IP is resolvable locally | `signadot local connect` or a devbox makes `.svc` names reachable |
| Local stdout/stderr streams during routed requests | Watch requests land in changed code, see panics, attach a debugger |
| Sandbox readiness, forks, routing state, and tunnel connection | Confirm the sandbox can route before testing code |
| Preview endpoints, when explicitly requested | Deterministically hit a fork without manual routing headers, but may expose a public `*.preview.signadot.com` URL |
| Routing-key isolation | Prove keyed traffic hits the sandbox while unkeyed traffic stays on baseline |
| `signadot local proxy` | Diagnose dependency reachability; not a validation result |

## Side-Effect Policy

| Action | Default behavior |
|---|---|
| Read clusters, workloads, endpoints, sandboxes, routegroups | Do autonomously |
| Create an isolated sandbox for this task | Do autonomously when cluster/workload are unambiguous |
| Update a sandbox clearly owned by this task | Do autonomously |
| Update a shared sandbox or routegroup | Ask first |
| Add public preview endpoints such as `defaultRouteGroup.endpoints` | Ask first |
| Delete a sandbox | Ask first; default is leave it up |
| Run `sudo signadot local connect --cluster <cluster>` or `signadot local disconnect` | Ask the user to run it; it modifies the local network stack and may require sudo |
| Run `signadot local status` or `signadot local proxy` | Do autonomously when useful; proxy is diagnostic, not proof of validation |

## Routing Rules

### Two Ports Matter

Keep the two port concepts separate:

| Context | Port to use | How to resolve |
|---|---|---|
| Sandbox local mapping | Workload/container port | MCP workload-port resolver such as `resolve_workload_port`, or workload spec |
| Validation traffic to `.svc` URL | Kubernetes Service port | Endpoint resolver such as `resolve_endpoints`, Service object, or repo Signadot spec |

The sandbox can be `ready: true` with a connected tunnel even when its mapping
uses the wrong container port; requests then fall through to baseline. If routing
looks broken, check for a virtual host entry such as
`<sandbox>-<mapping>-*.<namespace>.svc` in `/etc/hosts`.

### Always Hit The Cluster URL

Validation traffic must target the cluster service URL, not the local process:

```bash
curl -sS "http://<svc>.<namespace>.svc:<service-port>/<path>" \
  -H "baggage: sd-routing-key=<routing-key>" \
  -H "tracestate: sd-routing-key=<routing-key>"
```

For gRPC:

```bash
grpcurl -plaintext \
  -H "baggage: sd-routing-key=<routing-key>" \
  -H "tracestate: sd-routing-key=<routing-key>" \
  -d '{"field":"value"}' \
  <svc>.<namespace>.svc:<service-port> package.Service/Method
```

`baggage` and `tracestate` with key name `sd-routing-key` are always accepted.
If `clusterConfig.routing.customHeaders` lists additional headers, inject every
listed header with the routing key as the value. Use query-param routing only
when the surface cannot set headers.

`signadot local proxy` can help debug whether a cluster dependency is reachable
from the machine, but a localhost proxy URL bypasses the same end-to-end routing
path and is not a validation result.

### Forward The Key Across Hops

The routing key reaches a sandboxed downstream service only if every hop
propagates it. Raw HTTP/gRPC clients, custom proxy handlers, and async producers
often drop the key unless the code explicitly copies it. When adding a new
forwarder, copy the incoming `baggage` header onto outbound requests or use the
service's existing instrumented client.

## Secrets And Env Vars

When reconstructing env vars from workload specs, ConfigMaps, or Secrets:

- Resolve every required value before blaming the code. Missing DB addresses,
  credentials, and feature flags often appear as first-request 500s.
- Do not print secret values in chat, logs, or summaries. Redact them as
  `<redacted>` and avoid pasting decoded Secret contents.
- Prefer exporting secrets directly into the process environment. If an env file
  is necessary, write it with restrictive permissions and remove it during
  cleanup.
- For service addresses, grep the code for config lookups such as `*_ADDR`,
  `*_HOST`, `*_URL`, and language-specific helpers. Defaults that work inside a
  pod may not work from a local process.

## Validation Type Picker

- **Integration tests**: run the language-native test command against the
  cluster `.svc` URL, injecting routing headers in the test client or a shared
  transport.
- **Existing e2e suite**: use the repo's existing command and config. Point its
  base URL at the `.svc` URL and attach routing headers at the framework HTTP
  layer.
- **Ad-hoc browser automation**: drive the UI from a browser to exercise the
  change end-to-end. Use whatever browser-automation tooling is available
  (Playwright is the common one); inject routing headers on every request,
  clear previous routes first when browser state persists, and drive the full
  UI path.
- **Existing tagged Signadot plan**: pick a tag by `selectionHint` and run it
  against the sandbox. For everything else about plans — params, secrets,
  logs/outputs, authoring, tagging — defer to the `signadot-plan` skill.

Read [references/validation-types.md](references/validation-types.md) before
running the chosen type.

## Failure Loop

When validation fails, do not stop at "validation failed." Continue the loop:

1. Quote the exact failure: status code, error message, stack trace, missing UI
   element, bad field, or empty browser state.
2. Identify whether the likely cause is app code, sandbox shape, missing env,
   stale process, wrong port, routing-key propagation, or a changed downstream
   consumer that must also run locally.
3. Apply the smallest fix, rebuild and restart affected processes, and re-run
   the same validation with the same routing key and target URL.
4. Stop to ask only when the fix requires a judgment call that cannot be made
   without the user — for example, choosing between fixing forward, making a
   change backward-compatible, or accepting an intentional break. Do not ask
   permission for mechanical fixes such as typos, missing env vars, or
   restarting a stopped process; just apply them and continue the loop.

Before declaring done, consider whether the verified behavior should be codified
as a Signadot plan. Do this when the bug is deterministic, important, and not
covered elsewhere. Skip it for typos, infra flakes, exploratory checks, and
non-deterministic failure modes. The sandbox is still up — running the new
plan against it once confirms it catches the bug (or passes for the fixed
code) before tagging.

## Quick Diagnostics

| Symptom | Likely cause | First check |
|---|---|---|
| Envoy 503 from devbox but pod is healthy | Hit container port instead of Service port | Service object / endpoint resolver |
| Response looks like old baseline behavior | Routing key dropped or localhost target used | Target URL and all routing headers |
| Sandbox ready and tunnel connected but local process gets no traffic | Wrong sandbox mapping port | `/etc/hosts` virtual sandbox entry |
| Local process starts, then first real request returns 500 | Missing env var or unresolved dependency address | Config lookups and exported env |
| Browser body or accessibility tree empties after interaction | SPA runtime error | Browser console errors and `page.content().length` |
| Background process exits soon after start | Shell job received SIGHUP or port conflict | Process status, listener, log file |
| gRPC dial stalls around DNS timeout | Go gRPC SRV lookup delay | `passthrough:///` target and connection reuse |

Read [references/troubleshooting.md](references/troubleshooting.md) for detailed
signals and fixes.

## Final Report

Include:

- Validation type and command/tool path used
- Cluster, sandbox name, routing key, and service URL
- What passed, including browser/user path when relevant
- Any local process PIDs or ports stopped
- Sandbox teardown command as an option, not an action:

```bash
signadot sandbox delete <sandbox-name>
```

If the user ran local network connect, remind them that they can later run:

```bash
signadot local disconnect
```
