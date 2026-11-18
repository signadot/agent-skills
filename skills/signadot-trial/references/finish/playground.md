# Hand-off: let the user try it

When the user is done, nothing is removed. Sandboxes carry no expiry, so everything stays as it is until the user
asks for teardown. The report pages carry what was shown and how to try it; the chat message only points to them.

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
| local-development's route process and Redis port-forward | Usually; they're background processes this session started | the start commands in `references/core/local-development.md` "Run" |

If the proxy address changed after a reconnect, read it again with the command in `references/setup/cluster.md` §4
(the `portforward` section's `localAddress`).

## 2. Update the overview page

Rebuild `$T/report/index.html` one last time (`references/finish/report.md`, "The overview page"), so its links and
scenario list are current. Keep it to what that section lists: no next steps, setup details or teardown.

Don't change the user's PATH or shell profile, and don't suggest putting `<T>/bin` on PATH: its `sd` wrapper would
shadow the `sd` find-and-replace tool some people use.

## 3. The closing message

Open the overview page (`open`, `xdg-open`, or `explorer.exe "$(wslpath -w <page>)"` on WSL), then send a short message: no scenario summaries and no lists of
things to try, since the pages have them.

```markdown
**Your Signadot trial is done:** 4 of 4 scenarios passed. The report is open in your browser, with a page for each
scenario: `/Users/me/project/.signadot-trial/report/index.html`

Everything stays running so you can explore. When you're done, ask me to tear down the Signadot trial.
```

If the user stopped early, say how many of the chosen scenarios ran and that "continue the trial" runs the rest.
Then stop. Run `references/finish/teardown.md` only when the user asks.
