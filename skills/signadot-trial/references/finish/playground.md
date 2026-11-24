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

## 3. Summary, fit and questions

Before the closing message:

1. **All at once** (`pace: all`): the summary from SKILL.md, "After each scenario": one line per scenario with what
   it proved and its preview link. Then the menu items they didn't pick, as a list, in case they want more.
2. **The fit page:** if they answered the stack questions (`answers-*` lines under Run), write and open it
   (`references/finish/fit.md`), and give its three-line summary in chat. If they didn't, offer once: "Want a page on
   whether Signadot fits your stack? Five quick questions." On a yes, ask them (`references/setup/customize.md` §2),
   then write it. On a no, the overview keeps the fit checklist.
3. Ask: "Is there anything else you'd like to know about Signadot? For example how it would work on your stack, what
   it costs, or how it compares with other tools." Answer each question as `references/finish/questions.md` says:
   from the current docs, pricing and comparison pages, with citations. When they have no more, send the closing
   message.

## 4. The closing message

Open the overview page (`open`, `xdg-open`, or `explorer.exe "$(wslpath -w <page>)"` on WSL), then send a short
message: the report, one next step on their own service, and teardown. No scenario summaries and no lists of things
to try, since the pages have them.

```markdown
**Your Signadot trial is done:** 4 of 4 scenarios passed. The report is open in your browser, with a page for each
scenario: `/Users/me/project/.signadot-trial/report/index.html`

**Next: try it on one of your own services.** Install Signadot's operator on a dev cluster
(https://www.signadot.com/docs/installation/signadot-operator), then add the `signadot-validate` skill to your agent
(`npx skills add signadot/agent-skills --skill signadot-validate`) and ask it to validate a change to one service:
the same change, run and prove loop you saw with route. Your platform team provides the cluster and the operator;
each service passes the routing key along, which OpenTelemetry already does.

Everything here stays running so you can explore. When you're done, ask me to tear down the Signadot trial.
```

Keep the "Next" paragraph as it is; if they answered the stack questions, add one clause from the fit page's
biggest piece of work ("for you, mostly adding OpenTelemetry to the services that don't have it yet").

If the user stopped early, say how many of the chosen scenarios ran and that "continue the trial" runs the rest.
Then stop. Run `references/finish/teardown.md` only when the user asks.
