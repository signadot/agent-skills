# Redis Streams

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

- **Problem:** consumers of a shared Redis stream share a consumer group, so a consumer under test would take
  entries meant for the baseline.
- **What Signadot does:** a producer, consumer and notifier share one stream (`demo:messages`). The sandboxed
  consumer (running "processor v2", which uppercases messages) reads the stream through its own consumer group. The
  routing key travels in each entry's fields; every consumer acknowledges every entry and processes only the ones
  that are its own.
- **Why it matters:** stream-processing changes are tested on the real stream, with no copy of Redis and no lost or
  duplicated entries.

## Costs

About 3 minutes, including a local image build. About 0.5 GB of memory. Namespace `redis-streams-demo`.

## Before you start

The demo comes from `signadot/examples` in `$T/examples` (`references/setup/cluster.md` §2). It has no published image, so you build it locally and load it into the kind node;
no registry is needed. On an existing (non-kind) cluster, use that cluster's way of loading local images instead
(for example `minikube image load`).

## Set up

```bash
cd "$T/examples/selective-consumption-with-redis-streams/python"
docker build -q -t redis-streams-demo-python:latest . > "$T/logs/redis-streams-build.log" 2>&1
kind load docker-image redis-streams-demo-python:latest --name signadot-trial
"$T/bin/kc" create namespace redis-streams-demo --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/kc" apply -f k8s/
"$T/bin/kc" -n redis-streams-demo wait --for=condition=available deploy --all --timeout=300s
```

Done when every deployment in `redis-streams-demo` is available. If you deployed it before the operator, restart it
as `references/setup/cluster.md` §3 says. Record `namespace redis-streams-demo` under Resources.

Once the operator is installed, create the baseline link for the report (a route group that matches no sandbox, so
its preview link always opens the unchanged producer's page; see `references/setup/cluster.md` §5):

```bash
"$T/bin/sd" routegroup apply -f "$S/assets/specs/async/redis-streams-baseline.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get redis-streams-baseline<suffix> -o json | grep -oE '"url": *"https://[^"]+"' | head -1
```

Record `routegroup redis-streams-baseline<suffix>` under Resources.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/async/redis-streams-consumer.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get redis-streams-consumer<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

Record `sandbox redis-streams-consumer<suffix>` under Resources. Wait about 10 seconds for the consumers to pick up
the new routing rules, then publish one entry without the key and one with it:

```bash
curl -s --proxy <proxy> -X POST http://producer.redis-streams-demo.svc:4000/api/publish -H 'Content-Type: application/json' \
  -d '{"messageID": "trial-1", "messageBody": "hello trial-1"}'
curl -s --proxy <proxy> -X POST http://producer.redis-streams-demo.svc:4000/api/publish -H 'Content-Type: application/json' \
  -H "baggage: sd-routing-key=<key>" -d '{"messageID": "trial-2", "messageBody": "hello trial-2"}'
```

Each call prints the stream entry ID.

## Prove it

```bash
"$T/bin/kc" -n redis-streams-demo logs deploy/consumer --since=5m | grep -E 'processing|skipped'
"$T/bin/kc" -n redis-streams-demo get pods -o name | grep "redis-streams-consumer<suffix>-dep-consumer-"
"$T/bin/kc" -n redis-streams-demo logs <sandbox consumer pod> --since=5m | grep -E 'processing|skipped'
curl -s --proxy <proxy> http://producer.redis-streams-demo.svc:4000/api/events \
  | awk '{ gsub(/\{"context":/, "\n{\"context\":"); print }' | grep trial-2 | grep -oE '"sandboxName":"[^"]*"|"logEntry":"[^"]*'
```

Done when the baseline consumer logged `processing <trial-1 entry> (routing key None)` and `skipped <trial-2 entry>`,
and the sandbox consumer the opposite. The event trail for `trial-2` shows it consumed by
`redis-streams-consumer<suffix>` "with processor v2".

For the page's diagram: `producer → redis:demo:messages → consumer(baseline: trial-1) ·
consumer(redis-streams-consumer<suffix>: trial-2)`.

## Record

```markdown
## Scenario redis-streams
status: passed
seconds: <sandbox apply to proof>
baseline: the baseline consumer processed trial-1 (processor v1) and skipped trial-2
sandbox: the sandbox consumer processed only trial-2 (processor v2)
hops-baseline: producer → redis:demo:messages → consumer(baseline)
hops-sandbox: producer → redis:demo:messages → consumer(redis-streams-consumer<suffix>)
proof: one stream; a consumer group per version; each processed only the entries carrying its routing key
commands: docker build + kind load; kubectl apply -f k8s/; sd sandbox apply -f assets/specs/async/redis-streams-consumer.yaml …; curl …/api/publish
specs: assets/specs/async/redis-streams-consumer.yaml
links: https://www.signadot.com/docs/tutorials/testing-redis-streams
try: publish messages from both links and look at the consumer groups with XINFO GROUPS
```

## Try it yourself

- Publish messages from the baseline and sandbox links (the producer's page shows each message's trail): only
  the sandbox's are processed by "processor v2", in upper case.
- See the consumer groups on the stream:
  `kubectl --kubeconfig <T>/kubeconfig -n redis-streams-demo exec deploy/redis -- redis-cli XINFO GROUPS demo:messages`.
- The docs page also forks the producer and the notifier; their specs are in
  `<T>/examples/selective-consumption-with-redis-streams/python/signadot/`.

## Tear down

```bash
"$T/bin/sd" routegroup delete redis-streams-baseline<suffix>
"$T/bin/sd" sandbox delete redis-streams-consumer<suffix>
"$T/bin/kc" delete namespace redis-streams-demo
```

## Docs

https://www.signadot.com/docs/tutorials/testing-redis-streams.md, with the consumer-group pattern explained. The
tutorial pushes the image to a registry; the trial loads it straight into the kind node, and forks only the
consumer.
