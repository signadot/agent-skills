# Reports

The trial writes one page per scenario and an overview page that links them, all in `$T/report/`, built from the
trial log (`references/trial-log.md`). Write each scenario's page as soon as it's proven, so the user gets it while
the next scenario runs. The scenario pages are the main thing the user takes away from the trial.

## Before the first page

```bash
mkdir -p "$T/report/screens" && cp "$S/assets/report/report.css" "$T/report/"
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

Write for someone who is new to Signadot and didn't watch the run: what was tested, how Signadot handled it, the
proof, and why it matters to a team like theirs. Plain words; define a Signadot term the first time it appears; no
file names, step IDs or placeholders. Use the scenario file's "What it shows" for the story and its trial-log entry
for every value.

- **title:** the scenario's menu name.
- **status:** the pill (`passed` or `failed`), "Scenario n of N" (in run order, of the scenarios chosen), the time
  from the scenario's first command to its proof, the cluster and the date.
- **headline:** one or two sentences that say what was proven, with the proving values.
- **tested:** three boxes. *The situation:* the file's Problem, told as a team's day-to-day problem. *What we
  changed:* the concrete change and the service it's in (from the file's Run and spec). *What we sent:* the requests
  or messages, without and with the routing key.
- **app:** for HotROD scenarios, the diagram, with `class="box changed"` on each service the scenario changed (the
  local-development scenario's route runs on the user's computer; say so in the paragraph). For other demo apps
  (Temporal, RabbitMQ, Redis Streams), one paragraph on what the app does and how its parts connect.
- **how:** the file's "What Signadot does", in two to four plain sentences: what the sandbox (or route group, plugin,
  job or plan) contains, what stays shared, and how the routing key travels. Then one flow row without the key and
  one with it, from the hops (`hop sbx` for a sandbox, `hop sbx local` for a process on the user's computer, `hop
  msg` for a topic or queue), and the legend.
- **result:** both results with the real values in `big`, the proof sentence, and the screenshot if there is one.
- **value:** three numbers measured in this run (for example time to ready, what was added, what else was affected;
  for messages, how many each consumer handled). Then the "usual way vs with Signadot" table, four rows, from the
  file's Problem and this run's numbers; don't invent figures for the usual way. End with the file's "Why it
  matters".
- **adopt:** what it would take on the user's own services (table below), with links. End with the file's Docs page,
  linked as the HTML page (drop `.md`).
- **try:** the file's "Try it yourself", with real values and the full trial folder path.
- **details:** what this scenario created and whether it's still running, the spec with the cluster and suffix
  filled in, and the commands.

If the scenario failed, say plainly what was seen and what was tried in the headline and result, keep the flow rows
you have, and still explain the value it would have shown.

**What it would take on their services**, by scenario:

| Scenario | What it would take | Link |
|---|---|---|
| isolated-change | Services propagate the routing key (OpenTelemetry baggage); Signadot routing runs in the cluster (its sidecar or their mesh); CI creates a sandbox per pull request from the image it builds | https://www.signadot.com/docs/guides/set-up-context-propagation, https://www.signadot.com/docs/guides/request-routing |
| multi-service-preview | The same, plus a route group that joins the sandboxes of one feature by label; the preview link goes on the pull requests | https://www.signadot.com/docs/tutorials/multi-pr-feature-testing |
| local-development | The Signadot CLI on each developer's computer, `signadot local connect`, and a sandbox that points a service at their machine | https://www.signadot.com/docs/tutorials/quickstart/local-development |
| sandbox-database | A resource plugin that creates and seeds a database (or schema) per sandbox and removes it afterwards | https://www.signadot.com/docs/guides/set-up-data-isolation |
| kafka, rabbitmq, redis-streams, temporal | Producers carry the routing key into message headers (OpenTelemetry does this); each consumer handles only messages for its own routing key and skips the rest | https://www.signadot.com/docs/guides/set-up-message-queue-isolation |
| jobs | A job runner group in the cluster, and the team's existing test suite run as a Job against each pull request's sandbox from CI | https://www.signadot.com/docs/tutorials/quickstart/jobs |
| plans | Tagged Plans that CI or a coding agent runs against any sandbox; the `signadot-plan` skill authors them | https://www.signadot.com/docs/tutorials/quickstart/plan-based-validation |

## The overview page

- **title:** e.g. "Your Signadot trial: 3 scenarios proven, 1 to go", or "…: 4 of 4 scenarios proven" at the end.
- **summary:** pills with counts (passed, failed, to go), then org, cluster and date.
- **scenarios:** one `ROW` per chosen scenario in run order, linking its page, with a one-sentence result and its
  time; a scenario that hasn't run yet gets the `next` pill and no link. Then one `NOT-PICKED` row per menu item the
  user didn't choose.
- **running:** everything in `## Resources` that still exists, the preview link, and the connection. Say that
  nothing expires on its own. At the hand-off, add what `references/finish/playground.md` §2 lists.
- **Look at the cluster yourself** (a fixed section): replace `TRIAL_FOLDER` with the trial folder's full path. It
  tells the user why `kubectx` doesn't show the trial's cluster and how to see it.
- **next steps:** the agent skills for their own services (`npx skills add signadot/agent-skills --skill
  signadot-validate`, and `--skill signadot-plan` for Plans); the Signadot MCP server (`<T>/bin/sd mcp` with the
  trial's login and org, or `signadot mcp` once their own CLI is logged in); installing the operator on their own
  cluster (https://www.signadot.com/docs/installation/signadot-operator); add-ons they didn't try.
- **teardown:** what teardown will remove, and the manual steps (from `references/finish/teardown.md`).
- **timeline** and **run details:** the `## Steps` (by their "Tell the user" names), what the user did, any
  fallbacks, and the `## Run` facts, except secrets.

## Screenshots

Take them only if you can drive a browser. Preview links (multi-service-preview) need nothing else. For a sandbox,
start a local proxy that adds the sandbox's routing key to every request, and open the plain localhost URL it serves:

```bash
nohup "$T/bin/sd" local proxy --sandbox <sandbox> --map http://frontend.hotrod.svc:8080@localhost:18080 \
  > "$T/logs/local-proxy.log" 2>&1 & echo $! > "$T/local-proxy.pid"
```

Then open `http://localhost:18080`, book a ride, and save `$T/report/screens/<scenario id>.png`. Stop the proxy before
starting one for another sandbox (`references/finish/playground.md` has the stop command). Link screenshots
relatively (`screens/isolated-change.png`). Without a browser, leave out the `<figure>`: the flow rows and the proof
carry the page.

Good screenshots: isolated-change, the ride notifications with the `SD-` plate; multi-service-preview, the preview
page with the highlighted plate; local-development, the ride with an ETA in seconds.
