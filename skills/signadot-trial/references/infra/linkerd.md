# Linkerd

Chosen before setup. Adds about 2 minutes and 0.5 GB of memory. Namespace `linkerd`. Needs `openssl` for the
mesh's certificates.

## What it shows

Signadot routing in a cluster that runs Linkerd. Linkerd keeps doing what it does (mTLS, retries, metrics), and
Signadot's DevMesh sidecar, running next to the Linkerd proxy in each pod, routes requests that carry a routing key
to their sandbox.

## Install before HotROD

Run this after the kind cluster is up (`references/setup/cluster.md` §1) and before HotROD (§2). Linkerd's identity
needs a trust anchor and an issuer certificate; generate them with openssl, then install the charts with helm (the
chart repository is given per command, so the user's helm repositories don't change).

```bash
D="$T/linkerd-certs"; mkdir -p "$D" && cd "$D"
openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -new -key ca.key -subj "/CN=root.linkerd.cluster.local" -out ca.csr
printf 'basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n' > ca.ext
openssl x509 -req -in ca.csr -signkey ca.key -extfile ca.ext -days 365 -out ca.crt
openssl ecparam -name prime256v1 -genkey -noout -out issuer.key
openssl req -new -key issuer.key -subj "/CN=identity.linkerd.cluster.local" -out issuer.csr
printf 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n' > issuer.ext
openssl x509 -req -in issuer.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile issuer.ext -days 365 -out issuer.crt
openssl verify -CAfile ca.crt issuer.crt

R=https://helm.linkerd.io/edge
helm upgrade --install linkerd-crds linkerd-crds --repo $R --version 2026.11.2 -n linkerd --create-namespace \
  --kubeconfig "$T/kubeconfig" --wait > "$T/logs/linkerd.log" 2>&1
helm upgrade --install linkerd-control-plane linkerd-control-plane --repo $R --version 2026.11.2 -n linkerd \
  --set-file identityTrustAnchorsPEM=ca.crt --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key --kubeconfig "$T/kubeconfig" --wait >> "$T/logs/linkerd.log" 2>&1
"$T/bin/kc" -n linkerd get pods
```

Done when `openssl verify` prints `OK` and the `linkerd` pods are running. The certificates are for this local
cluster only. Record `mesh linkerd` and `namespace linkerd` under Resources.

## Overlay and operator values

- HotROD overlay: `linkerd`. Its four services carry both `linkerd.io/inject: enabled` and
  `sidecar.signadot.com/inject: "true"`.
- Operator values, in `$T/operator-values.yaml`:

  ```yaml
  linkerd:
    enabled: true
  ```

- `install-operator.sh` flags: `--values "$T/operator-values.yaml"` (the DevMesh `sd-sidecar` is the proxy it
  checks).

## Mesh check

`install-operator.sh` prints `sidecars: 4/4`. Each of driver, frontend, location and route also runs
`linkerd-proxy`:

```bash
"$T/bin/kc" -n hotrod get pods -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.initContainers[*].name} {.spec.containers[*].name}{"\n"}{end}'
```

C1–C3 then prove routing on Linkerd: the same commands and the same "done when" checks as on DevMesh.

## Tear down

Deleting the kind cluster removes Linkerd. On an existing cluster, after the operator:

```bash
helm uninstall linkerd-control-plane linkerd-crds -n linkerd --kubeconfig "$T/kubeconfig"
"$T/bin/kc" delete namespace linkerd
```

## Docs

https://www.signadot.com/docs/guides/request-routing/linkerd.md, and
https://www.signadot.com/docs/guides/request-routing/devmesh.md for the DevMesh sidecar it relies on.
