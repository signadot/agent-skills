# Kafka

`<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md. Uses the driver sandbox `driver-plates<suffix>` from the
two-service scenario.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD; driver is the changed service. Point out step 3 to 4: frontend puts each ride request on
  Kafka's `dispatch` topic, and driver consumes it.
- **The change:** driver gives every driver's licence plate an `SD-` prefix (a prebuilt image; in a team, the image
  CI builds from the pull request).
- **The sandbox:** `driver-plates<suffix>`, a copy of driver (from the two-service scenario, or created here). Also
  created: nothing in Kafka. The copy reads the same topic in its own consumer group (the normal group's name plus
  `-<routing key>`), so it gets a copy of every message.
- **Routing:** the sandbox's link adds its key; OpenTelemetry carries it from frontend into the Kafka message's
  headers. No sidecar routes messages: each driver reads the key on every message, the copy processes only
  messages with its sandbox's key, and the normal driver skips those.

## Costs

About 2 minutes. Nothing new to create or deploy: it uses HotROD's own Kafka in namespace `hotrod`.

## Before you start

The sandbox `driver-plates<suffix>` must exist and be ready. If the two-service scenario was skipped, or a mesh
rebuild removed it, create it (safe to run again; record it under Resources if it's new):

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/driver-plates.yaml" --set cluster=<cluster> --set suffix=<suffix>
```

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

For the page's diagram: `frontend → kafka:dispatch → driver(baseline: <plate>) · driver(driver-plates<suffix>:
SD-<plate>)`.

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
specs: assets/specs/core/driver-plates.yaml
links: https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka
try: book rides on the baseline and sandbox links and watch both driver logs
```

## Try it yourself

- **Baseline:** request a ride on the baseline link: plates like `T757183C`.
- **Sandbox:** request a ride on the sandbox's link: plates start with `SD-`.
- **Check:** follow `Dispatch successful` in the normal driver (`deploy/driver`) and in
  `driver-plates<suffix>-dep-driver-…`: each ride appears in only one, the sandbox's with an `SD-` plate, though
  both drivers received both messages.
- **More:** send the key yourself with curl (`references/finish/report.md`, "Try it").

## Tear down

Nothing of its own: `driver-plates<suffix>` is removed at teardown.

## Docs

https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka.md explains the consumer-side pattern.
https://www.signadot.com/docs/tutorials/testing-kafka-microservices.md walks through it with a separate demo app;
the trial uses HotROD's built-in Kafka instead, so nothing extra is deployed.
