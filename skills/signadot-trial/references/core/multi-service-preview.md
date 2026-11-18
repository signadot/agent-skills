# Test a feature across two services, with a shareable preview

Runs by default. About 2 minutes. `<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD; driver and frontend are the changed services.
- **The change:** one feature across two services, as two pull requests would bring it: driver gives every
  driver's licence plate an `SD-` prefix, and frontend highlights those plates. Each runs from a prebuilt image (in
  a team, the images CI builds from the two pull requests).
- **The sandbox:** two sandboxes, `driver-plates<suffix>` and `frontend-highlight<suffix>`, each a copy of one
  service. Also created: a route group, `hotrod-plates<suffix>`, which joins them by their label
  (`feature: hotrod-plates<suffix>`) under one routing key and gives one preview link.
- **Routing:** the route group's link adds its key. The sidecar in the normal frontend's pod sends the page's
  requests to the new frontend. Driver gets its work from Kafka, so the new driver processes only the dispatch
  messages that carry the key and the normal driver skips them (the Kafka scenario shows that part).

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/driver-plates.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/frontend-highlight.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup apply -f "$S/assets/specs/core/hotrod-plates-routegroup.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get hotrod-plates<suffix> -o json
```

Record `sandbox driver-plates<suffix>`, `sandbox frontend-highlight<suffix>` and `routegroup hotrod-plates<suffix>`
under Resources. From the route
group's JSON, note `routingKey` and the `url` of its `frontend` endpoint (the preview URL, on
`preview.signadot.com`).

## Prove it

```bash
curl -s --proxy <proxy> http://frontend.hotrod.svc:8080/ | grep -oE 'index-[A-Za-z0-9_-]+\.js' | head -1
curl -s --proxy <proxy> -H "baggage: sd-routing-key=<route group routing key>" http://frontend.hotrod.svc:8080/ \
  | grep -oE 'index-[A-Za-z0-9_-]+\.js' | head -1
bash "$S/scripts/ride.sh" --proxy <proxy> --key <route group routing key>
```

Done when:
- the two bundle names differ: the frontend sandbox serves its own build;
- the keyed ride has an `SD-` plate and the hop `driver driver-plates<suffix>`: one key reached both sandboxes
  (HotROD's notifications don't include the frontend, so the bundle name is the frontend's proof);
- you have the preview URL.

For the page's diagram: the keyed request reaches `frontend-highlight<suffix>` and `driver-plates<suffix>`; the
request without the key reaches the normal frontend and driver. Route and location stay shared.

Give the user the preview URL: anyone signed in to the org can open it, book a ride, and see the highlighted plate.
It needs no header or proxy.

## Record

```markdown
## Scenario multi-service-preview
status: passed
seconds: <apply to proof>
baseline: bundle <baseline bundle>, plate <plate>
sandbox: bundle <sandbox bundle>, plate SD-<plate> highlighted
hops-baseline: frontend(baseline) → kafka → driver(baseline) → route(baseline)
hops-sandbox: frontend(frontend-highlight<suffix>) → <hops line from the keyed ride>
proof: one routing key reached both sandboxes; preview <preview URL>
commands: sd sandbox apply -f assets/specs/core/driver-plates.yaml …; sd sandbox apply -f assets/specs/core/frontend-highlight.yaml …; sd routegroup apply -f assets/specs/core/hotrod-plates-routegroup.yaml …
specs: assets/specs/core/driver-plates.yaml, assets/specs/core/frontend-highlight.yaml, assets/specs/core/hotrod-plates-routegroup.yaml
screenshot: screens/multi-service-preview.png (only if you took one)
links: https://www.signadot.com/docs/tutorials/multi-pr-feature-testing, <preview URL>
try: open the preview URL and book a ride
```

**Screenshot (optional):** open the preview URL in the browser session from signup, book a ride, and save
`$T/report/screens/multi-service-preview.png` once the highlighted `SD-` plate shows.

## Try it yourself

- **Baseline:** request a ride on the baseline link: plates like `T757183C`, not highlighted.
- **Sandbox:** request a ride on the route group's link: plates start with `SD-` and are highlighted. Anyone in the
  org can open it; share it with a teammate.
- **Check:** follow `Dispatch successful` in the normal driver (`deploy/driver`) and in
  `driver-plates<suffix>-dep-driver-…`: rides through the route group's link appear only in the second, with `SD-`
  plates.
- **More:** send the route group's key yourself with curl (`references/finish/report.md`, "Try it"); see the route
  group in the dashboard, https://app.signadot.com/routegroups.

## Tear down

```bash
"$T/bin/sd" routegroup delete hotrod-plates<suffix>
"$T/bin/sd" sandbox delete frontend-highlight<suffix>
"$T/bin/sd" sandbox delete driver-plates<suffix>
```

Kafka and the automated tests reuse `driver-plates<suffix>`, so delete it only at teardown.

## Docs

https://www.signadot.com/docs/tutorials/multi-pr-feature-testing.md. The tutorial builds images for each pull
request; the trial uses prebuilt ones.
