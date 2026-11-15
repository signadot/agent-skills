# Istio (sidecar mode)

Chosen before setup. Adds about 2 minutes and 0.5 GB of memory. Namespace `istio-system`.

## What it shows

Signadot routing on an existing Istio mesh, with no extra proxy. Istio routes at the source: each caller's Envoy
sidecar decides where a request goes. The operator adds routes for each sandbox to HotROD's VirtualServices, matching
the routing key in the `baggage` header; requests without it keep going to the baseline.

## Install before HotROD

**On an existing cluster, check first** whether Istio is already installed:

```bash
helm status istiod -n istio-system --kubeconfig "$T/kubeconfig"
```

If it succeeds, use the mesh that's there: skip this install, don't record `mesh` or `istio-system` (teardown must
not remove them), and tell the user the trial adds HotROD to their mesh.

Run this after the kind cluster is up (`references/setup/cluster.md` §1) and before HotROD (§2). It uses helm only,
with the chart repository given per command, so the user's helm repositories don't change.

```bash
R=https://istio-release.storage.googleapis.com/charts
helm upgrade --install istio-base base --repo $R --version 1.30.8 -n istio-system --create-namespace \
  --kubeconfig "$T/kubeconfig" --wait > "$T/logs/istio.log" 2>&1
helm upgrade --install istiod istiod --repo $R --version 1.30.8 -n istio-system \
  --set pilot.resources.requests.memory=256Mi --set pilot.resources.requests.cpu=100m \
  --set global.proxy.resources.requests.memory=64Mi --set global.proxy.resources.requests.cpu=10m \
  --kubeconfig "$T/kubeconfig" --wait >> "$T/logs/istio.log" 2>&1
"$T/bin/kc" -n istio-system get pods
```

The `--set` flags lower istiod's and each sidecar's memory requests (2 GiB and 128 MiB by default), which a
single-node trial cluster can't fit next to HotROD and the operator. Done when `istiod` is running. Record `mesh istio` and `namespace istio-system` under Resources.

## Overlay and operator values

- HotROD overlay: `istio`. Its four services carry `sidecar.istio.io/inject: "true"`, and it adds a VirtualService
  for each service that sandboxes fork.
- Operator values, in `$T/operator-values.yaml`:

  ```yaml
  istio:
    enabled: true
  trafficManager:
    replicas: 1    # one node: the default 2 replicas don't fit
  ```

- `install-operator.sh` flags: `--values "$T/operator-values.yaml" --proxy istio-proxy`.

## Mesh check

`install-operator.sh` prints `sidecars: 4/4`: each of driver, frontend, location and route runs an `istio-proxy`
(as a native sidecar, so it's listed among the init containers). Once C1 runs, the operator has added a route for it:

```bash
"$T/bin/kc" -n hotrod get virtualservices
"$T/bin/kc" -n hotrod get virtualservice route -o yaml | grep -c signadot-operator
```

C1–C3 then prove routing on Istio: the same commands and the same "done when" checks as on DevMesh.

## Tear down

Deleting the kind cluster removes Istio. On an existing cluster, after the operator:

```bash
helm uninstall istiod istio-base -n istio-system --kubeconfig "$T/kubeconfig"
"$T/bin/kc" delete namespace istio-system
```

## Docs

https://www.signadot.com/docs/guides/request-routing/istio.md. The trial installs Istio with helm at a fixed version
so the mesh is predictable; on a real cluster you'd use your existing mesh.
