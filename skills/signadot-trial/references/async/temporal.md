# Temporal

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app** (not HotROD; the user has only seen HotROD): a small money-transfer app built on Temporal. Steps
  for the diagram: (1) the transfer app's page starts a transfer as a Temporal workflow; (2) the Temporal server
  puts its steps (withdraw, then deposit) on one task queue, `money-transfer`; (3) a worker takes each step and runs
  it; (4) the Temporal UI shows every transfer and, for each step, which worker ran it.
- **The change:** the sandbox's worker is a new version of the worker. In the trial it runs the same code, so what
  the page shows is which worker runs which transfer; with your own services it would run the worker image built
  from the pull request.
- **The sandbox:** a copy of `temporal-worker` on the same server and task queue. Also created: nothing else; no
  second Temporal server or task queue.
- **Routing:** the sandbox's preview link adds its key to the transfer app's requests; OpenTelemetry carries it
  into the workflow's headers. No sidecar routes tasks: each worker reads the key on every task, runs its own and
  hands the others back.

## Costs

About 6 minutes, including two local image builds (about 1 minute) and the Temporal server's start. About 1 GB of
memory: the Temporal server with Postgres and Elasticsearch is the heaviest add-on. Namespace `temporal`.

## Before you start

- The demo comes from `signadot/examples` in `$T/examples` (`references/setup/cluster.md` §2).
- The demo has workers in Python, TypeScript, Go and Java. The trial uses the Python worker (the default); for
  another language, follow the docs page with `k8s/<language>-worker-deployment.yaml`.
- Its images aren't published: you build them locally and load them into the kind node; no registry is needed. On
  an existing (non-kind) cluster, use that cluster's way of loading local images instead.

## Set up

```bash
cd "$T/examples/temporal-tutorial"
docker build -q -t temporal-py-client-ui:v1.0 py_client > "$T/logs/temporal-build.log" 2>&1
docker build -q -t temporal-money-transfer:v1.0 temporal_worker >> "$T/logs/temporal-build.log" 2>&1
kind load docker-image temporal-py-client-ui:v1.0 temporal-money-transfer:v1.0 --name signadot-trial
"$T/bin/kc" create namespace temporal --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/kc" apply -n temporal -f k8s/temporal/
"$T/bin/kc" apply -n temporal -f k8s/worker-deployment.yaml -f k8s/temporal-py-client-ui-deployment.yaml
"$T/bin/kc" -n temporal set env deploy/temporal-worker ROUTES_API_REFRESH_INTERVAL_SECONDS=10
"$T/bin/kc" -n temporal wait --for=condition=available deploy --all --timeout=600s
```

The worker restarts a few times until the Temporal server is up; that's expected. Done when every deployment in
`temporal` is available. If you deployed it before the operator, restart it as
`references/setup/cluster.md` §3 says, or the worker sandbox stays Not Ready. Record `namespace temporal` under Resources.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/async/temporal-worker.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get temporal-worker<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

Record `sandbox temporal-worker<suffix>` under Resources. Wait about 15 seconds for both workers to refresh their
routing rules, then start one transfer without the key and one with it:

```bash
curl -s --proxy <proxy> -X POST http://temporal-py-client-ui.temporal.svc:8080/api/start-workflow \
  -d "from_account=acc_001" -d "to_account=acc_002" -d "amount=100.00"
curl -s --proxy <proxy> -X POST http://temporal-py-client-ui.temporal.svc:8080/api/start-workflow \
  -H "baggage: sd-routing-key=<key>" -d "from_account=acc_001" -d "to_account=acc_002" -d "amount=200.00"
```

Each call prints the workflow ID and the routing key it carried.

## Prove it

```bash
"$T/bin/kc" -n temporal logs deploy/temporal-worker -c temporal-worker --since=5m | grep 'Processing task with routing key'
"$T/bin/kc" -n temporal get deploy -o name | grep "temporal-worker<suffix>-dep-temporal-worker-"
"$T/bin/kc" -n temporal logs <sandbox worker deployment> -c temporal-worker --since=5m | grep 'Processing task with routing key'
```

Done when the baseline worker logged tasks only with routing key `''` and the sandbox worker only with `<key>`.
Both workflows ran on the same server and task queue.

Then read, for each workflow ID the start calls printed, which worker completed its steps, as the Temporal UI
shows it:

```bash
curl -s --proxy <proxy> http://temporal-ui-service.temporal.svc/api/v1/namespaces/default/workflows/<workflow id>/history \
  | tr -d '\n ' | grep -oE '"workflowTaskCompletedEventAttributes":\{[^{}]*"identity":"[^"]*"' | grep -oE '"identity":"[^"]*"' | sort -u
```

The transfer without the key prints only the normal worker (`1@temporal-worker-<hash>`); the one with the key only
the sandbox's (`1@temporal-worker<suffix>-dep-temporal-worker-…`). Put both on the page: they're what the user will
see in the Temporal UI.

Explain the hand-back on the page too, because the user will see it: either worker may pick up a step first. A
worker that picks up a step that isn't its own hands it back, which the Temporal UI shows as a **Workflow Task
Failed** event with "Workflow/Worker cannot handle routing key", and the right worker then runs the step. So the
sandbox's worker can appear once in a transfer without the key (as that failed task), and the normal worker in one
with the key. The steps that completed show who really ran it.

For the page's diagram: `client → temporal:money-transfer → worker(baseline: no key) ·
worker(temporal-worker<suffix>: <key>)`.

## Record

```markdown
## Scenario temporal
status: passed
seconds: <sandbox apply to proof>
baseline: the baseline worker ran only the workflow without a key
sandbox: the sandbox worker ran only the workflow with its key
hops-baseline: client → temporal:money-transfer → worker(baseline)
hops-sandbox: client → temporal:money-transfer → worker(temporal-worker<suffix>)
proof: one Temporal server and task queue; each worker ran only the tasks carrying its routing key
commands: docker build + kind load; kubectl apply -n temporal …; sd sandbox apply -f assets/specs/async/temporal-worker.yaml …; curl …/api/start-workflow
specs: assets/specs/async/temporal-worker.yaml
identity-baseline: <the normal worker's identity>
identity-sandbox: <the sandbox worker's identity>
links: https://www.signadot.com/docs/tutorials/testing-temporal-workers
link-baseline: http://temporal-py-client-ui.temporal.svc:8080 (no routing key; needs the laptop's connection)
link-sandbox: <the sandbox's preview link>
link-temporal-ui: http://temporal-ui-service.temporal.svc (needs the laptop's connection)
try: start a transfer from each link, then open it in the Temporal UI and see which worker ran each step
```

## Try it yourself

The transfer app's baseline and the Temporal UI are cluster addresses: they open only with the sudo connection
(`references/finish/report.md`, "Try it": the reconnect goes first in the steps, and you ask for it in chat when
you show the page, then check the links, "After each scenario").

- **Baseline:** start a transfer from the transfer app at its cluster address,
  http://temporal-py-client-ui.temporal.svc:8080: no key is added, so the page shows "Routing Key: undefined".
- **Sandbox:** start a transfer from the sandbox's preview link: the page shows the sandbox's routing key.
- **Check:** open the Temporal UI, http://temporal-ui-service.temporal.svc: both transfers are on the one
  `money-transfer` task queue. Open each; its completed steps list the worker that ran them (Identity): the normal
  worker for the first, the sandbox's (`…temporal-worker<suffix>-dep-temporal-worker-…`) for the second. A
  "Workflow Task Failed … cannot handle routing key" event is the other worker handing a step back. In a terminal:
  `kubectl --kubeconfig <T>/kubeconfig -n temporal logs -f deploy/temporal-worker -c temporal-worker | grep 'routing key'`.

## Tear down

```bash
"$T/bin/sd" sandbox delete temporal-worker<suffix>
"$T/bin/kc" delete namespace temporal
```

## Docs

https://www.signadot.com/docs/tutorials/testing-temporal-workers.md, with the interceptors explained. The trial loads
images into kind instead of minikube, uses the baseline image for the sandboxed worker, and shortens the routing
refresh from 120 to 10 seconds so the proof doesn't wait two minutes.
