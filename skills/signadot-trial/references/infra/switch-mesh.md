# Rebuild on a service mesh after the basics

The basics ran on Signadot's own routing (DevMesh). A mesh changes how HotROD and the operator are installed, so
when the user picks one after the basics, the trial rebuilds its demo cluster on that mesh with the same steps setup
uses, then runs the first scenario there. About 10 minutes, mostly pulling the demo app's images again. Run it before
any other pick: the rebuild removes everything in the cluster.

Only on a kind cluster the trial created (`created_kind_cluster: yes`). On an existing cluster, don't offer it.
The message before more scenarios says that the basics' sandboxes will be removed (their pages stay) and gets an
OK.

## 1. Remove what lives in the old cluster

```bash
for f in route-local redis-pf; do p=$(cat "$T/$f.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF "$T/" && kill "$p"; done
"$T/bin/sd" sandbox delete local-route<suffix>
"$T/bin/sd" routegroup delete hotrod-plates<suffix>
"$T/bin/sd" sandbox delete frontend-highlight<suffix>
"$T/bin/sd" sandbox delete driver-plates<suffix>
"$T/bin/sd" sandbox delete fast-route<suffix>
"$T/bin/sd" local disconnect
kind delete cluster --name signadot-trial --kubeconfig "$T/kubeconfig"
```

Take those sandboxes, the route group, the processes and the port-forward off `## Resources`. Keep `routegroup
hotrod-baseline<suffix>` and the cluster's registration in Signadot: both live in Signadot, and the new cluster takes
them over.

## 2. Rebuild on the mesh

Set `infra: <mesh>` under Run, then run these as setup does, with the mesh's file:

1. `references/setup/cluster.md` §1, then the mesh file's "Install before HotROD".
2. §2 with the mesh file's overlay.
3. §3 with the mesh file's operator flags. `install-operator.sh` finds the cluster already registered and creates a
   new cluster token for the new operator.
4. §4. The connection's proxy address changes: record the new `proxy:`.
5. The mesh file's "Mesh check", then the baseline ride from §5. The baseline link (`baseline_url`) works again as
   soon as HotROD is back.

Record each step under Steps as `rebuild-<step>` (for example `rebuild-operator`).

## 3. Prove it on the mesh

Run `references/core/isolated-change.md` again (Run, then Prove it). It creates `fast-route<suffix>` again. Kafka,
jobs and plans create `driver-plates<suffix>` again themselves if they're picked. Record the result as
`## Scenario <mesh>` (`istio`, `istio-ambient` or `linkerd`), and write its page as `$T/report/<mesh>.html`, titled
with the menu name ("On your service mesh: Istio"):

- **change:** the same one-service change as the first scenario, now on the mesh the user picked.
- **routing:** the same diagram, with the decision point labelled for the mesh (Istio's sidecar on driver, the
  ambient waypoint in front of route, or Signadot's sidecar next to Linkerd's proxy).
- **works:** card 3 from the mesh file's "What it shows": how Signadot works with the mesh to route by the routing
  key. Don't explain the mesh itself.
- Everything else as for any scenario page (`references/finish/report.md`).

## Docs

The mesh file's Docs section.
