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
5. **Make its cluster links work.** When the page's steps open a cluster address (one ending in `.svc`: the
   Temporal UI and transfer app, the Redis Streams producer, RabbitMQ's management UI) and the trial's connection is
   `connect_mode: unprivileged`, that link won't open in the user's browser yet: cluster names resolve on the laptop
   only with the sudo connection. Don't leave it to the page: in the result message, before the question about the
   next scenario, add a step for the user: "To open <the link> in your browser, run this once in your own terminal
   (it asks for your sudo password), then tell me:" with the reconnect command,
   `<trial folder>/bin/sd local disconnect && <trial folder>/bin/sd local connect`. When they reply, check the link
   with `curl -sS -o /dev/null -w '%{http_code}\n' <link>`:
   - an HTTP status (`200`, or `302` for a redirect): it opens now. Tell the user, record `connect_mode: privileged`
     and drop `--proxy` from then on (`references/setup/cluster.md` §4).
   - `000` and "Could not resolve host": the reconnect didn't take. `"$T/bin/sd" local status` says `running with
     root-daemon` once it has. Ask the user to run the command again and paste what it printed.

   If the user would rather not use sudo, say the link stays closed and carry on; the rest of the page still
   applies.

In every page, escape `<`, `>` and `&` in anything copied from command output, and leave no `FILL:` comment or
template block behind.

## Writing a scenario page

Write for someone who is new to Signadot and didn't watch the run. Be brief: a sentence or two, then the picture,
the facts or the commands. The page explains how it works, not why to buy it: no sales lines, no "usual way vs
Signadot" comparisons. Plain words; define a Signadot term the first time it appears; no file names, step IDs or
placeholders. Take the content from the scenario file's "What it shows" and "Try it yourself", and every value from
its trial-log entry.

**Every page has the same four sections, in this order,** whatever the scenario. Don't add, drop or reorder them:

1. **The demo app:** what it does, a diagram of its parts and how a request flows through them, and which part
   this scenario changes.
2. **The change:** the code or configuration change, in which service.
3. **The sandbox:** how the change is deployed as a sandbox: what it runs, what stays shared, its routing key and
   preview link, and anything created with it (a database from a resource plugin, a queue, a route group).
4. **Test it yourself:** the routing diagram (requests with and without the key), how the key is set, passed along
   and routed, then numbered steps the user runs: the baseline flow, the sandbox flow, and how to check which
   version handled each one (logs, the app's page, a UI such as the Temporal UI or RabbitMQ's management UI).

**Commands on the pages.** Each command the user might run goes in its own `<div class="cmd">` block (a one-line
explanation, then `<pre><code>`), so it gets a Copy button; specs go in one too. Make it paste-ready: full paths,
the real sandbox names, pod and deployment names, suffix and routing key, no `$T`, `<…>` or other placeholders.
Say what it prints. Use `kubectl --kubeconfig <trial folder>/kubeconfig …` and `<trial folder>/bin/sd …`. Never
show `ride.sh`, `--proxy` or the trial's local proxy: the preview links, and the sudo connection for cluster
addresses, replace them. Link docs pages as HTML (drop `.md`).

### The slots

- **title:** the scenario's menu name.
- **status:** the pill (`passed` or `failed`), "Scenario n" (its place in run order), the time from the scenario's
  first command to its proof, the cluster and the date.
- **headline:** one or two sentences that say what was proven, with the proving values.
- **app:** one or two sentences on what the app does, its diagram, and a numbered list of the steps a request
  takes, matching the diagram's numbers. For HotROD, the template's example as it is, with the scenario's changed
  services drawn as `box changed` and tagged "changed in this scenario" (several: tag each). For another demo app
  (Temporal, RabbitMQ, Redis Streams), draw its parts in the same style from the scenario file's "The demo app":
  services as `box`, queues, topics and streams as `bus`, databases as `store`, numbered `circle.n` steps on the
  arrows, and the UI that shows the scenario best as a box too. Keep every label inside the picture (end-anchor a
  tag near the right edge).
- **change:** two or three sentences: what changed, in which service, and what the developer wants to check. Show
  the change itself when it's small (a code line, a setting, a patch), and say in one muted line how it maps to real
  use (the image CI builds from the pull request, or the code on the developer's computer).
- **sandbox:** one sentence on how it was deployed, then the `facts` list: **Runs** (the copies and their pods),
  **Shared** (everything else), **Routing key**, **Preview link** (or "none" when the spec has no endpoint), and
  **Also created** (the database from the resource plugin, the consumer's own queue or consumer group, the route
  group, the local process; "nothing else" when there is none). Then the spec (cluster and suffix filled in,
  comments kept), a short list of what its parts mean, and, when the spec has `defaultRouteGroup`, the `linkmap`
  line (the real preview link → "Signadot adds the routing key" → `target`). Then command blocks: the command that
  created it, see its pods, see the sandbox and its key. End with the docs link for what it uses (the sandbox spec,
  resource plugins, route groups, local sandboxes).
- **routing:** one sentence, the diagram (see "The diagram") and its legend; then the `how` strip, three short
  cards: *1, set where the request starts* (how this scenario's requests got the key: the preview link, a job or
  plan runner, a header; and the Chrome extension or any HTTP client), *2, passed along* (how the key travels in
  this app: OpenTelemetry `baggage` over HTTP, message, entry or workflow headers), *3, routed* (where the decision
  is made: the table below), each linked to its docs page; then **What the trial saw:** one sentence from the trial
  log, and the screenshot if there is one.
- **tryit:** the numbered steps from the scenario file's "Try it yourself", always in this order: first, only when a
  step uses a cluster address and the connection is `connect_mode: unprivileged`, **Before you start**: the
  reconnect and its check (see "Try it"); then the baseline flow; the sandbox flow; checking which version handled
  each; then the optional extras. A live view the user should watch while running the flows (RabbitMQ's consumer
  logs) goes before the flows. Jobs and Plans test with runs instead of links: their flows are runs against
  different sandboxes. Each step: a short title (`<h4>`), the link or the command blocks, and what the
  user sees. End with the docs links: the scenario's tutorial, from the file's Docs, and any page a step relies on.

If the scenario failed, say plainly what was seen and what was tried in the headline and under the diagram, and draw
what you know.

### The diagram

The template's diagram is the finished one for isolated-change. Keep its layout for every scenario:

- the request sources on the left: the baseline link (no key) and the sandbox or route group link (adds the key);
  or the job or plan runner, or the producer;
- the app's real path in one row, left to right: for HotROD, frontend (location above it), Kafka, driver (Redis
  above it), route. The trial log's hops say which version served each service, but list them in the order the
  notifications arrived: don't draw that order;
- two lanes along the path: grey (`lane base`) for the request without the sandbox's key (a baseline link's key
  belongs to no sandbox), accent (`lane key`) for the one with it;
- for each service the sandbox changed, its copy below the normal box (`box sbx`, or `box local` for a process on
  the user's computer), inside a dashed `outline` labelled with the sandbox's name; the keyed lane drops to the copy
  and the grey lane goes on to the normal one;
- the place the routing decision is made, drawn where it really happens
  ([request routing](https://www.signadot.com/docs/guides/request-routing.md)). Both lanes reach it together, and it
  is where they split:
  - **DevMesh and Linkerd, destination side** (the template): Signadot's sidecar inside the pod of the normal version
    of the service being called. Draw that pod as a `pod` rectangle around a `router` ("sidecar") and the normal
    box; the grey lane goes on to the normal box beside it and the accent lane leaves the pod for the copy. On
    Linkerd, title the pod "pod of the normal route, with Linkerd's proxy".
  - **Istio sidecar mode, source side:** the caller's Envoy sidecar decides, so the `router` ("Envoy") goes inside
    the caller's `pod` instead, and the normal route is a plain box. For route, replace the template's driver, its
    line to Redis, the route pod (rectangle, title, sidecar and route box) and the lanes from driver on with:

    ```html
    <rect class="pod" x="480" y="120" width="200" height="80" rx="10"/><text class="sub" x="672" y="112" text-anchor="end">pod of driver, the caller</text>
    <rect class="box" x="490" y="133" width="90" height="54" rx="8"/><text x="535" y="156" text-anchor="middle">driver</text><text class="sub" x="535" y="173" text-anchor="middle">shared</text>
    <rect class="router" x="596" y="146" width="74" height="28" rx="14"/><text class="small" x="633" y="164" text-anchor="middle">Envoy</text><text class="sub" x="633" y="191" text-anchor="middle">reads the key</text>
    <rect class="box" x="736" y="133" width="120" height="54" rx="8"/><text x="796" y="156" text-anchor="middle">route</text><text class="sub" x="796" y="173" text-anchor="middle">normal · ETA 23m14s</text>
    <path class="line" d="M535,133 V60" marker-end="url(#a-line)"/>
    <path class="lane base" d="M580,153 H592" marker-end="url(#a-base)"/>
    <path class="lane base" d="M670,153 H732" marker-end="url(#a-base)"/>
    <path class="lane key" d="M580,167 H592" marker-end="url(#a-key)"/>
    <path class="lane key" d="M670,167 C704,167 700,244 732,244" marker-end="url(#a-key)"/>
    ```
  - **Istio ambient, waypoint:** pods have no sidecar; a waypoint proxy in front of the called service decides. Draw
    the template without the `pod` rectangle and its title, and label the `router` "waypoint".
  - **Messages and workflows:** nothing to draw: both lanes go into the topic or queue, and each consumer or worker
    takes only its own;
- the results in the boxes where they appear (an ETA, a plate, a processed message), so the picture carries the
  result. Update the `aria-label` to describe the picture.

| Scenario | Copies below the row | Where the decision is made (the `how` strip's third card) |
|---|---|---|
| isolated-change | route | the sidecar in the normal route's pod forwards calls with the key to the copy |
| multi-service-preview | frontend and driver, one outline per sandbox, under the route group's name | the sidecar in the normal frontend's pod (the link's requests arrive there); driver's copy takes only the Kafka messages that carry the key, and the normal driver skips them |
| local-development | route, as `box local`, "on your computer" | the sidecar in the normal route's pod forwards calls with the key through Signadot's connection to the process on the user's computer |
| sandbox-database | location, with its own database (a `store` inside the outline) | the sidecar in the normal location's pod; the resource plugin created the database with the sandbox and removes it with it |
| kafka | driver | no router: both messages go into the one topic; each driver reads the key on every message and processes only its own |
| temporal, rabbitmq, redis-streams | the worker or consumer | no router: each worker or consumer reads the key on every task, message or entry and handles only its own (from the file's "What Signadot does") |
| jobs | driver (the Job tests the driver sandbox) | the job runner sets the sandbox's key on the test traffic (first card); then as in multi-service-preview |
| plans | the driver sandbox and broken-route, the broken one's result marked failed | the plan runner sets the key of the sandbox it's given (first card); then the sidecars, as in isolated-change |
| istio, istio-ambient, linkerd | route | Istio: the Envoy sidecar in driver's pod, the caller (source side); ambient: the waypoint in front of route; Linkerd: Signadot's sidecar in the normal route's pod, next to Linkerd's proxy (destination side) |

For Temporal, RabbitMQ and Redis Streams, draw their own apps the same way, with their services from the file.

### Try it

The steps come from the scenario file's "Try it yourself", which lists them as **Baseline**, **Sandbox**, **Check**
and **More**. Write each as one step of the `try` list, with this run's links, names and key.

**Before you start.** Signadot's local connection makes every cluster address (one ending in `.svc`) work on the
user's laptop, in a terminal and in a browser, but only with sudo. When a step uses a cluster address and the
trial's connection is `connect_mode: unprivileged` (the default), the list starts with this step: a command block
that reconnects with sudo, `<trial folder>/bin/sd local disconnect && <trial folder>/bin/sd local connect`, saying
it asks for their password and to tell the agent if it's still running scenarios; then a check,
`curl -sS -o /dev/null -w '%{http_code}\n' <the step's cluster address>`, which prints `200` once it works and
"Could not resolve host" until then. When only an optional step needs it (the HotROD curl below), put both inside
that step instead, as the template does. With `connect_mode: privileged`, leave them out.

**Checking which version handled a request.** Name the real pods: the sandbox's deployment is
`<sandbox name>-dep-<workload>-<hash>`; read it with
`"$T/bin/kc" -n <namespace> get deploy -o name | grep <sandbox name>`. Give the normal one and the sandbox's in two
blocks, with `logs -f … | grep --line-buffered '<line>'`, and say which requests appear in which. HotROD's
containers are named `hotrod`, and each service logs one line per request: route `Finding route`, location
`Loading location`, driver `Dispatch successful`, frontend `Dispatching driver`.

**Sending the key yourself (HotROD).** An optional last step: curl to the frontend's cluster address with the
key, as in the template:

1. Request a ride with the key (prints `{}`):
   `curl -sS -X POST http://frontend.hotrod.svc:8080/dispatch -H 'baggage: sd-routing-key=<key>' -H 'Content-Type: application/json' -d '{"SessionID":4242,"RequestID":1,"PickupLocationID":1,"DropoffLocationID":123}'`
2. Read the ride's messages a few seconds later (prints `Driver <plate> arriving in <ETA>`; run it again if it
   prints nothing): `curl -sS 'http://frontend.hotrod.svc:8080/notifications?sessionID=4242&cursor=0' | grep -o 'Driver [^"]*'`
   (escape `&` as `&amp;` in the page).

Say what it prints with the key, and that the same request without the header (and another `SessionID`) reaches
the baseline. For multi-service-preview, use the route group's key.

Use `curl -sS`, never `-s` alone: `-s` hides errors such as "Could not resolve host", and the user sees a blank
line instead.

**App links.** Preview links open the app in any browser signed in to the user's Signadot org; Signadot adds the
routing key of the sandbox or route group to every request made through them. That includes a baseline link: it
adds the key of a route group with no sandbox in it, so no sandbox claims those requests. Say so ("the routing key
this link adds belongs to no sandbox"); never write that the baseline link adds no key. When the app shows the key
it received, use the app's cluster address for the baseline instead, which adds none (Temporal, Redis Streams).
Read a link with `"$T/bin/sd" sandbox get <name> -o json | grep -oE '"url": *"https://[^"]+"' | head -1` (or
`routegroup get`), and record both in the scenario's entry as `link-baseline:` and `link-sandbox:`.

| Scenario | Baseline link | Sandbox link | What to look for |
|---|---|---|---|
| isolated-change | `baseline_url` (route group `hotrod-baseline<suffix>`) | sandbox `fast-route<suffix>` | ETAs in minutes on the baseline, 1s through the sandbox |
| multi-service-preview | `baseline_url` | route group `hotrod-plates<suffix>` | `SD-` plates, highlighted |
| local-development | `baseline_url` | sandbox `local-route<suffix>` (works while the route process runs on this computer) | ETAs in seconds |
| sandbox-database | `baseline_url` | sandbox `location-db<suffix>` | different pickup and drop-off locations |
| kafka, jobs | `baseline_url` | sandbox `driver-plates<suffix>` | plates start with `SD-` only through the sandbox |
| plans | `baseline_url` | sandboxes `driver-plates<suffix>` and `broken-route<suffix>` | rides through the broken one don't complete: the regression the plan caught |
| istio, istio-ambient, linkerd | `baseline_url` | sandbox `fast-route<suffix>` | as isolated-change, on the mesh |
| temporal | the transfer app's cluster address, `http://temporal-py-client-ui.temporal.svc:8080` (no key; needs the connection) | sandbox `temporal-worker<suffix>`; plus the Temporal UI, `http://temporal-ui-service.temporal.svc` (needs the connection) | the transfer page shows "Routing Key: undefined" on the baseline and the sandbox's key through its link; in the Temporal UI, each transfer's completed steps list the worker that ran them (Identity): `1@temporal-worker-…` or the sandbox's `1@temporal-worker<suffix>-dep-temporal-worker-…`; a "Workflow Task Failed … cannot handle routing key" event is the other worker handing a step back (say so on the page) |
| redis-streams | the producer's cluster address, `http://producer.redis-streams-demo.svc:4000` (no key; needs the connection) | sandbox `redis-streams-consumer<suffix>` | each message's trail: `routingKey: ""` and `consumer (baseline)` with processor v1 on the baseline; the sandbox's key and `consumer (sandbox=…)` with processor v2, in upper case, through its link |
| rabbitmq | — (the app has no page of its own) | RabbitMQ's management UI, `http://rabbitmq.rabbitmq-demo.svc:15672`, user `guest` / `guest` (the demo's default; needs the connection) | Queues: `consumer-baseline` and `consumer-trial<suffix>`, both bound with `#` to the `orders_exchange` exchange; every order reaches both, and each consumer processes only its own (the logs show PROCESSING, and SKIP or `process=False` for the rest) |

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
