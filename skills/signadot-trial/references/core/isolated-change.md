# Test one service change in isolation

Always runs. About 1 minute. `<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

## What it shows

- **Problem:** testing a change to one microservice usually means waiting for a shared staging slot, or copying the
  whole stack.
- **What Signadot does:** a sandbox forks only the changed service (`driver`) from a prebuilt image. Every other
  service is shared with the baseline, and a routing key decides which version serves a request.
- **Why it matters:** each pull request gets its own environment in seconds, at the cost of one pod instead of a
  full stack copy.

Introduce the terms in one line each: a **sandbox** runs only the services you changed, next to the shared
**baseline**; a **routing key** sent with a request (`baggage: sd-routing-key=<key>`) sends it to the sandbox.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/driver-plates.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get driver-plates<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

`sandbox apply` waits until the sandbox is ready. The second command prints its routing key. Record
`sandbox driver-plates<suffix>` under Resources. The image's only change: driver plates start with `SD-`.

## Prove it

```bash
bash "$S/scripts/ride.sh" --proxy <proxy>
bash "$S/scripts/ride.sh" --proxy <proxy> --key <routing key>
```

Done when the ride without the key has a plate like `T751234C` with every hop `baseline`, and the ride with the key
has a plate starting with `SD-` (the driver is picked at random, so the digits differ) with the hop
`driver driver-plates<suffix>`. Point out that the sandbox was ready in seconds and is
one pod.

## Record

```markdown
## Scenario isolated-change
status: passed
seconds: <apply to proof>
baseline: plate <plate>
sandbox: plate <keyed plate, starting with SD->
hops-baseline: <hops line from the first ride>
hops-sandbox: <hops line from the second ride>
proof: the driver step was served by sandbox driver-plates<suffix> only when the routing key was sent
commands: sd sandbox apply -f assets/specs/core/driver-plates.yaml --set cluster=<cluster> --set suffix=<suffix>
specs: assets/specs/core/driver-plates.yaml
screenshot: screens/isolated-change.png (only if you took one)
links: https://www.signadot.com/docs/tutorials/quickstart/first-sandbox
try: book rides with and without the key: bash <S>/scripts/ride.sh --proxy <proxy> [--key <routing key>]
```

**Screenshot (optional):** if you can drive a browser, start a local proxy for `driver-plates<suffix>`
(`references/finish/report.md` "Screenshots"), open `http://localhost:18080`, book a ride, and save
`$T/report/screens/isolated-change.png`.

## Try it yourself

- Book rides with and without the key: `bash <S>/scripts/ride.sh --proxy <proxy> --key <routing key>`.
- See the sandbox in the dashboard: https://app.signadot.com/sandboxes.
- List it from the CLI: `<T>/bin/sd sandbox list`.

## Tear down

```bash
"$T/bin/sd" sandbox delete driver-plates<suffix>
```

Kafka and the automated tests reuse this sandbox, so delete it only at teardown.

## Docs

https://www.signadot.com/docs/tutorials/quickstart/first-sandbox.md. The tutorial builds its own image; the trial
uses a prebuilt one, so the sandbox is ready in seconds.
