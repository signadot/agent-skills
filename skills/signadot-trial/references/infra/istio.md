# Istio (sidecar mode)

Installed during setup when the first request names it (about 2 more minutes; the basics then run on it), or after
the basics with its own copy of HotROD in `hotrod-istio` (`references/infra/add-mesh.md`, about 4 minutes). Istio
adds about 0.3 GB of memory, in namespace `istio-system`; a copy adds about 1.1 GB.

## What it shows

Signadot routing on an existing Istio mesh, with no extra proxy. Istio routes at the source: each caller's Envoy
sidecar decides where a request goes. The operator adds routes for each sandbox to HotROD's VirtualServices, matching
the routing key in the `baggage` header; requests without it keep going to the baseline.

## Install before HotROD

**On an existing cluster, check first** whether Istio is already installed:

```bash
"$T/bin/hm" status istiod -n istio-system
```

If it succeeds, use the mesh that's there: skip this install, don't record `mesh` or `istio-system` (teardown must
not remove them), and tell the user the trial adds HotROD to their mesh.

Run this after the kind cluster is up (`references/setup/cluster.md` §1) and before HotROD (§2), or from
`references/infra/add-mesh.md`. It installs Istio with the ambient profile, which serves both modes: namespaces
whose pods have Envoy sidecars, and ambient namespaces with a waypoint. So Istio ambient can be added later without
reinstalling. Waypoints are Gateway API resources, so the Gateway API CRDs come first. Charts go through `$T/bin/hm`
(helm with the trial's kubeconfig and cache), with the repository given per command, so the user's helm setup
doesn't change.

```bash
"$T/bin/kc" get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || "$T/bin/kc" apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml > "$T/logs/istio.log"
R=https://blob.istio.io/istio-release/charts
"$T/bin/hm" upgrade --install istio-base base --repo $R --version 1.30.8 -n istio-system --create-namespace \
  --wait >> "$T/logs/istio.log" 2>&1
"$T/bin/hm" upgrade --install istiod istiod --repo $R --version 1.30.8 -n istio-system --set profile=ambient \
  --set pilot.resources.requests.memory=256Mi --set pilot.resources.requests.cpu=100m \
  --set global.proxy.resources.requests.memory=64Mi --set global.proxy.resources.requests.cpu=10m \
  --wait >> "$T/logs/istio.log" 2>&1
"$T/bin/hm" upgrade --install istio-cni cni --repo $R --version 1.30.8 -n istio-system --set profile=ambient \
  --wait >> "$T/logs/istio.log" 2>&1
"$T/bin/hm" upgrade --install ztunnel ztunnel --repo $R --version 1.30.8 -n istio-system \
  --set resources.requests.memory=128Mi --set resources.requests.cpu=50m \
  --wait >> "$T/logs/istio.log" 2>&1
"$T/bin/kc" -n istio-system get pods
```

The `--set` flags lower the memory requests of istiod (2 GiB by default), each sidecar (128 MiB) and ztunnel, which
a single-node trial cluster can't fit next to HotROD and the operator. Done when `istiod`,
`istio-cni-node` and `ztunnel` are running. Record `mesh istio` and `namespace istio-system` under Resources.

## Overlay and operator values

- HotROD overlay: `istio`. Its four services carry `sidecar.istio.io/inject: "true"`, and it adds a VirtualService
  for each service that sandboxes fork.
- Operator values, in `$T/operator-values.yaml`:

  ```yaml
  istio:
    enabled: true
  linkerd:
    enabled: false   # one mesh at a time
  trafficManager:
    replicas: 1      # one node: the default 2 replicas don't fit
  ```

- `install-operator.sh` flags: `--values "$T/operator-values.yaml" --proxy istio-proxy`.

## Mesh check

`install-operator.sh` prints `sidecars: 4/4`: each of driver, frontend, location and route runs an `istio-proxy`
(as a native sidecar, so it's listed among the init containers). Once the first sandbox runs, the operator has added
a route for it. `<ns>` is `hotrod` during setup, `hotrod-istio` when added after the basics:

```bash
"$T/bin/kc" -n <ns> get virtualservices
"$T/bin/kc" -n <ns> get virtualservice route -o yaml | grep -c signadot-operator
```

The first scenario then proves routing on Istio: the same commands and the same "done when" checks as on DevMesh.

## Tear down

Deleting the kind cluster removes Istio. On an existing cluster, after the operator:

```bash
"$T/bin/hm" uninstall ztunnel istio-cni istiod istio-base -n istio-system
"$T/bin/kc" delete namespace istio-system
```

The Gateway API CRDs stay, since other tools may use them.

## Docs

https://www.signadot.com/docs/guides/request-routing/istio.md. The trial installs Istio with helm at a fixed version
so the mesh is predictable; on a real cluster you'd use your existing mesh.
