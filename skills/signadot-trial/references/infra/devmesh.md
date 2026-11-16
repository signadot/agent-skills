# DevMesh (default)

## What it shows

Signadot's own request routing. The operator adds a small proxy (`sd-sidecar`) to each annotated workload; it
reads the routing key on each request and sends the request to the sandbox that owns the key, or to the baseline.
No service mesh is needed.

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
