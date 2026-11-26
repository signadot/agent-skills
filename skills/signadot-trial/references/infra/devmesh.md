# DevMesh (default)

## What it shows

Signadot's own request routing. The operator adds a small proxy (`sd-sidecar`) to each annotated workload. It
routes at the destination: when a request arrives at a pod, that pod's sidecar reads the routing key and sends the
request on to the sandbox that owns the key, or to the service beside it. No service mesh is needed.

## Install before HotROD

Nothing.

## Overlay and operator values

- HotROD overlay: `devmesh` (its workloads carry `sidecar.signadot.com/inject: "true"`).
- `install-operator.sh` flags: none (`--proxy sd-sidecar` is the default).

## Mesh check

`install-operator.sh` prints `sidecars: 4/4`: driver, frontend, location and route each run an `sd-sidecar`
container. To see it yourself:

```bash
"$T/bin/kc" -n hotrod get pods -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[*].name}{"\n"}{end}'
```

The basics then prove routing on DevMesh.

## Tear down

Removed with the operator (see teardown.md); nothing extra.

## Docs

- https://www.signadot.com/docs/guides/request-routing/devmesh.md (how DevMesh routes requests)
