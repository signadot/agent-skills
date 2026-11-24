# Test one service change in isolation

Always runs, first, and always changes route. About 1 minute. `<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD, as in the template; route is the changed service.
- **The change:** route works out each driver's ETA. With `FAST_ROUTE` set, a setting route already has, every ETA
  comes back as 1 second instead of minutes, so no image needs building. In a team's CI the sandbox would run the
  image built from the pull request.
- **The sandbox:** a copy of only `route`, with `FAST_ROUTE=1`, next to the normal one. Frontend, Kafka, driver,
  location, Redis and MySQL stay shared. Nothing else is created.
- **Routing:** the sandbox's preview link adds its key. HotROD passes it along with OpenTelemetry, from frontend
  through the Kafka message to driver, and on driver's call to route. The DevMesh sidecar in the normal route's pod
  reads it and forwards those calls to the sandbox's route.

Introduce the terms in one line each: a **sandbox** runs only the services you changed, next to the shared
**baseline**; a **routing key** sent with a request (`baggage: sd-routing-key=<key>`) sends it to the sandbox.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/fast-route.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get fast-route<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

`sandbox apply` waits until the sandbox is ready. The second command prints its routing key. Record
`sandbox fast-route<suffix>` under Resources.

## Prove it

```bash
bash "$S/scripts/ride.sh" --proxy <proxy>
bash "$S/scripts/ride.sh" --proxy <proxy> --key <routing key>
```

Done when the ride without the key has an ETA in minutes (like `23m14s`) with every hop `baseline`, and the ride
with the key has the ETA `1s` with the hop `route fast-route<suffix>`. Point out that the sandbox was ready in
seconds and is one pod.

## Record

```markdown
## Scenario isolated-change
status: passed
seconds: <apply to proof>
baseline: ETA <minutes>
sandbox: ETA 1s
hops-baseline: <hops line from the first ride>
hops-sandbox: <hops line from the second ride>
routing-key: <routing key>
proof: the route step was served by sandbox fast-route<suffix> only when the routing key was sent
commands: sd sandbox apply -f assets/specs/core/fast-route.yaml --set cluster=<cluster> --set suffix=<suffix>
specs: assets/specs/core/fast-route.yaml
screenshot: screens/isolated-change.png (only if you took one)
links: https://www.signadot.com/docs/tutorials/quickstart/first-sandbox
try: open the baseline and sandbox links and compare the ETAs; kubectl --kubeconfig <T>/kubeconfig -n hotrod get pods
```

**Screenshot (optional):** if you can drive a browser, open the sandbox's link in the browser session from signup,
book a ride, and save `$T/report/screens/isolated-change.png` once the ETA shows.

## Try it yourself

- **Baseline:** request a ride on the baseline link: ETAs in minutes.
- **Sandbox:** request a ride on the sandbox's link: every ETA is 1 second.
- **Check:** follow `Finding route` in the normal route (`deploy/route`) and in the sandbox's
  (`fast-route<suffix>-dep-route-…`): baseline rides appear only in the first, sandbox rides only in the second.
- **More:** send the key yourself with curl to the frontend's cluster address (`references/finish/report.md`, "Try
  it"); see the sandbox in the dashboard, https://app.signadot.com/sandboxes.

## Tear down

```bash
"$T/bin/sd" sandbox delete fast-route<suffix>
```

## Docs

https://www.signadot.com/docs/tutorials/quickstart/first-sandbox.md. The tutorial forks the driver from a prebuilt
image; the trial forks route with a setting, so the change doesn't involve Kafka consumers (the Kafka scenario covers
those).
