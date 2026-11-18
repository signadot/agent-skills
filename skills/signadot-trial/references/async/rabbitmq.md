# RabbitMQ

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app** (not HotROD; the user has only seen HotROD): a small order app with no page of its own. Steps for
  the diagram: (1) a client sends an order to the publisher (`POST /publish`); (2) the publisher publishes it to one
  RabbitMQ topic exchange, `orders_exchange`; (3) the exchange copies it to every queue bound with `#`, one queue per
  consumer version; (4) each consumer takes it from its queue. RabbitMQ's management UI shows the exchange, the
  queues and their message rates, and can publish a message itself: it's the app's UI for this scenario.
- **The change:** the sandbox's consumer is a new version of the consumer. In the trial it runs the same code, so
  what the page shows is which consumer processes which order; with your own services it would run the image built
  from the pull request.
- **The sandbox:** a copy of `consumer`. Also created: its own temporary queue, `consumer-trial<suffix>`
  (`QUEUE_NAME` in the spec), bound to the same exchange; RabbitMQ deletes it when the sandbox goes. No second
  broker. Without its own queue the copy would compete with the baseline for the same messages.
- **Routing:** the key comes with the order: a `baggage` header on the request to the publisher (OpenTelemetry
  copies it into the message's headers), or on a message published from the management UI. No sidecar routes
  messages: both consumers get every order, and each reads the key. The sandbox's consumer processes only orders
  with its sandbox's key; the baseline consumer processes everything else (no key, or a key no consumer sandbox
  claims) and skips the sandbox's. Every 10 seconds each consumer asks Signadot's route server which keys belong to
  sandboxes of the consumer. Both acknowledge every message, processed or skipped, so nothing piles up.
- **Two kinds of routing key** (say so on the page; the management UI shows the other one): RabbitMQ's own routing
  key is what the exchange matches against bindings, always `orders` here, and `#` matches it. Signadot's routing
  key identifies a sandbox and travels as `sd-routing-key` in the OpenTelemetry `baggage` header.

## Costs

About 3 minutes (image pulls on first run; on amd64, a local image build of about 1 minute instead). About 0.5 GB of
memory. Namespace `rabbitmq-demo`.

## Before you start

- The demo comes from `signadot/examples` in `$T/examples`, fetched at a pinned commit by
  `references/setup/cluster.md` §2.
- Its published images (`ghcr.io/emminex23/rabbitmq-publisher` and `-consumer`) exist only for arm64. On arm64
  (preflight `arch: arm64`, such as an Apple Silicon Mac) they pull and run as they are: skip the build lines below.
  On amd64 they fail with `ImagePullBackOff` ("no match"), so build both from the demo's source and load them into
  the kind node (no registry needed); on an existing (non-kind) cluster, use that cluster's way of loading local
  images. Record `rabbitmq-images: built (amd64)` under Fallbacks.

## Set up

Start this as soon as the cluster is up, so the images pull while you do the basics.

```bash
cd "$T/examples/rabbitmq-signadot-demo"
# amd64 only: build the two images and load them into kind
docker build -q -t rabbitmq-consumer:trial consumer > "$T/logs/rabbitmq-build.log" 2>&1
docker build -q -t rabbitmq-publisher:trial publisher >> "$T/logs/rabbitmq-build.log" 2>&1
kind load docker-image rabbitmq-consumer:trial rabbitmq-publisher:trial --name signadot-trial
"$T/bin/kc" apply -f k8s/namespace.yaml
"$T/bin/kc" apply -n rabbitmq-demo -f k8s/rabbitmq.yaml -f k8s/redis.yaml
"$T/bin/kc" -n rabbitmq-demo wait --for=condition=ready pod -l app=rabbitmq --timeout=300s
"$T/bin/kc" -n rabbitmq-demo wait --for=condition=ready pod -l app=redis --timeout=120s
"$T/bin/kc" apply -n rabbitmq-demo -f k8s/publisher.yaml -f k8s/consumer.yaml
# amd64 only: use the images built above
"$T/bin/kc" -n rabbitmq-demo set image deploy/consumer consumer=rabbitmq-consumer:trial
"$T/bin/kc" -n rabbitmq-demo set image deploy/publisher publisher=rabbitmq-publisher:trial
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

Give the management UI a preview link, so it opens in the user's browser without the sudo connection (and on WSL,
where cluster addresses never open in the browser):

```bash
"$T/bin/sd" routegroup apply -f "$S/assets/specs/async/rabbitmq-tools.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get rabbitmq-tools<suffix> -o json | grep -oE '"url": *"https://[^"]+"' | head -1
```

Record `routegroup rabbitmq-tools<suffix>` under Resources and the link as `link-rabbitmq-ui:`.

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
link-rabbitmq-ui: <the rabbitmq-tools<suffix> preview link> (guest / guest)
try: publish more orders with and without the key and watch both consumer logs
```

## Try it yourself

The management UI opens through its preview link (`link-rabbitmq-ui`), in any browser signed in to the org: no
sudo connection. Only the optional `curl` to the publisher uses a cluster address; put the reconnect inside that
step (`references/finish/report.md`, "Try it").

Put the live view first on the page, so the user watches the consumers while publishing:

- **Watch both consumers,** in two terminals:
  `kubectl --kubeconfig <T>/kubeconfig -n rabbitmq-demo logs -f deploy/consumer -c consumer | grep --line-buffered -E 'PROCESSING|SKIP|ACCEPT'`
  and the same for the sandbox's, `deploy/rabbitmq-consumer<suffix>-dep-consumer-…`, with
  `grep --line-buffered -E 'PROCESSING|process='`.
- **Open the management UI** through its preview link, and sign in with the demo's default user,
  `guest` / `guest`. Under Queues: `consumer-baseline` (the normal consumer's) and `consumer-trial<suffix>` (the
  sandbox's). Under Exchanges, `orders_exchange` shows both bound with `#`.
- **Baseline:** in the UI, open Exchanges → `orders_exchange` → Publish message; Routing key `orders`, Payload
  `{"order_id":"ui-1","amount":10}`, no headers; Publish. Or, in a terminal with the sudo connection,
  `curl -sS -X POST http://publisher.rabbitmq-demo.svc:8080/publish -H 'Content-Type: application/json' -d '{"order_id":"cli-1","amount":10}'`.
  The baseline consumer logs `ACCEPT (no routing key)` and `PROCESSING ORDER ui-1`; the sandbox's logs
  `process=False`.
- **Sandbox:** the same, with one header: name `baggage`, value `sd-routing-key=<key>`, and Payload
  `{"order_id":"ui-2","amount":20}`. Or the curl with `-H 'baggage: sd-routing-key=<key>'` and another order ID. The
  sandbox's consumer logs `process=True` and `PROCESSING ORDER ui-2`; the baseline logs
  `SKIP (active sandbox key '<key>')`.
- **Check:** in the UI, Queues: both queues' message rates moved for both orders. Every order reached both queues;
  each consumer chose which to process.
- **More:** the docs page also forks the publisher and joins both in a route group; its sandbox specs are in
  `<T>/examples/rabbitmq-signadot-demo/signadot/`.

## Tear down

```bash
"$T/bin/sd" sandbox delete rabbitmq-consumer<suffix>
"$T/bin/sd" routegroup delete rabbitmq-tools<suffix>
"$T/bin/kc" delete namespace rabbitmq-demo
```

## Docs

https://www.signadot.com/docs/tutorials/testing-rabbitmq-microservices.md, with the consumer and publisher code
explained. The trial forks only the consumer, with a suffixed name so it can't collide with other sandboxes in an
existing org.
