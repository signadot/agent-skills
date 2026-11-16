# RabbitMQ

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

- **The demo app** (not HotROD): a small order app. A publisher service takes each order over HTTP and publishes it
  to one RabbitMQ exchange, `orders`; a consumer service processes the orders it receives. It has no web page: the
  consumers' logs show who processed each order. Explain this first on the page: the user has only seen HotROD so
  far.
- **Problem:** consumers on a shared RabbitMQ broker compete for messages, so a consumer under test either steals
  other people's messages or needs its own broker.
- **What Signadot does:** a small order app publishes to one exchange; the baseline consumer and a sandboxed consumer
  each get a copy on their own queue. OpenTelemetry carries the routing key from the HTTP request into the message
  headers, and each consumer processes only the messages that are its own and skips the rest.
- **Why it matters:** message-driven changes are tested end to end on the shared broker, with no duplicate brokers
  or queues to manage.

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
curl -s --proxy <proxy> -X POST http://publisher.rabbitmq-demo.svc:8080/publish -H 'Content-Type: application/json' \
  -d '{"order_id":"trial-1","amount":100,"message":"Baseline order"}'
curl -s --proxy <proxy> -X POST http://publisher.rabbitmq-demo.svc:8080/publish -H 'Content-Type: application/json' \
  -H "baggage: sd-routing-key=<key>" -d '{"order_id":"trial-2","amount":200,"message":"Sandbox order"}'
```

## Prove it

```bash
"$T/bin/kc" -n rabbitmq-demo logs deploy/consumer -c consumer --since=5m | grep -E 'PROCESSING|SKIP'
"$T/bin/kc" -n rabbitmq-demo get pods -o name | grep "rabbitmq-consumer<suffix>-dep-consumer-"
"$T/bin/kc" -n rabbitmq-demo logs <sandbox consumer pod> -c consumer --since=5m | grep -E 'PROCESSING|SKIP'
```

Done when the baseline consumer processed `trial-1` and skipped `trial-2`, and the sandbox consumer processed
`trial-2` only. Both orders went through the same exchange.

For the page's diagram: `publisher → rabbitmq:orders → consumer(baseline: trial-1) · consumer(rabbitmq-consumer<suffix>:
trial-2)`.

## Record

```markdown
## Scenario rabbitmq
status: passed
seconds: <sandbox apply to proof>
baseline: the baseline consumer processed trial-1 and skipped trial-2
sandbox: the sandbox consumer processed only trial-2
hops-baseline: publisher → rabbitmq:orders → consumer(baseline)
hops-sandbox: publisher → rabbitmq:orders → consumer(rabbitmq-consumer<suffix>)
proof: one broker and exchange; each consumer processed only the orders carrying its routing key
commands: kubectl apply (rabbitmq-signadot-demo); sd sandbox apply -f assets/specs/async/rabbitmq-consumer.yaml …; curl …/publish
specs: assets/specs/async/rabbitmq-consumer.yaml
links: https://www.signadot.com/docs/tutorials/testing-rabbitmq-microservices
try: publish more orders with and without the key and watch both consumer logs
```

## Try it yourself

- Follow both consumers' logs: `kubectl --kubeconfig <T>/kubeconfig -n rabbitmq-demo logs -f deploy/consumer | grep -E 'PROCESSING|SKIP'`,
  and the same for the sandbox's consumer pod. Ask your agent to publish more orders with and without the key.
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
