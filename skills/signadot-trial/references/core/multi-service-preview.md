# C2 · Test a feature across two services, with a shareable preview

Runs by default. About 2 minutes. Needs C1's sandbox. `<cluster>`, `<suffix>` and `<proxy>` as in C1.

## What it shows

- **Problem:** a feature often spans several services and pull requests, and can only be tested once everything is
  merged and deployed together.
- **What Signadot does:** a route group joins the sandboxes that share a label (`feature: hotrod-plates<suffix>`)
  under one routing key, and its endpoint gives a preview URL. Here the frontend sandbox highlights `SD-` plates,
  and the driver sandbox from C1 produces them.
- **Why it matters:** reviewers, designers and PMs open one URL and see the whole feature before anything merges.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/frontend-highlight.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup apply -f "$S/assets/specs/core/hotrod-plates-routegroup.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get hotrod-plates<suffix> -o json
```

Record `sandbox frontend-highlight<suffix>` and `routegroup hotrod-plates<suffix>` under Resources. From the route
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

For the flow diagram, put `frontend(frontend-highlight<suffix>)` in front of the keyed ride's hops, and
`frontend(baseline)` in front of the baseline's.

Give the user the preview URL: anyone signed in to the org can open it, book a ride, and see the highlighted plate.
It needs no header or proxy.

## Record

```markdown
## Scenario C2
status: passed
seconds: <apply to proof>
baseline: bundle <baseline bundle>, plate <plate>
sandbox: bundle <sandbox bundle>, plate SD-<plate> highlighted
hops-baseline: frontend(baseline) → location(baseline) → driver(baseline) → route(baseline)
hops-sandbox: frontend(frontend-highlight<suffix>) → <hops line from the keyed ride>
proof: one routing key reached both sandboxes; preview <preview URL>
commands: sd sandbox apply -f assets/specs/core/frontend-highlight.yaml …; sd routegroup apply -f assets/specs/core/hotrod-plates-routegroup.yaml …
specs: assets/specs/core/frontend-highlight.yaml, assets/specs/core/hotrod-plates-routegroup.yaml
screenshot: screens/C2.png (only if you took one)
links: https://www.signadot.com/docs/tutorials/multi-pr-feature-testing, <preview URL>
try: open the preview URL and book a ride
```

**Screenshot (optional):** open the preview URL in the browser session from signup, book a ride, and save
`$T/report/screens/C2.png` once the highlighted `SD-` plate shows.

## Try it yourself

- Open the preview URL and book a ride: the plate is highlighted.
- Share it with a teammate in the same org.
- See the route group in the dashboard: https://app.signadot.com/routegroups.

## Tear down

```bash
"$T/bin/sd" routegroup delete hotrod-plates<suffix>
"$T/bin/sd" sandbox delete frontend-highlight<suffix>
```

## Docs

https://www.signadot.com/docs/tutorials/multi-pr-feature-testing.md. The tutorial builds images for each pull
request; the trial uses prebuilt ones.
