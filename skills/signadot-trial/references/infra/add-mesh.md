# Add a service mesh after the basics

The basics ran on Signadot's own routing (DevMesh) in `hotrod`. Each mesh the user picks after them gets its own
namespace with its own copy of HotROD, next to the basics, and the first scenario runs again there. Nothing that's
running is removed: the basics' sandboxes, links and pages keep working. About 4 minutes for the first mesh, and 2
for the second Istio mode, since Istio is in by then. Each copy uses about 1.1 GB of memory.

Only on a kind cluster the trial created (`created_kind_cluster: yes`); on an existing cluster, don't offer it.

| Pick | `<mesh>` | `<ns>` | Mesh file | Family |
|---|---|---|---|---|
| Istio | `istio` | `hotrod-istio` | `references/infra/istio.md` | Istio |
| Istio ambient | `ambient` | `hotrod-ambient` | `references/infra/istio-ambient.md` | Istio |
| Linkerd | `linkerd` | `hotrod-linkerd` | `references/infra/linkerd.md` | Linkerd |

`<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

**One mesh family at a time.** The operator works with Istio or with Linkerd, not both; DevMesh stays on with
either, so the basics keep routing. One Istio install serves both Istio modes. Run the Istio picks first (Istio, then
Istio ambient). Before a pick from the other family than the one in the cluster, ask:

```markdown
Signadot's operator works with one mesh at a time. Switching to **Linkerd** removes Istio and its demo copies
(their pages stay; their links stop working). The basics keep running. About 5 minutes. Switch now, or skip Linkerd?
```

(Swap the names when going from Linkerd to Istio.) On "switch", run "Switch the mesh family" below, then this
file's steps for the pick. On "skip", record the pick as `skipped` and go on.

## 1. Check memory

```bash
docker stats --no-stream --format '{{.MemUsage}}' signadot-trial-control-plane
```

It prints what the cluster uses and its limit, e.g. `4.3GiB / 7.7GiB`. The copy needs about 1.1 GB more, and the
mesh about 0.3 GB if it isn't in the cluster yet. If that doesn't fit, ask one question with these choices: remove a
mesh copy whose scenario is done (its "Tear down" below; its page stays), give Docker more memory, or skip this
mesh.

## 2. Install the mesh, if it isn't in the cluster

Skip this when `mesh istio` (for either Istio mode) or `mesh linkerd` is already under Resources. Otherwise run the
mesh file's "Install before HotROD" and record what it says.

## 3. Deploy HotROD's copy

`OVERLAY` is the mesh file's overlay. On Istio ambient, label the namespace before the overlay goes in (the mesh
file's "Overlay and operator values"). The images are on the node already, so this takes about a minute.

```bash
NS=hotrod-<mesh> OVERLAY=<the mesh file's overlay>
"$T/bin/kc" create namespace "$NS" --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/kc" -n "$NS" apply -k "https://github.com/signadot/hotrod//k8s/overlays/prod/$OVERLAY?ref=b16178651580a8ba3ceb45ac7c59f4579611b0b3"
"$T/bin/kc" -n "$NS" wait --for=condition=available deploy --all --timeout=600s
"$T/bin/kc" -n "$NS" rollout status statefulset/kafka --timeout=600s
"$T/bin/kc" -n "$NS" rollout status statefulset/mysql --timeout=600s
```

Record `namespace hotrod-<mesh>` under Resources.

## 4. Turn the mesh on in the operator

Write the mesh file's operator values to `$T/operator-values.yaml`, then:

```bash
bash "$S/scripts/install-operator.sh" --trial-dir "$T" --cluster <cluster> --values "$T/operator-values.yaml" \
  --namespace hotrod-<mesh> --proxy <the mesh file's proxy>
```

It upgrades the installed operator with the values (`operator: upgraded`; `unchanged` when the mesh was on already)
and keeps its cluster token. The operator's pods restart once, onto the mesh. Done when it prints `sidecars: 4/4`.

The restart can drop this computer's connection. Check it:

```bash
curl -s -o /dev/null -w '%{http_code}\n' --proxy <proxy> http://frontend.hotrod.svc:8080/
```

If it doesn't print `200`, reconnect: `"$T/bin/sd" local disconnect`, then `"$T/bin/sd" local connect
--unprivileged`, and record the new `proxy:` (`references/setup/cluster.md` §4). On a privileged connection, ask the
user to run `"$T/bin/sd" local connect` again in their own terminal.

## 5. Mesh check and baseline link

Run the mesh file's "Mesh check" with `-n hotrod-<mesh>`. Then the copy's baseline link, a route group that matches
no sandbox:

```bash
"$T/bin/sd" routegroup apply -f "$S/assets/specs/infra/hotrod-baseline-mesh.yaml" --set cluster=<cluster> \
  --set suffix=<suffix> --set mesh=<mesh>
"$T/bin/sd" routegroup get hotrod-baseline-<mesh><suffix> -o json | grep -oE '"url": *"https://[^"]+"' | head -1
```

Repeat the second command until the link appears. Record `routegroup hotrod-baseline-<mesh><suffix>` under
Resources.

## 6. Prove it on the mesh

The first scenario's change, in the copy:

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/infra/fast-route-mesh.yaml" --set cluster=<cluster> \
  --set suffix=<suffix> --set mesh=<mesh>
"$T/bin/sd" sandbox get fast-route-<mesh><suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
bash "$S/scripts/ride.sh" --proxy <proxy> --frontend http://frontend.hotrod-<mesh>.svc:8080
bash "$S/scripts/ride.sh" --proxy <proxy> --frontend http://frontend.hotrod-<mesh>.svc:8080 --key <routing key>
```

Record `sandbox fast-route-<mesh><suffix>` under Resources. Done when, as in the first scenario, the ride without
the key has an ETA in minutes with every hop `baseline`, and the ride with the key has the ETA `1s` with the hop
`route fast-route-<mesh><suffix>`.

Then show that the basics still route on DevMesh next to the mesh: if `fast-route<suffix>` is still there, the
keyed ride from the first scenario (`ride.sh --proxy <proxy> --key <its key>`, HotROD's own frontend) still has the
hop `route fast-route<suffix>`.

## Record

The scenario ID is the mesh file's name: `istio`, `istio-ambient` or `linkerd`.

```markdown
## Scenario istio
status: passed
seconds: <apply to proof>
namespace: hotrod-istio
baseline: ETA <minutes>
sandbox: ETA 1s
hops-baseline: <hops line from the first ride>
hops-sandbox: <hops line from the second ride>
routing-key: <routing key>
basics-still-route: yes
proof: the route step was served by sandbox fast-route-istio<suffix> only when the routing key was sent
specs: assets/specs/infra/fast-route-mesh.yaml, assets/specs/infra/hotrod-baseline-mesh.yaml
link-baseline: <hotrod-baseline-istio<suffix>'s link>
link-sandbox: <fast-route-istio<suffix>'s link>
links: <the mesh file's Docs page>
try: open both links and compare the ETAs; kubectl --kubeconfig <T>/kubeconfig -n hotrod-istio get pods
```

Write its page as `$T/report/<scenario ID>.html`, titled with the menu name ("On your service mesh: Istio"):

- **The demo app:** the same HotROD, its own copy in `hotrod-<mesh>`, on the mesh.
- **The change:** the same one-service change as the first scenario.
- **The sandbox:** a copy of only `route` in `hotrod-<mesh>`; plus the copy's baseline link.
- **Routing:** the same diagram, with the decision where the mesh makes it (`references/finish/report.md`, "The
  diagram"): Istio's Envoy sidecar inside driver's pod, the caller; the ambient waypoint in front of route, outside
  any pod; or Signadot's sidecar inside the normal route's pod, next to Linkerd's proxy. The "how" text comes from
  the mesh file's "What it shows": how Signadot works with the mesh to route by the key. Don't explain the mesh
  itself.
- **Test it yourself:** as the first scenario's, with this copy's links and `-n hotrod-<mesh>`; the curl goes to
  `frontend.hotrod-<mesh>.svc`.

## Tear down

One mesh copy (also how to free memory, or to make room for a mesh switch):

```bash
"$T/bin/sd" sandbox delete fast-route-<mesh><suffix>
"$T/bin/sd" routegroup delete hotrod-baseline-<mesh><suffix>
"$T/bin/kc" delete namespace hotrod-<mesh>
```

Take them off `## Resources`. The mesh itself goes with the kind cluster at teardown.

## Switch the mesh family

From Istio to Linkerd; going the other way, swap the families and their files. About 5 minutes. The order keeps the
operator off a mesh before that mesh is removed.

1. Tear down each Istio copy that's still there (above).
2. Install Linkerd: `linkerd.md`'s "Install before HotROD".
3. Write `linkerd.md`'s operator values to `$T/operator-values.yaml` and move the operator over. Its check counts the
   basics' sidecars:

   ```bash
   bash "$S/scripts/install-operator.sh" --trial-dir "$T" --cluster <cluster> --values "$T/operator-values.yaml"
   ```

   Done when it prints `operator: upgraded` and `sidecars: 4/4`. Check the connection as in step 4.
4. Remove Istio, and take `mesh istio` and `namespace istio-system` off Resources:

   ```bash
   "$T/bin/hm" uninstall ztunnel istio-cni istiod istio-base -n istio-system
   "$T/bin/kc" delete namespace istio-system
   ```

   (From Linkerd to Istio: `"$T/bin/hm" uninstall linkerd-control-plane linkerd-crds -n linkerd` and
   `"$T/bin/kc" delete namespace linkerd`.)
5. Go on with step 3 above for the pick: Linkerd is installed and the operator is on it.

Record the step under Steps as `switch-mesh · ok · <seconds>s · istio → linkerd`.

## Docs

The mesh file's Docs section. For running sidecar and ambient namespaces side by side:
https://www.signadot.com/docs/guides/request-routing/istio-ambient.md.
