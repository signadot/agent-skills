# Teardown

Only when the user asks. Before starting, list what will be removed (from the trial log's `## Resources`) and what
stays, and get a yes. If their request already says to remove everything ("tear it all down", "yes, remove
everything"), that's the yes: list what you're removing as you go instead of asking again. Never touch anything the trial log doesn't list: not the user's own login or `~/.signadot`, not
another local connection.

## Order

1. **Add-ons, in reverse run order.** Run the "Tear down" section of each add-on file that ran: testing
   (Plans, then Jobs), async (the demo-app files, then Kafka, which has nothing of its own), data, then each mesh
   copy added after the basics (`references/infra/add-mesh.md`, "Tear down"). Each removes its sandboxes, plugin,
   runner group or plan tag, and its namespace.
2. **The basics.**

   ```bash
   # Local processes, only if the recorded PIDs still belong to the trial (a PID can be reused after a reboot)
   for f in route-local redis-pf; do p=$(cat "$T/$f.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF "$T/" && kill "$p"; done
   "$T/bin/sd" sandbox delete local-route<suffix>
   "$T/bin/sd" routegroup delete hotrod-plates<suffix>
   "$T/bin/sd" sandbox delete frontend-highlight<suffix>
   "$T/bin/sd" sandbox delete driver-plates<suffix>
   "$T/bin/sd" sandbox delete fast-route<suffix>
   "$T/bin/sd" routegroup delete hotrod-baseline<suffix>
   ```

3. **The connection,** only if it's the trial's, and before the cluster goes: when `"$T/bin/sd" local status` shows
   `cluster signadot-trial<suffix>`, run `"$T/bin/sd" local disconnect`. Leave any other connection alone. (After
   the kind cluster is deleted, `local status` errors with `context "kind-signadot-trial" does not exist`; that's
   expected, so don't run it again.)
4. **The cluster.**
   - If the trial created the kind cluster (`created_kind_cluster: yes`):
     `kind delete cluster --name signadot-trial --kubeconfig "$T/kubeconfig"`.
   - Otherwise, remove only what the trial installed: `"$T/bin/hm" uninstall signadot-operator -n signadot` and
     `"$T/bin/kc" delete namespace signadot`, the mesh if the trial installed it (its infra file's "Tear down"), and
     each namespace listed under Resources (`"$T/bin/kc" delete namespace <ns>`).

   The user's kube context needs nothing: the trial never changed it.
5. **Check** that nothing the trial created is left in the org:

   ```bash
   "$T/bin/sd" sandbox list; "$T/bin/sd" routegroup list; "$T/bin/sd" resourceplugin list
   "$T/bin/sd" jobrunnergroup list; "$T/bin/sd" plan tag list
   ```

   None of these should show a trial name (with `<suffix>`). Delete any that remain.
6. **Retire the trial log,** so a later trial starts fresh instead of resuming this one:

   ```bash
   mv "$T/trial-log.md" "$T/trial-log.torn-down-$(date -u +%Y%m%d-%H%M%SZ).md"
   ```

7. **The trial folder,** only on a separate yes. If they keep it, remove the stale `route-local.pid` and
   `redis-pf.pid` files, and tell them where the report is (`<trial folder>/report/index.html`) and that they can ask
   you to delete the folder later. It holds the CLI, the trial's login and connection settings, the
   HotROD build, the report and the logs. Offer to copy the report somewhere first. Use the literal path preflight
   printed (for example `/Users/me/project/.signadot-trial`), never a variable that could be empty:

   ```bash
   chmod -R u+w "/Users/me/project/.signadot-trial" && rm -rf "/Users/me/project/.signadot-trial"
   ```

Images the trial pulled or built stay in Docker on the host: the `golang:1.27.1` image when route was built in a
container (about 900 MB), and locally built demo images (for example `temporal-money-transfer:v1.0`). Mention
`docker image rm <image>` for each if the user wants the space back.

## Left for the user

Tell them, as a short list, the cluster first:

- **Delete the cluster's registration** at `https://app.signadot.com/cluster/signadot-trial<suffix>` (or Settings →
  Clusters). The CLI can't remove it, and until it's gone it holds one of the org's clusters: a free org allows one,
  so the next trial can't start.
- If testing ran: revert the org settings recorded as `org_setting` (the plan runner on the cluster and the allowed
  Playwright image), if they don't want them.
- The org and the account stay. The trial's CLI login was in the trial folder; to use Signadot from their own CLI,
  they run `signadot auth login`.
- If the trial asked them to disconnect their own connection (`disconnected_user_connection: yes`), reconnect it
  with `signadot local connect`.
