# Reports

The trial writes one page per scenario and an overview page that links them, all in `$T/report/`, built from the
trial log (`references/trial-log.md`). Write each scenario's page as soon as it's proven, so the user gets it while
the next scenario runs. The scenario pages are the main thing the user takes away from the trial.

## Before the first page

```bash
mkdir -p "$T/report/screens" && cp "$S/assets/report/report.css" "$S/assets/report/report.js" "$T/report/"
```

## After each scenario

1. **Screenshot,** if you can drive a browser (see "Screenshots").
2. **Its page:** `cp "$S/assets/report/scenario.html" "$T/report/<scenario id>.html"`, replace `SCENARIO` in the
   `<title>`, and fill every `FILL:` slot. The template's examples are a finished page for "Test one change in
   isolation": write every scenario to the same depth, with this run's values. See "Writing a scenario page".
3. **The overview:** copy `assets/report/index.html` to `$T/report/index.html` again and fill it from the trial log,
   so it's always current (see "The overview page").
4. **Open the scenario page** with `open` (macOS) or `xdg-open` (Linux), or give the user its path. Then show the
   result in chat and ask before the next scenario (SKILL.md, "After each scenario").

In every page, escape `<`, `>` and `&` in anything copied from command output, and leave no `FILL:` comment or
template block behind.

## Writing a scenario page

Write for someone who is new to Signadot and didn't watch the run. The page explains how it works, not why to buy
it: no sales lines, no "usual way vs Signadot" comparisons, no adoption checklist. Plain words; define a Signadot
term the first time it appears; no file names, step IDs or placeholders. Use the scenario file's "What it shows"
for the story and its trial-log entry for every value.

Every page tells the same story, top to bottom:

1. **The change** someone wants to check end to end.
2. **The sandbox** that runs it: the spec, applied with the CLI, a second copy of only what changed, and its
   routing key.
3. **Requests with and without the routing key:** one diagram of both, with the results in it.
4. **What makes the routing work:** the key is set where the request starts, each service passes it along, and
   Signadot routes by it.

**Commands on the pages.** Each command the user might run goes in its own `<div class="cmd">` block (a one-line
explanation, then `<pre><code>`), so it gets a Copy button; specs go in one too. Make it paste-ready: full paths,
the real sandbox names, suffix and routing key, no `$T`, `<…>` or other placeholders. Use
`kubectl --kubeconfig <trial folder>/kubeconfig …` and `<trial folder>/bin/sd …`. Never show `ride.sh`, `--proxy`
or the trial's local proxy: the preview links, and the sudo connection for curl, replace them.

### The slots

- **title:** the scenario's menu name.
- **status:** the pill (`passed` or `failed`), "Scenario n" (its place in run order), the time from the scenario's
  first command to its proof, the cluster and the date.
- **headline:** one or two sentences that say what was proven, with the proving values.
- **urls:** the box with the demo app's two links (see "App links"): the baseline, and the sandbox with a line saying
  that Signadot adds the sandbox's routing key to every request made through it, so it reaches the changed version.
  Say what to look for in each. Leave the box out only for a demo app with no web page (RabbitMQ).
- **change:** two or three sentences: what changed, in which service, and what the developer wants to check end to
  end. Show the change itself when it's small (a code line, a setting, a patch), and say in one muted line how it
  maps to real use (the image CI builds from the pull request, or the code on the developer's computer).
- **sandbox:** what was created and what stays shared, the routing key, then the spec (cluster and suffix filled in,
  comments kept) and a short list of what its parts mean. Whenever the spec has `defaultRouteGroup`, explain it as
  where the sandbox link at the top comes from, then the `linkmap` line (the real preview link → "Signadot adds the
  routing key" → `target`) and the sentence saying both addresses are the same app: the link from any signed-in
  browser, `target` from inside the cluster or a connected laptop. Readers otherwise see two URLs and can't tell
  why. Then command blocks: the command that created it, and the file's "Try it yourself" commands (see the pods,
  see the sandbox and its key).
- **routing:** one sentence on the app's path, the diagram (see "The diagram"), its legend, a **Proof:** sentence
  from the trial log, and the screenshot if there is one.
- **works:** three numbered cards. *1, the key is set where the request starts:* how this scenario's requests got
  the key (the preview link, a job or plan runner, a producer), the other ways to send it (the Chrome extension, a
  header in any HTTP client), and for HotROD the curl commands in "Setting the key yourself". *2, each service passes
  it along:* how the key travels in this app (OpenTelemetry `baggage` over HTTP, message or workflow headers). *3,
  Signadot routes by it:* where the decision is made in this scenario (table below). Link each card to its docs page.
  End with the scenario's tutorial, from the file's Docs, linked as the HTML page (drop `.md`).

If the scenario failed, say plainly what was seen and what was tried in the headline and under the diagram, and draw
what you know.

### The diagram

The template's diagram is the finished one for isolated-change. Keep its layout for every scenario:

- the request sources on the left: the baseline link (no key) and the sandbox or route group link (adds the key);
  or the job or plan runner, or the producer;
- the app's real path in one row, left to right: for HotROD, frontend (location above it), Kafka, driver (Redis
  above it), route. The trial log's hops say which version served each service, but list them in the order the
  notifications arrived: don't draw that order;
- two lanes along the path: grey (`lane base`) for the request without the key, accent (`lane key`) for the one
  with it;
- for each service the sandbox changed, its copy below the normal box (`box sbx`, or `box local` for a process on
  the user's computer), inside a dashed `outline` labelled with the sandbox's name; the keyed lane drops to the copy
  and the grey lane goes on to the normal one;
- the place the decision is made, labelled for this scenario: the `router` node in front of the forked service
  (DevMesh's sidecar, Istio's sidecar, the ambient waypoint), or, for messages and workflows, nothing: both lanes go
  into the topic or queue and each consumer takes only its own;
- the results in the boxes where they appear (an ETA, a plate, a processed message), so the picture carries the
  result. Update the `aria-label` to describe the picture.

| Scenario | Copies below the row | Where the decision is made (card 3) |
|---|---|---|
| isolated-change | route | DevMesh's sidecar on the normal route pod forwards keyed calls to the copy |
| multi-service-preview | frontend and driver, one outline per sandbox, under the route group's name | the sidecar on the normal frontend pod; driver's copy takes only the Kafka messages that carry the key, and the normal driver skips them |
| local-development | route, as `box local`, "on your computer" | the sidecar on the normal route pod forwards keyed calls through Signadot's connection to the process on the user's computer |
| sandbox-database | location, with its own database (a `store` inside the outline) | the sidecar on the normal location pod; the resource plugin created the database with the sandbox and removes it with it |
| kafka | driver | no router: both messages go into the one topic; each driver reads the key on every message and processes only its own |
| temporal, rabbitmq, redis-streams | the worker or consumer | no router: each worker or consumer reads the key on every task, message or entry and handles only its own (from the file's "What Signadot does") |
| jobs | driver (the Job tests the driver sandbox) | the job runner sets the sandbox's key on the test traffic (card 1); then as in multi-service-preview |
| plans | the driver sandbox and broken-route, the broken one's result marked failed | the plan runner sets the key of the sandbox it's given (card 1); then the sidecars, as in isolated-change |
| istio, istio-ambient, linkerd | route | Istio: the caller's Envoy sidecar; ambient: the waypoint in front of route; Linkerd: Signadot's sidecar next to Linkerd's proxy (from the mesh file's "What it shows") |

For Temporal, RabbitMQ and Redis Streams, draw their own apps the same way, with their services from the file.

### Setting the key yourself

For HotROD scenarios, card 1 shows how to send the key with curl from the user's laptop. Signadot's local
connection makes every address inside the cluster reachable from the laptop, so the commands use the real
in-cluster address, the one in the spec's `target`:

1. Only when the trial's connection is `connect_mode: unprivileged` (the default), first: a command block marked
   **First, once:** that reconnects with sudo, `<trial folder>/bin/sd local disconnect && <trial folder>/bin/sd local connect`,
   saying it asks for their password and that they should tell the agent if it's still running scenarios. Then a
   check, `curl -sS -o /dev/null -w '%{http_code}\n' http://frontend.hotrod.svc:8080/`, which prints `200`, and
   "Could not resolve host" until the reconnect is done. Without the reconnect, cluster names don't resolve and the
   commands below print nothing useful. With `connect_mode: privileged`, leave both out: cluster addresses already
   work.
2. Book a ride with the key (prints `{}`):
   `curl -sS -X POST http://frontend.hotrod.svc:8080/dispatch -H 'baggage: sd-routing-key=<key>' -H 'Content-Type: application/json' -d '{"SessionID":4242,"RequestID":1,"PickupLocationID":1,"DropoffLocationID":123}'`
3. Read the ride's notifications a few seconds later (prints `Driver <plate> arriving in <ETA>`; run it again if
   it prints nothing): `curl -sS 'http://frontend.hotrod.svc:8080/notifications?sessionID=4242&cursor=0' | grep -o 'Driver [^"]*'`
   (escape `&` as `&amp;` in the page).

Use `curl -sS`, never `-s` alone: `-s` hides errors such as "Could not resolve host", and the user sees a blank
line instead. Say what each command prints.

Say what it prints with the key, and that the same request without the header (and another `SessionID`) reaches
the baseline. For multi-service-preview, use the route group's key; the changed frontend answers too.

**App links.** Preview links open the app in any browser signed in to the user's Signadot org; Signadot adds the
routing key of the sandbox or route group to every request made through them. Read a link with
`"$T/bin/sd" sandbox get <name> -o json | grep -oE '"url": *"https://[^"]+"' | head -1` (or `routegroup get`), and
record both in the scenario's entry as `link-baseline:` and `link-sandbox:`.

| Scenario | Baseline link | Sandbox link | What to look for |
|---|---|---|---|
| isolated-change | `baseline_url` (route group `hotrod-baseline<suffix>`) | sandbox `fast-route<suffix>` | ETAs in minutes on the baseline, 1s through the sandbox |
| multi-service-preview | `baseline_url` | route group `hotrod-plates<suffix>` | `SD-` plates, highlighted |
| local-development | `baseline_url` | sandbox `local-route<suffix>` (works while the route process runs on this computer) | ETAs in seconds |
| sandbox-database | `baseline_url` | sandbox `location-db<suffix>` | different pickup and drop-off locations |
| kafka, jobs | `baseline_url` | sandbox `driver-plates<suffix>` | plates start with `SD-` only through the sandbox |
| plans | `baseline_url` | sandboxes `driver-plates<suffix>` and `broken-route<suffix>` | rides through the broken one don't complete: the regression the plan caught |
| istio, istio-ambient, linkerd | `baseline_url` | sandbox `fast-route<suffix>` | as isolated-change, on the mesh |
| temporal | route group `temporal-baseline<suffix>` | sandbox `temporal-worker<suffix>` | start a transfer from each; the worker logs show which worker ran it |
| redis-streams | route group `redis-streams-baseline<suffix>` | sandbox `redis-streams-consumer<suffix>` | the message trail: only the sandbox's are processed by processor v2, in upper case |
| rabbitmq | — | — | no web page: leave out the box |

## The overview page

Keep it short, so the trial reads as simple: the links, the list of scenarios, and how to look at the cluster. The
detail is on the scenario pages; teardown and next steps are for the agent to offer in chat, not for this page.

- **title:** e.g. "Your Signadot trial: 3 scenarios proven, 1 to go", or "…: 3 of 3 scenarios proven" when nothing
  is to go.
- **summary:** pills with counts (passed, failed, to go), then org, cluster and date.
- **urls:** the baseline link, then each scenario's sandbox link with what to look for (see "App links").
- **scenarios:** one `ROW` per scenario that ran or is to go, in run order, linking its page, with a one-sentence
  result and its time; one that hasn't run yet gets the `next` pill and no link. Then the `MORE` line while
  something on the menu of more scenarios hasn't been tried.
- **Look at the cluster yourself** (a fixed section): replace `TRIAL_FOLDER` with the trial folder's full path. It
  tells the user why `kubectx` doesn't show the trial's cluster and how to see it.

## Screenshots

Take them only if you can drive a browser. Open the scenario's sandbox link (see "App links") in the browser session
from signup, book a ride, and save `$T/report/screens/<scenario id>.png`. Link screenshots relatively
(`screens/isolated-change.png`). Without a browser, leave out the `<figure>`: the diagram and the proof carry the
page.

Good screenshots: isolated-change, the ride with an ETA of 1s; multi-service-preview, the preview page with the
highlighted plate; local-development, the ride with an ETA in seconds.
