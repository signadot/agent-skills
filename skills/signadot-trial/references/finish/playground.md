# Hand-off: let the user try it

Right after the report, nothing is removed. Sandboxes carry no expiry, so everything stays as it is until the user
asks for teardown. Tell the user what's running, how to reach it, and what to try, in one message.

## 1. List what's running

Build the list from the trial log's `## Resources` and check each item is still up:

```bash
"$T/bin/sd" sandbox list
"$T/bin/sd" routegroup list
"$T/bin/sd" local status
"$T/bin/kc" get namespaces
lsof -nP -iTCP:8083 -sTCP:LISTEN          # C3's route service on this computer, if C3 ran
```

What keeps running, and what doesn't:

| Item | Survives the end of this agent session? | If it stopped |
|---|---|---|
| kind cluster, HotROD, demo apps, operator | Yes, while Docker runs | Start Docker again; the cluster comes back |
| Sandboxes, route group, plugin, runner group, plan tag | Yes (stored in Signadot) | — |
| Local connection | Yes (a background daemon), until reboot | `<T>/bin/sd local connect --unprivileged` |
| C3's route process, Redis port-forward, a local proxy | Usually; they're background processes this session started | the start commands in `references/core/local-development.md` "Run", or below |

If the proxy address changed after a reconnect, read it again with the command in `references/setup/cluster.md` §4
(the `portforward` section's `localAddress`).

## 2. Tell the user how to use it

Include what applies, with real values:

- **See a sandbox in any browser:** a local proxy serves the frontend on a plain localhost URL and adds the
  sandbox's routing key to every request, so no header extension or proxy setting is needed:

  ```bash
  nohup "$T/bin/sd" local proxy --sandbox driver-plates<suffix> --map http://frontend.hotrod.svc:8080@localhost:18080 \
    > "$T/logs/local-proxy.log" 2>&1 & echo $! > "$T/local-proxy.pid"
  ```

  Then open http://localhost:18080 and book a ride: the plate starts with `SD-`. Use `--sandbox local-route<suffix>`
  for C3 (ETAs in seconds) or `--routegroup hotrod-plates<suffix>` for C2. Record `process <pid> local proxy` under
  Resources. One proxy at a time on this port; stop it before starting another:

  ```bash
  p=$(cat "$T/local-proxy.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF 'local proxy' && kill "$p"
  ```

- **The preview URL from C2:** opens in a browser signed in to the org, with no setup.
- **Any request through the connection:**
  `curl --proxy socks5h://<address> -H "baggage: sd-routing-key=<key>" http://frontend.hotrod.svc:8080/`.
- **The trial's CLI and cluster:** `<T>/bin/sd` (the trial org) and `<T>/bin/kc`, or
  `export KUBECONFIG=<T>/kubeconfig` for any kubectl tool. Their own `signadot` and kube context are unchanged.
- **The dashboard:** https://app.signadot.com, with the sandboxes, route group and any jobs or plans.
- **Things to try:** the `try:` line of every scenario that ran, from the trial log, plus each file's "Try it
  yourself" section.
- **Use it on their own services:** the agent skills that run this loop for any change:
  `npx skills add signadot/agent-skills --skill signadot-validate` (and `--skill signadot-plan` to author Plans).
  See https://www.signadot.com/docs/integrations/coding-agents/agent-skills. To install the operator on their own
  cluster: https://www.signadot.com/docs/installation/signadot-operator.
- **Connect a coding agent:** the Signadot MCP server, `<T>/bin/sd mcp` when the trial isolated its config or the CLI
  isn't on the user's PATH, otherwise `signadot mcp`; it uses the same org. Per-client setup:
  https://www.signadot.com/docs/integrations/mcp.

## 3. Offer teardown, don't do it

End the hand-off with something like: "Everything stays running so you can explore; nothing expires on its own.
When you're done, ask me to tear down the Signadot trial and I'll remove it all, in order, and tell you what's left
for you to do." Then stop. Run `references/finish/teardown.md` only when the user asks.

**Closing message,** after the hand-off: one line per scenario result, the report path, the preview URL, what's
running, and the teardown offer. If the user has no `signadot` on their PATH, say where the CLI is
(`cli_path` in the trial log) and offer to link it into a folder on their PATH, with their OK. Don't put `<T>/bin` itself on
PATH: its `sd` wrapper would shadow the `sd` find-and-replace tool some people use.
