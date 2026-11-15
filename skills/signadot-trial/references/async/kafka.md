# Kafka

`<suffix>` and `<proxy>` as in C1 (drop `--proxy` for a privileged connection). Needs C1's `driver-plates<suffix>`.

## What it shows

- **Problem:** with a shared message broker, a consumer under test either steals messages meant for everyone else,
  or needs its own broker and topics, which is slow and expensive.
- **What Signadot does:** HotROD's frontend publishes every ride request to one Kafka topic, and both drivers (the
  baseline and the C1 sandbox) consume it. Each request carries its routing key; each consumer processes only the
  messages that are its own and skips the rest.
- **Why it matters:** async flows are tested end to end on the shared broker, without copying Kafka or topics, and
  without interfering with anyone else.

## Costs

About 2 minutes. Nothing new to create or deploy: it uses HotROD's own Kafka in namespace `hotrod`.

## Before you start

C1's sandbox `driver-plates<suffix>` must exist and be ready.

## Set up

Find the two driver pods: the baseline one and the sandbox's fork.

```bash
"$T/bin/kc" -n hotrod get pods -o name | grep -E 'pod/driver-[a-z0-9]+-[a-z0-9]+$'
"$T/bin/kc" -n hotrod get pods -o name | grep "pod/driver-plates<suffix>-dep-driver-"
```

## Run

Book one ride without the key and one with it:

```bash
bash "$S/scripts/ride.sh" --proxy <proxy>
bash "$S/scripts/ride.sh" --proxy <proxy> --key <driver-plates routing key>
```

Note both plates.

## Prove it

Each driver logs `Dispatch successful` with the plate (`driverID`) of every request it consumed:

```bash
"$T/bin/kc" -n hotrod logs <baseline driver pod> -c hotrod --since=2m | grep 'Dispatch successful' | grep -oE '"driverID": *"[^"]*"'
"$T/bin/kc" -n hotrod logs <sandbox driver pod> -c hotrod --since=2m | grep 'Dispatch successful' | grep -oE '"driverID": *"[^"]*"'
```

Done when the baseline pod's log has the unkeyed ride's plate and no `SD-` plates, and the sandbox pod's log has
the keyed ride's plate and only `SD-` plates. Earlier rides may show up too; the split is what matters. Both
requests went through the same broker and topic.

Message path for the card: `frontend → kafka:dispatch → driver(baseline: <plate>) · driver(driver-plates<suffix>:
SD-<plate>)`. Draw the topic as a `hop msg`.

## Record

```markdown
## Scenario kafka
status: passed
seconds: <rides to proof>
baseline: the baseline driver consumed only ride <plate>
sandbox: the sandbox driver consumed only ride <SD- plate>
hops-baseline: frontend → kafka:dispatch → driver(baseline)
hops-sandbox: frontend → kafka:dispatch → driver(driver-plates<suffix>)
proof: one broker, one topic; each consumer processed only the messages carrying its routing key
commands: ride.sh with and without the key; kubectl logs on both driver pods
specs: assets/specs/core/driver-plates.yaml (from C1)
links: https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka
try: book several keyed and unkeyed rides and watch both driver logs
```

## Try it yourself

- Follow both driver logs (`<T>/bin/kc -n hotrod logs -f <pod> -c hotrod | grep Dispatch`) while you book rides
  with and without the key.

## Tear down

Nothing of its own: C1's sandbox is removed with the core tutorial.

## Docs

https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka.md explains the consumer-side pattern.
https://www.signadot.com/docs/tutorials/testing-kafka-microservices.md walks through it with a separate demo app;
the trial uses HotROD's built-in Kafka instead, so nothing extra is deployed.
