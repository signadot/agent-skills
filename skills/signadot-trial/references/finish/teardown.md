# Teardown

Only when the user asks. Before starting, list what will be removed (from the trial log's `## Resources`) and what
stays, and get a yes. Never touch `~/.signadot`, the user's own login, or anything the trial log doesn't list.

## Order

1. **Variations, in reverse run order.** Run the "Tear down" section of each variation file that ran: testing
   (Plans, then Jobs), async (the demo-app files, then Kafka, which has nothing of its own), then data. Each
   removes its sandboxes, plugin, runner group or plan tag, and its namespace.
2. **Core tutorial.**

   ```bash
   kill "$(cat "$T/route-local.pid")" "$(cat "$T/redis-pf.pid")" 2>/dev/null   # C3's local processes
   "$T/bin/sd" sandbox delete local-route<suffix>
   "$T/bin/sd" routegroup delete hotrod-plates<suffix>
   "$T/bin/sd" sandbox delete frontend-highlight<suffix>
   "$T/bin/sd" sandbox delete driver-plates<suffix>
   ```

3. **The connection,** only if it's the trial's: when `"$T/bin/sd" local status` shows
   `cluster signadot-trial<suffix>`, run `"$T/bin/sd" local disconnect`. Leave any other connection alone.
4. **The cluster.**
   - If the trial created the kind cluster (`created_kind_cluster: yes`):
     `kind delete cluster --name signadot-trial --kubeconfig "$T/kubeconfig"`.
   - Otherwise, remove only what the trial installed: `helm uninstall signadot-operator -n signadot --kubeconfig
     "$T/kubeconfig"`, the mesh if the trial installed it (its infra file's "Tear down"), and each namespace listed
     under Resources (`"$T/bin/kc" delete namespace <ns>`).

   The user's kube context needs nothing: the trial never changed it.
5. **Check** that nothing the trial created is left in the org:

   ```bash
   "$T/bin/sd" sandbox list; "$T/bin/sd" routegroup list; "$T/bin/sd" resourceplugin list
   "$T/bin/sd" jobrunnergroup list; "$T/bin/sd" plan tag list
   ```

   None of these should show a trial name (with `<suffix>`). Delete any that remain.
6. **The trial folder,** only on a separate yes: `rm -rf "${T:?}"` (the `:?` stops the command if `T` is empty).
   Prefer the literal path, e.g. `rm -rf ~/.signadot-trial`. It holds the CLI, the trial's login (when isolated),
   the report and the logs. Offer to copy the report somewhere first.

Locally built demo images stay in Docker on the host (for example `temporal-money-transfer:v1.0`); mention
`docker image rm <image>` if the user wants the space back.

## Left for the user

Tell them, as a short list:

- Remove the cluster registration in the dashboard: Settings → Clusters → `signadot-trial<suffix>`.
- If testing ran: revert the org settings recorded as `org_setting` (the plan runner on the cluster and the allowed
  Playwright image), if they don't want them.
- The org and the account stay.
- If the trial asked them to disconnect their own connection (`disconnected_user_connection: yes`), reconnect it
  with `signadot local connect`.
