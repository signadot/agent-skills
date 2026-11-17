# Run a Playwright suite as a Job

`<cluster>` and `<suffix>` as in SKILL.md. Uses the driver sandbox `driver-plates<suffix>` from the two-service
scenario.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD; driver is the changed service (the sandbox under test).
- **The change:** none of its own: the Job tests the driver change from the two-service scenario (`SD-` plates)
  with HotROD's existing Playwright suite, unchanged.
- **The sandbox:** `driver-plates<suffix>` (created here if it's missing). Also created: a job runner group,
  `hotrod-playwright<suffix>`, a pool of test pods in the cluster; and the Job, whose report Signadot keeps as an
  artifact.
- **Routing:** the Job's routing context sets the sandbox's key on all of the suite's traffic; from there it routes
  as in the two-service scenario. Nothing in the tests changes.

## Costs

About 4 minutes: the runner's image is about 2 GB to pull, then the suite takes about a minute. About 1 GB of
memory. Namespace `signadot-tests`.

## Before you start

- The sandbox `driver-plates<suffix>` must exist. If the two-service scenario was skipped, create it (safe to run
  again; record it under Resources if it's new):
  `"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/driver-plates.yaml" --set cluster=<cluster> --set suffix=<suffix>`
- No org settings are needed for Jobs.

## Set up

SKILL.md's flow starts this right after the operator is installed, so the image pulls during the basics:

```bash
"$T/bin/kc" create namespace signadot-tests --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/sd" jobrunnergroup apply -f "$S/assets/specs/testing/playwright-runner.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/kc" -n signadot-tests wait --for=condition=ready pod --all --timeout=600s
```

Done when the runner pod (`hotrod-playwright<suffix>-0`) is ready. Record `namespace signadot-tests` and
`runnergroup hotrod-playwright<suffix>` under Resources.

## Run

```bash
"$T/bin/sd" job submit -f "$S/assets/specs/testing/playwright-job.yaml" --set suffix=<suffix> \
  --set sandbox=driver-plates<suffix> --attach --timeout 15m > "$T/logs/job.log" 2>&1
grep -E 'queued|passed|failed' "$T/logs/job.log"
```

The first line of the log names the job (`hotrod-playwright-e2e-…`). `--attach` streams the run; if the log shows
"The execution has been restarted", the stream reconnected and replayed the output, which is harmless.

## Prove it

A green run alone doesn't prove the sandbox was tested, because the suite's assertions pass on the baseline too. The
proof is in the recorded traces: the plates the browser saw.

```bash
"$T/bin/sd" job get <job name>          # Status: Succeeded; the artifacts list can take a few seconds to fill in
mkdir -p "$T/artifacts/job" && cd "$T/artifacts/job"
"$T/bin/sd" artifact download --job <job name> hotrod/playwright-report.tar.gz -o report.tar.gz
tar -xzf report.tar.gz
for z in playwright-report/data/*.zip; do unzip -p "$z"; done | grep -aoE '(SD-)?T7[0-9]{5}C' | sort -u
```

Done when the job is `Succeeded` and the plates in the traces all start with `SD-`: the tests ran through
`driver-plates<suffix>`. The job's dashboard page is `https://app.signadot.com/testing/jobs/<job name>`.

For the page's diagram: without key `playwright(runner) → frontend → driver(baseline)` (what a plain staging run tests);
with the job's routing context `playwright(runner) → frontend → driver(driver-plates<suffix>)`.

## Record

```markdown
## Scenario jobs
status: passed
seconds: <submit to proof>
baseline: a plain run would test the baseline driver (T7… plates)
sandbox: Job <job name> Succeeded (2 tests); traces show only SD- plates
hops-baseline: playwright(runner) → frontend(baseline) → driver(baseline)
hops-sandbox: playwright(runner) → frontend(baseline) → driver(driver-plates<suffix>)
proof: the unchanged Playwright suite ran in the cluster against the sandbox; every plate in the traces starts with SD-
commands: sd jobrunnergroup apply -f assets/specs/testing/playwright-runner.yaml …; sd job submit -f assets/specs/testing/playwright-job.yaml …
specs: assets/specs/testing/playwright-runner.yaml, assets/specs/testing/playwright-job.yaml
links: https://www.signadot.com/docs/tutorials/quickstart/jobs, https://app.signadot.com/testing/jobs/<job name>
try: run the same job against another sandbox, e.g. --set sandbox=frontend-highlight<suffix>
```

## Try it yourself

Jobs and Plans test with runs, not links: the steps are runs against different sandboxes.

- **Sandbox:** run the Job against the driver sandbox (the command under Run): it passes, and the plates in its
  traces all start with `SD-`.
- **Another sandbox:** run it again with `--set sandbox=frontend-highlight<suffix>` or `local-route<suffix>` (the
  suite then exercises the route service on this computer).
- **Check:** open the HTML report, `<T>/artifacts/job/playwright-report/index.html`, and the job in the dashboard,
  https://app.signadot.com/testing/jobs.

## Tear down

```bash
"$T/bin/sd" jobrunnergroup delete hotrod-playwright<suffix>
"$T/bin/sd" jobrunnergroup list     # repeat until hotrod-playwright<suffix> is gone; it drains first
"$T/bin/kc" delete namespace signadot-tests
```

Wait for the runner group to finish draining before deleting the namespace or the cluster; otherwise it stays
listed as `draining`.

## Docs

https://www.signadot.com/docs/tutorials/quickstart/jobs.md. The trial's job fetches HotROD's tests at the same commit as
the cluster, and checks the traces, since the suite's assertions pass on the baseline too.
