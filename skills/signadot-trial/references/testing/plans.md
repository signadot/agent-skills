# Run the suite as a Plan, and catch a regression

`<cluster>` and `<suffix>` as in SKILL.md. Needs isolated-change's `driver-plates<suffix>`; the last step also needs local-development's
`local-route<suffix>`.

## What it shows

- **Problem:** test automation that a person or agent can rerun on demand, against any change, usually means
  maintaining CI glue for every environment.
- **What Signadot does:** a Plan is a reusable, parameterized test run that Signadot executes in the cluster on a
  managed runner. The trial wraps HotROD's Playwright suite in a one-step Plan, tags it, runs it against the isolated-change
  sandbox, then against a sandbox with a deliberate bug, and sees the Plan catch it. A coding agent can author and
  run Plans like this with the `signadot-plan` and `signadot-validate` skills.
- **Why it matters:** the same tagged Plan validates any sandbox, including one running on a developer's computer,
  so regressions are caught before merge.

## Costs

About 4 minutes. No extra memory beyond a short-lived runner pod. Changes two org settings (below).

## Before you start

Plans need two org settings that only an org admin can change, in the dashboard. The message before more scenarios
lists them, and its OK is the yes; if no OK covered them, ask first. Then change them in a browser you drive (signed
in to the trial org), or give the user these steps:

1. **A plan runner on the trial cluster:** https://app.signadot.com → Platform → Managed Runners → click
   `<cluster>` → under Plan Runners, press + once (it saves at once and shows "Provisioning"). Done when the cluster's
   row shows "1/1 runner ready", usually within a minute.
2. **Allow the Playwright image:** on the same page, open Settings → Plan Runner Actions → Configure → under
   `run-container`, expand Allowed images. If `mcr.microsoft.com/playwright:*` is already listed, change nothing;
   otherwise add it and press Apply.

On Linux, if preflight shows `apparmor_userns: restricted` (Ubuntu 23.10 or newer), plan steps fail at start with
"operation not permitted" until the user changes a kernel setting that needs sudo (troubleshooting.md, Testing).
Say so before they choose Plans. Requirements: https://www.signadot.com/docs/reference/plans/cluster-requirements.md.

Record what you changed as `org_setting plan-runner <cluster>` and, only if you added it,
`org_setting allowed-image mcr.microsoft.com/playwright:*` under Resources, so teardown lists them for the user to
revert. Done when a Plan run doesn't fail with "no plan runner group on cluster" or an image-policy error.

## Set up

Plan specs reference an action by its ID, which differs per org. First check the tag: if the trial log already lists
`plan_tag hotrod-e2e<suffix>` (a resumed trial), skip `plan create` and reuse the tagged Plan. Otherwise the tag
should not exist yet; if it does, ask before moving it.

```bash
"$T/bin/sd" plan tag get hotrod-e2e<suffix> -o json    # expect "not found" on a first run
"$T/bin/sd" plan action get run-container -o json | sed -n 's/^  "id": *"\([^"]*\)".*/\1/p' | head -1
"$T/bin/sd" plan create -f "$S/assets/specs/testing/hotrod-e2e-plan.yaml" --set actionID=<action id> -o json
"$T/bin/sd" plan tag apply hotrod-e2e<suffix> --plan <plan id>
```

The plan ID is the first `"id"` in the create output. Record `plan <plan id>` and `plan_tag hotrod-e2e<suffix>` under
Resources.

## Run

Against isolated-change's sandbox:

```bash
"$T/bin/sd" plan run --tag hotrod-e2e<suffix> --param sandbox=driver-plates<suffix> --timeout 10m -o json > "$T/logs/plan-driver.json"
```

Then against a sandbox with a deliberate bug (`route` pointed at a Redis that doesn't exist). This run is meant to
fail, so `plan run` exits non-zero; that's the regression being caught, not a problem with the trial:

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/testing/broken-route.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" plan run --tag hotrod-e2e<suffix> --param sandbox=broken-route<suffix> --timeout 10m -o json > "$T/logs/plan-broken.json"
```

Record `sandbox broken-route<suffix>` under Resources. If local-development ran, also run it against the service on this computer:

```bash
"$T/bin/sd" plan run --tag hotrod-e2e<suffix> --param sandbox=local-route<suffix> --timeout 10m -o json > "$T/logs/plan-local.json"
```

## Prove it

Each run's execution ID is the first `"id"` in its JSON (`sed -n 's/^  "id": *"\([^"]*\)".*/\1/p' <file> | head -1`).
For each one:

```bash
"$T/bin/sd" plan execution get <execution id> | grep '^Phase'
"$T/bin/sd" plan execution get-output <execution id> exit_code     # the test step's exit code
"$T/bin/sd" plan execution logs <execution id> e2e | grep -E 'passed|failed|✘'
```

Done when:
- the run against `driver-plates<suffix>` is `completed` with exit code `0`;
- the run against `broken-route<suffix>` is `failed`, and its log shows the test "check route resolve routes"
  failing: the ride never gets past "Resolving routes". The other test still passes;
- the run against `local-route<suffix>` is `completed` with exit code `0`, and `$T/logs/route-local.log` shows the
  in-cluster test's requests (`Finding route`) reaching the process on this computer.

If a run is `failed` but its exit code is `0`, the tests passed and only uploading the report failed (its error says
"artifact upload failed"); run it again.

Flow for the card: `plan(runner) → frontend → … → route(broken-route<suffix>) ✗` next to `plan(runner) → frontend →
… → driver(driver-plates<suffix>) ✓`.

## Record

```markdown
## Scenario plans
status: passed
seconds: <first run to last proof>
baseline: Plan hotrod-e2e<suffix> passed against driver-plates<suffix> (exit 0)
sandbox: the same Plan failed against broken-route<suffix> (regression caught)[; passed against local-route<suffix>]
hops-baseline: plan(runner) → frontend(baseline) → driver(driver-plates<suffix>) → route(baseline)
hops-sandbox: plan(runner) → frontend(baseline) → driver(baseline) → route(broken-route<suffix>)
proof: one tagged Plan, three sandboxes: passed on the good change, failed on the broken one[, passed on this computer]
commands: sd plan create -f assets/specs/testing/hotrod-e2e-plan.yaml --set actionID=…; sd plan tag apply …; sd plan run --tag … --param sandbox=…
specs: assets/specs/testing/hotrod-e2e-plan.yaml, assets/specs/testing/broken-route.yaml
links: https://www.signadot.com/docs/tutorials/quickstart/plan-based-validation
try: run the tagged plan against any sandbox: sd plan run --tag hotrod-e2e<suffix> --param sandbox=<name>
```

In the report, add a short Jobs-vs-Plans note: Jobs run your own script on your own runner group (good for CI); Plans
are reusable, parameterized runs on a managed runner that people and coding agents can call by tag.

## Try it yourself

- Run the tagged Plan against any sandbox: `<T>/bin/sd plan run --tag hotrod-e2e<suffix> --param sandbox=<name>`.
- Install the agent skills that author and run Plans for your own services:
  `npx skills add signadot/agent-skills --skill signadot-plan` and `--skill signadot-validate`.

## Tear down

```bash
"$T/bin/sd" sandbox delete broken-route<suffix>
"$T/bin/sd" plan tag delete hotrod-e2e<suffix>
```

Don't try `plan delete`: Signadot keeps a plan that has run, as the record of its executions, and refuses to delete it
("cannot delete a plan that has been executed"). With its tag gone, nothing points at it. The recorded `plan <id>`
stays in the trial log for reference.

The two org settings stay; teardown lists them for the user to revert.

## Docs

https://www.signadot.com/docs/tutorials/quickstart/plan-based-validation.md, where a coding agent authors the Plan
with the `signadot-plan` skill. The trial ships a ready-made spec and only looks up the org's action ID.
