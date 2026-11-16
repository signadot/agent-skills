# Redis Streams

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app** (not HotROD; the user has only seen HotROD): a page where you publish a message. Steps for the
  diagram: (1) the producer's page takes a message and adds it to one Redis stream, `demo:messages`; (2) a consumer
  reads it from the stream and processes it (processor v1 keeps the text as it is, v2 makes it upper case); (3) a
  notifier sends the result; (4) the producer's page shows each message's trail: which service handled each step,
  and whether it was the baseline or a sandbox.
- **The change:** the consumer's processor v2, which upper-cases messages (`PROCESSOR_VERSION=v2` in the spec).
- **The sandbox:** a copy of `consumer` running v2. Also created: its own consumer group on the stream, so it reads
  every entry without taking any from the baseline's group.
- **Routing:** the sandbox's preview link adds its key to the producer's requests, and the producer writes it into
  each entry's fields. No sidecar routes entries: every consumer acknowledges every entry and processes only the
  ones that are its own.

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
link-baseline: http://producer.redis-streams-demo.svc:4000 (no routing key; needs the laptop's connection)
link-sandbox: <the sandbox's preview link>
try: publish a message from each link and compare the trails; look at the consumer groups with XINFO GROUPS
```

## Try it yourself

The producer's baseline is a cluster address: it opens only with the sudo connection
(`references/finish/report.md`, "Try it": the reconnect goes first in the steps, and you ask for it in chat when
you show the page, then check the link, "After each scenario").

- **Baseline:** publish a message from the producer's cluster address, http://producer.redis-streams-demo.svc:4000:
  the trail shows `routingKey: ""`, and `consumer (baseline)` processes it with processor v1.
- **Sandbox:** publish one from the sandbox's preview link: the trail shows the sandbox's routing key, and
  `consumer (sandbox=redis-streams-consumer<suffix>)` processes it with processor v2, in upper case.
- **Check:** the trail on the page shows which consumer processed each message. See both consumer groups on the
  stream:
  `kubectl --kubeconfig <T>/kubeconfig -n redis-streams-demo exec deploy/redis -- redis-cli XINFO GROUPS demo:messages`.
- **More:** the docs page also forks the producer and the notifier; their specs are in
  `<T>/examples/selective-consumption-with-redis-streams/python/signadot/`.

## Tear down

```bash
"$T/bin/sd" sandbox delete redis-streams-consumer<suffix>
"$T/bin/kc" delete namespace redis-streams-demo
```

## Docs

https://www.signadot.com/docs/tutorials/testing-redis-streams.md, with the consumer-group pattern explained. The
tutorial pushes the image to a registry; the trial loads it straight into the kind node, and forks only the
consumer.
