# Istio ambient mode

Chosen before setup. Adds about 2 minutes and 0.5 GB of memory. Namespace `istio-system`.

## What it shows

Signadot routing on Istio ambient mode, where pods run without sidecars. Each node's ztunnel carries traffic at
layer 4 and never reads headers, so layer-7 routing happens in a **waypoint**: a proxy in front of the destination
service. HotROD's namespace runs in ambient mode with one waypoint, and the operator adds sandbox routes, matched on
the routing key, to HotROD's VirtualServices; the waypoint applies them.

## Install before HotROD

**On an existing cluster, check first** whether Istio is already installed:

```bash
"$T/bin/hm" status istiod -n istio-system
```

If it succeeds, use the mesh that's there (it must run in ambient mode): skip this install, don't record `mesh` or
`istio-system` (teardown must not remove them), and tell the user the trial adds HotROD to their mesh. Still label the
`hotrod` namespace as below.

Run this after the kind cluster is up (`references/setup/cluster.md` §1) and before HotROD (§2). Waypoints are
Gateway API resources, so the Gateway API CRDs come first. Charts go through `$T/bin/hm`, with the repository given
per command.

```bash
"$T/bin/kc" get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || "$T/bin/kc" apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml > "$T/logs/istio.log"
R=https://istio-release.storage.googleapis.com/charts
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
"$T/bin/kc" create namespace hotrod --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/kc" label namespace hotrod istio.io/dataplane-mode=ambient istio.io/use-waypoint=waypoint --overwrite
"$T/bin/kc" -n istio-system get pods
```

The memory flags keep istiod, ztunnel and the waypoint small enough for a single-node trial cluster. Done when `istiod`, `istio-cni-node` and `ztunnel` are running. Record `mesh istio-ambient` and
`namespace istio-system` under Resources.

## Overlay and operator values

- HotROD overlay: `istio-ambient`. It adds the waypoint (a Gateway named `waypoint`, class `istio-waypoint`) and a
  VirtualService for each service that sandboxes fork.
- Operator values, in `$T/operator-values.yaml`:

  ```yaml
  istio:
    enabled: true
  trafficManager:
    replicas: 1    # one node: the default 2 replicas don't fit
  ```

- `install-operator.sh` flags: `--values "$T/operator-values.yaml" --proxy none` (ambient pods have no sidecar to
  count).

## Mesh check

```bash
"$T/bin/kc" get namespace hotrod --show-labels | grep -o 'istio.io/[a-z-]*=[a-z]*'
"$T/bin/kc" -n hotrod get gateway waypoint
"$T/bin/kc" -n hotrod get pods -l gateway.networking.k8s.io/gateway-name=waypoint
```

Done when the namespace has both labels, the waypoint Gateway is programmed, and its pod is running; HotROD's own pods
have a single container (no sidecar). The basics then prove routing through the waypoint.

## Tear down

Deleting the kind cluster removes Istio. On an existing cluster, after the operator:

```bash
"$T/bin/hm" uninstall ztunnel istio-cni istiod istio-base -n istio-system
"$T/bin/kc" delete namespace istio-system
```

The Gateway API CRDs stay, since other tools may use them.

## Docs

https://www.signadot.com/docs/guides/request-routing/istio-ambient.md, including clusters that mix ambient and
sidecar namespaces. The trial uses VirtualServices because HotROD's overlay does; for new ambient setups the docs
recommend HTTPRoutes with `istio.gatewayAPI.enabled: true`.
