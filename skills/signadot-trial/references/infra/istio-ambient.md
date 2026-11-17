# Istio ambient mode

Installed during setup when the first request names it (about 2 more minutes; the basics then run on it), or after
the basics with its own copy of HotROD in `hotrod-ambient` (`references/infra/add-mesh.md`, about 3 minutes, or 2
when Istio is in already). Istio adds about 0.6 GB of memory, in namespace `istio-system`; a copy adds about 1.2 GB.

## What it shows

Signadot routing on Istio ambient mode, where pods run without sidecars. Each node's ztunnel carries traffic at
layer 4 and never reads headers, so layer-7 routing happens in a **waypoint**: a proxy in front of the destination
service. HotROD's namespace runs in ambient mode with one waypoint, and the operator adds sandbox routes, matched on
the routing key, to HotROD's VirtualServices; the waypoint applies them.

## Install before HotROD

One Istio install serves both modes: run `references/infra/istio.md`'s "Install before HotROD", including its check
for an Istio that's already there, and record what it says. Skip it when `mesh istio` is already under Resources.

An Istio that was already in an existing cluster must run ambient: `"$T/bin/kc" -n istio-system get daemonset
ztunnel` must succeed. If it doesn't, Istio ambient can't run there; say so and skip it.

## Overlay and operator values

- Namespace labels, before the overlay goes in. `<ns>` is `hotrod` during setup, `hotrod-ambient` when added after
  the basics:

  ```bash
  "$T/bin/kc" create namespace <ns> --dry-run=client -o yaml | "$T/bin/kc" apply -f -
  "$T/bin/kc" label namespace <ns> istio.io/dataplane-mode=ambient istio.io/use-waypoint=waypoint --overwrite
  ```

- HotROD overlay: `istio-ambient`. It adds the waypoint (a Gateway named `waypoint`, class `istio-waypoint`) and a
  VirtualService for each service that sandboxes fork.
- Operator values, in `$T/operator-values.yaml`:

  ```yaml
  istio:
    enabled: true
  linkerd:
    enabled: false   # one mesh at a time
  trafficManager:
    replicas: 1      # one node: the default 2 replicas don't fit
  ```

- `install-operator.sh` flags: `--values "$T/operator-values.yaml" --proxy none` (ambient pods have no sidecar to
  count).

## Mesh check

```bash
"$T/bin/kc" get namespace <ns> --show-labels | grep -o 'istio.io/[a-z-]*=[a-z]*'
"$T/bin/kc" -n <ns> get gateway waypoint
"$T/bin/kc" -n <ns> get pods -l gateway.networking.k8s.io/gateway-name=waypoint
```

Done when the namespace has both labels, the waypoint Gateway is programmed, and its pod is running; HotROD's own pods
have a single container (no sidecar). The first scenario then proves routing through the waypoint.

## Tear down

As Istio's (`references/infra/istio.md`): deleting the kind cluster removes it.

## Docs

https://www.signadot.com/docs/guides/request-routing/istio-ambient.md, including clusters that mix ambient and
sidecar namespaces. The trial uses VirtualServices because HotROD's overlay does; for new ambient setups the docs
recommend HTTPRoutes with `istio.gatewayAPI.enabled: true`.
