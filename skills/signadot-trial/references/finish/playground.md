# Hand-off: let the user try it

When every chosen scenario has run, or the user says to stop, nothing is removed. Sandboxes carry no expiry, so
everything stays as it is until the user asks for teardown. The report pages carry what's running, how to use it and
what to do next; the chat message only points to them.

## 1. Check what's running

Build the list from the trial log's `## Resources` and check each item is still up:

```bash
"$T/bin/sd" sandbox list
"$T/bin/sd" routegroup list
"$T/bin/sd" local status
"$T/bin/kc" get namespaces
lsof -nP -iTCP:8083 -sTCP:LISTEN          # the route service on this computer, if local-development ran
```

What keeps running, and what doesn't:

| Item | Survives the end of this agent session? | If it stopped |
|---|---|---|
| kind cluster, HotROD, demo apps, operator | Yes, while Docker runs | Start Docker again; the cluster comes back |
| Sandboxes, route group, plugin, runner group, plan tag | Yes (stored in Signadot) | — |
| Local connection | Yes (a background daemon), until reboot | `<T>/bin/sd local connect --unprivileged` |
| local-development's route process, Redis port-forward, a local proxy | Usually; they're background processes this session started | the start commands in `references/core/local-development.md` "Run", or below |

If the proxy address changed after a reconnect, read it again with the command in `references/setup/cluster.md` §4
(the `portforward` section's `localAddress`).

## 2. Put it in the overview page

Rebuild `$T/report/index.html` one last time (`references/finish/report.md`, "The overview page"), with real values
and full paths:

- **What's running now:** each item above that's still up, with how to restart it if it stops. Include:
  - **See a sandbox in any browser:** a local proxy serves the frontend on a plain localhost URL and adds the
    sandbox's routing key to every request, so no header extension or proxy setting is needed. Start and stop
    commands (one proxy at a time on this port):

    ```bash
    nohup "$T/bin/sd" local proxy --sandbox driver-plates<suffix> --map http://frontend.hotrod.svc:8080@localhost:18080 \
      > "$T/logs/local-proxy.log" 2>&1 & echo $! > "$T/local-proxy.pid"
    p=$(cat "$T/local-proxy.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF 'local proxy' && kill "$p"
    ```

    Then http://localhost:18080 books rides on the sandbox (plates start with `SD-`). Use `--sandbox
    local-route<suffix>` for the service on this computer (ETAs in seconds) or `--routegroup hotrod-plates<suffix>`
    for the two-service change. If you start one yourself, record `process <pid> local proxy` under Resources.
  - **The preview link** (multi-service-preview): opens in a browser signed in to the org, with no setup.
  - **Any request through the connection:**
    `curl --proxy socks5h://<address> -H "baggage: sd-routing-key=<key>" http://frontend.hotrod.svc:8080/`.
  - **The dashboard:** https://app.signadot.com, with the sandboxes, route group and any jobs or plans.
- **Look at the cluster yourself:** the template's section, with the trial folder's path (the user won't find the
  cluster with `kubectx` otherwise, since its credentials are in `$T/kubeconfig`).
- **Next steps:** the agent skills that run this loop on their own services (`npx skills add signadot/agent-skills
  --skill signadot-validate`, and `--skill signadot-plan` for Plans;
  https://www.signadot.com/docs/integrations/coding-agents/agent-skills); the Signadot MCP server (`<T>/bin/sd mcp`
  uses the trial's login and org while the trial folder exists; `signadot mcp` once their own CLI is logged in;
  https://www.signadot.com/docs/integrations/mcp); their own CLI (install it from
  https://www.signadot.com/docs/getting-started/installation/signadot-cli, then `signadot auth login`; the trial's
  login stays inside the trial folder); the operator on their own cluster
  (https://www.signadot.com/docs/installation/signadot-operator); add-ons they didn't try.
- **Teardown:** what it removes and what's left for them (`references/finish/teardown.md`).

Don't change the user's PATH or shell profile, and don't suggest putting `<T>/bin` on PATH: its `sd` wrapper would
shadow the `sd` find-and-replace tool some people use.

## 3. The closing message

Open the overview page (`open` or `xdg-open`), then send a short message: no scenario summaries and no lists of
things to try, since the pages have them.

```markdown
**Your Signadot trial is done:** 4 of 4 scenarios passed. The report is open in your browser, with a page for each
scenario: `/Users/me/project/.signadot-trial/report/index.html`

Everything stays running so you can explore. When you're done, ask me to tear down the Signadot trial.
```

If the user stopped early, say how many of the chosen scenarios ran and that "continue the trial" runs the rest.
Then stop. Run `references/finish/teardown.md` only when the user asks.
