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
| C3's route process and Redis port-forward | Usually; they're background processes this session started | the start commands in `references/core/local-development.md` "Run" |

If the proxy address changed after a reconnect, read it again with the command in `references/setup/cluster.md` §4 (the `portforward` section's `localAddress`).

## 2. Tell the user how to use it

Include what applies, with real values:

- **The app with a routing key:** the preview URL from C2 (no setup needed: it opens in a browser signed in to the
  org), or any request through the connection:
  `curl --proxy socks5h://<address> -H "baggage: sd-routing-key=<key>" http://frontend.hotrod.svc:8080/`.
  A browser can use the same proxy (SOCKS5 at `<address>`) with a header extension that adds the `baggage` header.
- **The trial's CLI and cluster:** `<T>/bin/sd` (the trial org) and `<T>/bin/kc`, or
  `export KUBECONFIG=<T>/kubeconfig` for any kubectl tool. Their own `signadot` and kube context are unchanged.
- **The dashboard:** https://app.signadot.com, with the sandboxes, route group and any jobs or plans.
- **Things to try:** the `try:` line of every scenario that ran, from the trial log, plus each file's "Try it
  yourself" section.
- **Connect a coding agent:** the Signadot MCP server, `<T>/bin/sd mcp` (or `signadot mcp` when the trial didn't
  isolate its config), uses the same org.

## 3. Offer teardown, don't do it

End the hand-off with something like: "Everything stays running so you can explore; nothing expires on its own.
When you're done, ask me to tear down the Signadot trial and I'll remove it all, in order, and tell you what's left
for you to do." Then stop. Run `references/finish/teardown.md` only when the user asks.

Closing message, after the hand-off: one line per scenario result, the report path, the preview URL, what's running,
and the teardown offer. If the CLI in `$T/bin` isn't on the user's PATH, say where it is, and offer to add it (only
with their OK).
