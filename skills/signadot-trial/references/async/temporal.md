# Temporal

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

- **Problem:** Temporal workers poll a shared task queue, so a worker under test picks up other people's workflows,
  and a separate Temporal server or task queue per change is heavy.
- **What Signadot does:** a money-transfer app runs workflows on one task queue (`money-transfer`). A sandboxed
  worker joins the same queue. The routing key travels from the HTTP request into the workflow's headers, and each
  worker runs only the tasks that are its own; the others it hands back.
- **Why it matters:** workflow and activity changes are tested against the real Temporal server and queue, without
  duplicating either.

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

Once the operator is installed, create the baseline link for the report (a route group that matches no sandbox, so
its preview link always opens the unchanged Temporal demo app's page; see `references/setup/cluster.md` §5):

```bash
"$T/bin/sd" routegroup apply -f "$S/assets/specs/async/temporal-baseline.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get temporal-baseline<suffix> -o json | grep -oE '"url": *"https://[^"]+"' | head -1
```

Record `routegroup temporal-baseline<suffix>` under Resources.

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
links: https://www.signadot.com/docs/tutorials/testing-temporal-workers
try: start transfers from both links; open the Temporal UI and see the workflows on the one task queue
```

## Try it yourself

- Start transfers from the baseline and sandbox links, and follow the baseline worker's log:
  `kubectl --kubeconfig <T>/kubeconfig -n temporal logs -f deploy/temporal-worker -c temporal-worker | grep 'routing key'`.
- Open the Temporal UI: `kubectl --kubeconfig <T>/kubeconfig -n temporal port-forward svc/temporal-ui-service 8233:80`, then
  http://localhost:8233. All the workflows are there, on the same task queue.

## Tear down

```bash
"$T/bin/sd" routegroup delete temporal-baseline<suffix>
"$T/bin/sd" sandbox delete temporal-worker<suffix>
"$T/bin/kc" delete namespace temporal
```

## Docs

https://www.signadot.com/docs/tutorials/testing-temporal-workers.md, with the interceptors explained. The trial loads
images into kind instead of minikube, uses the baseline image for the sandboxed worker, and shortens the routing
refresh from 120 to 10 seconds so the proof doesn't wait two minutes.
