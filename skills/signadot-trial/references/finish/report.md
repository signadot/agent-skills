# Trial log and report

The trial log is the run's memory: resume state, the list of everything to tear down, and the data for the report.
Write to it as you go, never only at the end.

## The trial log (`$T/trial-log.md`)

Create it right after the user's OK. Append to it after every step and scenario. Use plain `key: value` lines under
these headings. Never write tokens, passwords, credentials or the contents of a kubeconfig into it.

```markdown
# Signadot trial log

## Run
org: acme-trial
cluster: signadot-trial
suffix:
kube_context: kind-signadot-trial
original_kube_context: docker-desktop
cluster_mode: kind
created_kind_cluster: yes
infra: devmesh
connect_mode: unprivileged
proxy: socks5h://127.0.0.1:60123
isolated: no
cli_path: /Users/me/.signadot-trial/bin/signadot
cli_on_path: no
versions: cli 1.9.1, operator 1.4.0, kind v0.33.0
selection: core, sandbox-database, kafka
started: 2026-11-15T10:02:11Z
finished:

## Steps
preflight · ok · 3s · Docker 8.0 GB, all tools present
cli · ok · 6s · CLI 1.9.1 in ~/.signadot-trial/bin
cluster · ok · 142s · kind cluster up, HotROD ready
account · ok · 95s · org acme-trial created
login · ok · 20s · CLI logged in to acme-trial
operator · ok · 61s · operator 1.4.0, sidecars 4/4
connect · ok · 9s · frontend 200 through the proxy
baseline · ok · 7s · plate T751234C, ETA 12min

## User actions
- Typed the signup password and clicked the verification link

## Fallbacks
- (none)

## Resources
kind_cluster signadot-trial
namespace hotrod
sandbox driver-plates
routegroup hotrod-plates
process 48211 hotrod route (C3)
portforward 48190 redis 6390:6379

## Scenario C1
status: passed
seconds: 48
baseline: plate T751234C
sandbox: plate SD-T751234C
hops-baseline: location(baseline) → driver(baseline) → route(baseline)
hops-sandbox: location(baseline) → driver(driver-plates) → route(baseline)
proof: the driver step was served by sandbox driver-plates only when the routing key was sent
commands: sd sandbox apply -f driver-plates.yaml --set cluster=signadot-trial --set suffix=
specs: assets/specs/core/driver-plates.yaml
screenshot: screens/C1.png
links: https://www.signadot.com/docs/tutorials/quickstart/first-sandbox
try: book a ride with and without the key: scripts/ride.sh --key <key> --proxy <proxy>
```

Rules:

- **Steps:** one line each, `<id> · ok|failed|skipped · <seconds>s · <proving value>`. The step IDs are `preflight`,
  `cli`, `cluster`, `account`, `login`, `operator`, `connect`, `baseline`. On resume, skip every step marked `ok`.
- **Resources:** one line per thing the trial created, `<kind> <name> [namespace or detail]`. Kinds:
  `kind_cluster`, `namespace`, `mesh`, `sandbox`, `routegroup`, `plugin`, `runnergroup`, `plan_tag`, `process`,
  `portforward`, `org_setting`. Teardown reads this list; anything missing from it is left behind.
- **Scenarios:** IDs are `C1`, `C2`, `C3`, then each variation's file name (`sandbox-database`, `kafka`, `temporal`,
  `rabbitmq`, `redis-streams`, `jobs`, `plans`). `status` is `passed`, `failed` or `skipped`.
- **Hops** are the flow diagram's data. For a request: `service(served-by)` joined by ` → `, where `served-by` is
  `baseline`, a sandbox name, or `local` for a process on this computer. `scripts/ride.sh` prints a ready-made
  `hops:` line. HotROD records location, driver and route; add `frontend(<served-by>)` in front yourself when a
  scenario proves which frontend served the page (C2). For messages: `producer → <topic or queue> → consumer(handled)`, e.g.
  `frontend → kafka:dispatch → driver(baseline: T7…) · driver(driver-plates: SD-T7…)`.

## The report

1. `mkdir -p $T/report/screens` and copy `assets/report-template.html` to `$T/report/index.html`.
2. Replace each `FILL:<name>` comment with real content in the shape its example shows:
   - **title:** e.g. "Signadot trial: 3 of 3 scenarios proven in 14 minutes".
   - **summary:** pills with counts (passed, failed, not run), then org, cluster, infrastructure, date and total
     minutes.
   - **cards:** copy the `CARD` block once per scenario that ran, in run order. Fill the problem, what Signadot did,
     one flow row for the baseline and one for the sandbox (from the scenario's hops), both results, the proof, the
     screenshot if there is one, why it matters, the docs link and the commands. Then copy the `NOT-RUN` block once
     per menu item the user didn't pick.
   - **timeline:** the `## Steps` table, what the user did, and any fallbacks.
   - **running:** everything in `## Resources` that still exists, the preview URL, and the connection. Say that
     nothing expires on its own.
   - **next steps:** `signadot-validate` for their own services; the Signadot MCP server command for the CLI that
     was actually used (`$T/bin/sd mcp` when the trial isolated its config or the CLI isn't on the user's PATH,
     otherwise `signadot mcp`) and which org it talks to; variations they didn't try.
   - **teardown:** what teardown will remove, and the manual steps (from `references/finish/teardown.md`).
   - **run details:** the `## Run` facts, except secrets.
3. Escape `<`, `>` and `&` in anything copied from command output.
4. Delete the `CARD` and `NOT-RUN` template blocks once you've copied them. Every `FILL:` comment should be gone.
5. Open it with `open $T/report/index.html` (macOS) or `xdg-open` (Linux), or give the user the path.

## Screenshots

Take them only if you can drive a browser that can send the routing-key header, or for preview URLs, which need no
header. Save them as `$T/report/screens/<scenario id>.png` and link them relatively (`screens/C1.png`). Without a
browser, leave out the `<figure>`: the flow diagram and the proof carry the card.

Good screenshots: C1 the ride notifications with the `SD-` plate; C2 the preview URL with the highlighted plate;
C3 the ride with an ETA in seconds.
