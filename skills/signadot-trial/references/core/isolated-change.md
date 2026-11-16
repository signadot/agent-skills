# Test one service change in isolation

Always runs. About 1 minute. `<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

## What it shows

- **The change:** a developer changed the route service, which computes each driver's ETA, and wants to check it
  end to end, against the real frontend, Kafka, driver and Redis, before merging. In the trial the change is one
  setting route already has, `FAST_ROUTE`: every ETA comes back as 1 second instead of minutes, so no image needs
  building. In a team's CI the sandbox would run the image built from the pull request.
- **What Signadot does:** a sandbox starts a second copy of only `route`, with the change, next to the normal one.
  Every other service is shared with the baseline. The sandbox gets a routing key; requests that carry it reach the
  new route, and all others reach the normal one.
- **How the key gets there:** the sandbox's preview link adds it to every request. HotROD passes it along with
  OpenTelemetry, from frontend through the Kafka message to driver, and on driver's call to route. The DevMesh
  sidecar on the normal route pod reads it and forwards those calls to the sandbox's route.

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

- Open the baseline and sandbox links (`references/finish/report.md`, "App links") and book a ride in each: only
  rides through the sandbox's link arrive in 1 second.
- See the sandbox's route pod next to the normal one: `kubectl --kubeconfig <T>/kubeconfig -n hotrod get pods`.
- See the sandbox, its routing key and its link: `<T>/bin/sd sandbox get fast-route<suffix>`.
- Send the routing key yourself, with curl through a port-forward (the page shows the commands; see
  `references/finish/report.md`, "Setting the key yourself").
- See it in the dashboard: https://app.signadot.com/sandboxes.

## Tear down

```bash
"$T/bin/sd" sandbox delete fast-route<suffix>
```

## Docs

https://www.signadot.com/docs/tutorials/quickstart/first-sandbox.md. The tutorial forks the driver from a prebuilt
image; the trial forks route with a setting, so the change doesn't involve Kafka consumers (the Kafka scenario covers
those).
