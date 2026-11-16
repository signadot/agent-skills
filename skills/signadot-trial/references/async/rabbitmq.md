# RabbitMQ

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

- **The demo app** (not HotROD): a small order app. A publisher service takes each order over HTTP (`POST /publish`)
  and publishes it to one RabbitMQ topic exchange, `orders_exchange`; a consumer service processes the orders. Every
  consumer version declares its own queue and binds it to the exchange with `#`, so every queue gets a copy of every
  order. The app has no page of its own; RabbitMQ's management UI is the place to watch it (the queues, and the
  exchange's bindings). Explain this first on the page: the user has only seen HotROD so far.
- **Problem:** RabbitMQ gives each message in a queue to only one of its consumers, so a consumer under test on the
  shared queue would take some of everyone else's orders. Without Signadot, it needs its own broker.
- **What Signadot does:** the sandbox's consumer gets its own queue (`QUEUE_NAME` in the spec) on the same exchange,
  so both consumers see every order. OpenTelemetry carries the routing key from the HTTP request into the message's
  headers. Each consumer reads the key on every message: the sandbox's consumer processes only messages with its
  sandbox's key; the baseline consumer processes everything else (no key, or a key no consumer sandbox claims) and
  skips messages with the sandbox's key. Every 10 seconds each consumer asks Signadot's route server which keys
  belong to sandboxes of the consumer. Both acknowledge every message, processed or skipped, so nothing piles up.
- **Two kinds of routing key** (say so on the page; the management UI shows the other one): RabbitMQ's own routing
  key is what the exchange matches against bindings, always `orders` here, and `#` matches it. Signadot's routing
  key identifies a sandbox and travels as `sd-routing-key` in the OpenTelemetry `baggage` header.
- **Why it matters:** a consumer change is tested end to end on the shared broker, with no second broker; the
  sandbox adds only a temporary queue, which RabbitMQ deletes when the sandbox goes.

## Costs

About 3 minutes (image pulls on first run). About 0.5 GB of memory. Namespace `rabbitmq-demo`.

## Before you start

The demo comes from `signadot/examples` in `$T/examples`, fetched at a pinned commit by `references/setup/cluster.md`
§2.

## Set up

Start this as soon as the cluster is up, so the images pull while you do the basics.

```bash
cd "$T/examples/rabbitmq-signadot-demo"
"$T/bin/kc" apply -f k8s/namespace.yaml
"$T/bin/kc" apply -n rabbitmq-demo -f k8s/rabbitmq.yaml -f k8s/redis.yaml
"$T/bin/kc" -n rabbitmq-demo wait --for=condition=ready pod -l app=rabbitmq --timeout=300s
"$T/bin/kc" -n rabbitmq-demo wait --for=condition=ready pod -l app=redis --timeout=120s
"$T/bin/kc" apply -n rabbitmq-demo -f k8s/publisher.yaml -f k8s/consumer.yaml
"$T/bin/kc" -n rabbitmq-demo wait --for=condition=available deploy --all --timeout=300s
```

Done when every deployment in `rabbitmq-demo` is available. If you deployed it before the operator, restart it
as `references/setup/cluster.md` §3 says. Record `namespace rabbitmq-demo` under Resources.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/async/rabbitmq-consumer.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get rabbitmq-consumer<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

Record `sandbox rabbitmq-consumer<suffix>` under Resources. Wait about 10 seconds after it's ready: the consumers
refresh their routing rules every 10 seconds.

Publish one order without the key and one with it:

```bash
curl -sS --proxy <proxy> -X POST http://publisher.rabbitmq-demo.svc:8080/publish -H 'Content-Type: application/json' \
  -d '{"order_id":"trial-1","amount":100,"message":"Baseline order"}'
curl -sS --proxy <proxy> -X POST http://publisher.rabbitmq-demo.svc:8080/publish -H 'Content-Type: application/json' \
  -H "baggage: sd-routing-key=<key>" -d '{"order_id":"trial-2","amount":200,"message":"Sandbox order"}'
```

## Prove it

```bash
"$T/bin/kc" -n rabbitmq-demo logs deploy/consumer -c consumer --since=5m | grep -E 'PROCESSING|SKIP|ACCEPT'
"$T/bin/kc" -n rabbitmq-demo get pods -o name | grep "rabbitmq-consumer<suffix>-dep-consumer-"
"$T/bin/kc" -n rabbitmq-demo logs <sandbox consumer pod> -c consumer --since=5m | grep -E 'PROCESSING|process='
```

Done when the baseline consumer processed `trial-1` (`ACCEPT (no routing key)`, then `PROCESSING ORDER trial-1`)
and skipped `trial-2` (`SKIP (active sandbox key …)`), and the sandbox consumer processed `trial-2` only (its
`process=True` line; `trial-1` has `process=False`). Both orders went through the same exchange.

For the page's diagram: the request sources are the two `curl` requests (without and with the key); the row is
publisher → `orders_exchange` (a `bus`) → two queues, `consumer-baseline` and `consumer-trial<suffix>` (one `bus`
each) → the normal consumer and, in the sandbox's outline, the new one. Both lanes go through the publisher and the
exchange and into both queues; mark the order each consumer processed in its box (`trial-1` in the normal one,
`trial-2` in the new one) and the one it skipped as "skipped". No router: each consumer decides.

## Record

```markdown
## Scenario rabbitmq
status: passed
seconds: <sandbox apply to proof>
baseline: the baseline consumer processed trial-1 and skipped trial-2
sandbox: the sandbox consumer processed only trial-2
hops-baseline: publisher → orders_exchange → consumer-baseline queue → consumer (baseline)
hops-sandbox: publisher → orders_exchange → consumer-trial<suffix> queue → consumer (rabbitmq-consumer<suffix>)
proof: one broker and exchange, a queue per consumer; the sandbox's consumer processed only the order with its key, and the baseline consumer only the other
commands: kubectl apply (rabbitmq-signadot-demo); sd sandbox apply -f assets/specs/async/rabbitmq-consumer.yaml …; curl …/publish
specs: assets/specs/async/rabbitmq-consumer.yaml
links: https://www.signadot.com/docs/tutorials/testing-rabbitmq-microservices
link-rabbitmq-ui: http://rabbitmq.rabbitmq-demo.svc:15672 (guest / guest; opens once the laptop has the sudo connection)
try: publish more orders with and without the key and watch both consumer logs
```

## Try it yourself

The link box leads the page with RabbitMQ's management UI (`references/finish/report.md`, "App links"). It's a
cluster address, so it opens in the user's browser only once the laptop has Signadot's connection with sudo. When
`connect_mode` is `unprivileged`, the reconnect goes first in the link box, and you ask for it in chat when you show
the page, then check the link (`references/finish/report.md`, "After each scenario"):
`curl -sS -o /dev/null -w '%{http_code}\n' http://rabbitmq.rabbitmq-demo.svc:15672/` prints `200`.

- Open RabbitMQ's management UI, http://rabbitmq.rabbitmq-demo.svc:15672, and sign in with the demo's default user,
  `guest` / `guest`. Under Queues there are two: `consumer-baseline` (the normal consumer's, durable) and
  `consumer-trial<suffix>` (the sandbox's, deleted with it). Under Exchanges, `orders_exchange` shows both bound
  with `#`, so every order reaches both; each consumer then processes only its own.
- Publish orders yourself, with and without the key, to the publisher's cluster address (the commands from "Run",
  without `--proxy`, using `-sS`), and watch each queue's message rate move for every order.
- Follow both consumers' logs:
  `kubectl --kubeconfig <T>/kubeconfig -n rabbitmq-demo logs -f deploy/consumer -c consumer | grep -E 'PROCESSING|SKIP|ACCEPT'`,
  and `… logs -f <sandbox consumer pod> -c consumer | grep -E 'PROCESSING|process='` for the sandbox's.
- The docs page also forks the publisher and joins both in a route group; its sandbox specs are in
  `<T>/examples/rabbitmq-signadot-demo/signadot/`.

## Tear down

```bash
"$T/bin/sd" sandbox delete rabbitmq-consumer<suffix>
"$T/bin/kc" delete namespace rabbitmq-demo
```

## Docs

https://www.signadot.com/docs/tutorials/testing-rabbitmq-microservices.md, with the consumer and publisher code
explained. The trial forks only the consumer, with a suffixed name so it can't collide with other sandboxes in an
existing org.
