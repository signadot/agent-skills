# The trial log

`$T/trial-log.md` is the run's memory: resume state, the list of everything teardown removes, and the data for the
reports. Create it right after the user's OK and append to it after every step and scenario, never only at the end.
Use plain `key: value` lines under these headings. Never write tokens, passwords, credentials or the contents of a
kubeconfig into it.

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
baseline_url: https://frontend--hotrod-baseline.preview.signadot.com
trial_dir: /Users/me/project/.signadot-trial
cli_path: /Users/me/project/.signadot-trial/bin/signadot
cli_on_path: no
versions: cli 1.9.1, operator 1.4.0, kind v0.33.0
selection: isolated-change, multi-service-preview, local-development, sandbox-database, kafka
started: 2026-11-15T10:02:11Z
finished:

## Steps
preflight · ok · 3s · Docker 8.0 GB, all tools present
cli · ok · 6s · CLI 1.9.1 in the trial folder
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
sandbox fast-route
sandbox driver-plates
sandbox frontend-highlight
routegroup hotrod-plates
routegroup hotrod-baseline
process 48211 hotrod route (local-development)
portforward 48190 redis 16379:6379

## Scenario isolated-change
status: passed
seconds: 48
baseline: ETA 23m14s
sandbox: ETA 1s
hops-baseline: location(baseline) → driver(baseline) → route(baseline)
hops-sandbox: location(baseline) → driver(baseline) → route(fast-route)
routing-key: 7g2k9xq4m1ab
proof: the route step was served by sandbox fast-route only when the routing key was sent
commands: sd sandbox apply -f fast-route.yaml --set cluster=signadot-trial --set suffix=
specs: assets/specs/core/fast-route.yaml
screenshot: screens/isolated-change.png
links: https://www.signadot.com/docs/tutorials/quickstart/first-sandbox
link-baseline: https://frontend--hotrod-baseline.preview.signadot.com
link-sandbox: https://frontend--fast-route.preview.signadot.com
try: open the baseline and sandbox links and compare the ETAs
```

## Rules

- **Steps:** one line each, `<id> · ok|failed|skipped · <seconds>s · <proving value>`. The step IDs are `preflight`,
  `cli`, `cluster`, `account`, `login`, `operator`, `connect`, `baseline`. On resume, skip every step marked `ok`.
- **Resources:** one line per thing the trial created, `<kind> <name> [namespace or detail]`. Kinds:
  `kind_cluster`, `namespace`, `mesh`, `sandbox`, `routegroup`, `plugin`, `runnergroup`, `plan`,
  `plan_tag`, `process`, `portforward`, `org_setting`. Teardown reads this list; anything missing from it is left
  behind.
- **Scenarios:** IDs are file names: `isolated-change`, `multi-service-preview`, `local-development`, then each
  add-on's (`istio`, `istio-ambient`, `linkerd`, `sandbox-database`, `kafka`, `temporal`, `rabbitmq`,
  `redis-streams`, `jobs`, `plans`). `status` is `passed`, `failed` or `skipped`.
- **Hops** say which version served each service, for the page's diagram. For a request: `service(served-by)`
  joined by ` → `, where `served-by` is `baseline`, a sandbox name, or `local` for a process on this computer.
  `scripts/ride.sh` prints a ready-made `hops:` line, in the order the notifications arrived, which is not the call
  order: draw HotROD's real path (frontend calls location, then publishes to Kafka; driver consumes it and calls
  route). Add `frontend(<served-by>)` yourself when a scenario proves which frontend served the page
  (multi-service-preview). For messages:
  `producer → <topic or queue> → consumer(handled)`,
  e.g. `frontend → kafka:dispatch → driver(baseline: T7…) · driver(driver-plates: SD-T7…)`.

## Resume and retire

- **Resume:** when preflight shows `trial_log: present`, read the log, tell the user what's done, and continue from
  the first step that isn't `ok`, then the chosen scenarios that haven't run (not `passed`, `failed` or `skipped`),
  pausing after each as usual. The user may also say "continue the trial" after stopping early. Keep the recorded
  suffix, cluster and infra choices.
- **Retire:** at the end of teardown, rename the log to `trial-log.torn-down-<date>.md`
  (`references/finish/teardown.md`). Preflight then shows `trial_log: absent`, so a later trial starts fresh instead
  of resuming one whose cluster is gone. The old log stays in `$T` for reference.
