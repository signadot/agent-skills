# Report

The report is built from the trial log (`references/trial-log.md`): its Run facts, Steps, Resources and one Scenario
entry per scenario.

## The report

1. `mkdir -p $T/report/screens` and copy `assets/report-template.html` to `$T/report/index.html`.
2. Replace each `FILL:<name>` comment with real content in the shape its example shows:
   - **title:** e.g. "Signadot trial: 3 of 3 scenarios proven in 14 minutes".
   - **summary:** pills with counts (passed, failed, not run), then org, cluster, infrastructure, date and total
     minutes.
   - **cards:** copy the `CARD` block once per scenario that ran, in run order. Fill the problem, what Signadot did,
     one flow row for the baseline and one for the sandbox (from the scenario's hops), both results, the proof, the
     screenshot if there is one, why it matters, the docs link and the commands. Then copy the `NOT-RUN` block once
     per menu item the user didn't pick.
   - **timeline:** the `## Steps` table, what the user did, and any fallbacks.
   - **running:** everything in `## Resources` that still exists, the preview URL, and the connection. Say that
     nothing expires on its own.
   - **next steps:** the agent skills for their own services (`npx skills add signadot/agent-skills --skill
     signadot-validate`, and `--skill signadot-plan` for Plans); the Signadot MCP server (`<T>/bin/sd mcp` with the
     trial's login and org, or `signadot mcp` once their own CLI is logged in); installing the operator on their own cluster
     (https://www.signadot.com/docs/installation/signadot-operator); add-ons they didn't try.
   - **teardown:** what teardown will remove, and the manual steps (from `references/finish/teardown.md`).
   - **run details:** the `## Run` facts, except secrets.
3. Escape `<`, `>` and `&` in anything copied from command output.
4. Delete the `CARD` and `NOT-RUN` template blocks once you've copied them. Every `FILL:` comment should be gone.
5. Open it with `open $T/report/index.html` (macOS) or `xdg-open` (Linux), or give the user the path.

## Screenshots

Take them only if you can drive a browser. Preview URLs (multi-service-preview) need nothing else. For a sandbox, start a local proxy
that adds the sandbox's routing key to every request, and open the plain localhost URL it serves:

```bash
nohup "$T/bin/sd" local proxy --sandbox <sandbox> --map http://frontend.hotrod.svc:8080@localhost:18080 \
  > "$T/logs/local-proxy.log" 2>&1 & echo $! > "$T/local-proxy.pid"
```

Then open `http://localhost:18080`, book a ride, and save `$T/report/screens/<scenario id>.png`. Stop the proxy before
starting one for another sandbox (`references/finish/playground.md` has the stop command). Link screenshots
relatively (`screens/isolated-change.png`). Without a browser, leave out the `<figure>`: the flow diagram and the proof carry the
card.

Good screenshots: isolated-change, the ride notifications with the `SD-` plate; multi-service-preview, the preview
URL with the highlighted plate; local-development, the ride with an ETA in seconds.
