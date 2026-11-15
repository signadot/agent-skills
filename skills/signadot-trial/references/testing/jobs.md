# Run a Playwright suite as a Job

`<cluster>` and `<suffix>` as in C1. Needs C1's `driver-plates<suffix>`.

## What it shows

- **Problem:** end-to-end suites usually run against a shared staging environment after merge, so a broken change
  is found late and blocks everyone.
- **What Signadot does:** a job runner group keeps a pool of test pods in the cluster; a Job runs HotROD's existing
  Playwright suite in one of them, against a sandbox. Signadot adds the sandbox's routing key to the test traffic, so
  the unchanged tests exercise the sandboxed service. Nothing in the tests changes.
- **Why it matters:** every pull request can run the team's existing end-to-end suite against its own sandbox
  before merge, in the cluster, with the results and artifacts kept in Signadot.

## Costs

About 3 minutes: the runner's image is about 2 GB to pull, then the suite takes about a minute. About 1 GB of
memory. Namespace `signadot-tests`.

## Before you start

- C1's sandbox must exist.
- No org settings are needed for Jobs.

## Set up

Start this early (right after the operator is installed), so the image pulls while you do the core tutorial:

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

Flow for the card: without key `playwright(runner) → frontend → driver(baseline)` (what a plain staging run tests);
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

- Run the same job against another sandbox: `--set sandbox=frontend-highlight<suffix>` or `local-route<suffix>`
  (the suite then exercises the route service on this computer).
- Open the HTML report: `<T>/artifacts/job/playwright-report/index.html`.
- See the job and its artifacts in the dashboard: https://app.signadot.com/testing/jobs.

## Tear down

```bash
"$T/bin/sd" jobrunnergroup delete hotrod-playwright<suffix>
"$T/bin/sd" jobrunnergroup list     # repeat until hotrod-playwright<suffix> is gone; it drains first
"$T/bin/kc" delete namespace signadot-tests
```

Wait for the runner group to finish draining before deleting the namespace or the cluster; otherwise it stays
listed as `draining`.

## Docs

https://www.signadot.com/docs/tutorials/quickstart/jobs.md. The trial's job clones HotROD's `main` branch for the
tests and checks the traces, since the suite's assertions pass on the baseline too.
