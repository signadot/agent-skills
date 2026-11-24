# Cluster, operator, connection and baseline

`T` is the trial folder and `S` the skill folder. The infrastructure choice (`infra:` in the trial log) decides
three things here: what to install before HotROD, HotROD's overlay, and the operator flags. All three come from the
chosen `references/infra/<choice>.md`.

## 1. Kind cluster (`cluster`, part 1)

Start this right after `install-cli.sh`, in the background if your shell allows it, so it runs during signup.
kind writes the cluster's credentials to the trial's own kubeconfig, so the user's kube context and
`~/.kube/config` never change.

First check `kind get clusters`. If a cluster named `signadot-trial` is already there and the trial log doesn't
mention it, ask the user before reusing it: it may be someone else's.

```bash
T="<trial_dir>"   # the absolute path preflight printed
if kind get clusters 2>/dev/null | grep -qx signadot-trial; then
  kind export kubeconfig --name signadot-trial --kubeconfig "$T/kubeconfig"
else
  kind create cluster --name signadot-trial --kubeconfig "$T/kubeconfig" --wait 120s > "$T/logs/kind.log" 2>&1
fi
chmod 600 "$T/kubeconfig"
"$T/bin/kc" get nodes
```

Done when the node is `Ready`. Record `kind_cluster signadot-trial` under Resources and `created_kind_cluster: yes`,
`kube_context: kind-signadot-trial` under Run (`created_kind_cluster: no` when you reused one, so teardown leaves it).

Then run the chosen infra file's "Install before HotROD" (nothing for DevMesh).

### Using an existing local cluster instead

Only if the user picked one in reply to the plan:

1. Refuse it if its context or server looks like a cloud cluster: `arn:aws:eks`, `eks.amazonaws.com`, `gke_`,
   `container.googleapis.com`, `azmk8s.io`.
2. If it doesn't look local (a context starting with `docker-desktop`, `kind-`, `k3d-`, `minikube`, `orbstack`,
   `rancher-desktop` or `colima`, or a server on `localhost`, `127.0.0.1`, `host.docker.internal` or `*.orb.local`),
   ask the user whether it's a local or dev cluster only they use. Continue only on a yes.
3. Write the trial's kubeconfig from it without switching anything:
   `kubectl config view --minify --flatten --context <ctx> > "$T/kubeconfig" && chmod 600 "$T/kubeconfig"`.
4. Refuse it if it already runs a Signadot operator, or if the check fails:
   `"$T/bin/kc" get deploy -A -l app.kubernetes.io/name=signadot-operator -o name` and
   `"$T/bin/kc" api-resources -o name | grep -i signadot` must both print nothing and succeed.

Record `cluster_mode: existing`, `created_kind_cluster: no` and `kube_context: <ctx>`. Use `<ctx>` wherever these
files say `kind-signadot-trial`. Skip the image pre-pull in §2 (it only works on kind).

On an existing cluster, never take over what was already there. Before creating any namespace (`hotrod`, a demo
app's, `signadot-tests`), check it:

```bash
"$T/bin/kc" get namespace <ns>
```

If it already exists and the trial log doesn't list it, stop and ask the user: it may hold their own work. Record
`namespace <ns>` under Resources only for namespaces the trial created, because teardown deletes everything listed
there. The infra files apply the same rule to a mesh that's already installed.

## 2. HotROD (`cluster`, part 2)

On Istio ambient, run the namespace commands from its file's "Overlay and operator values" first, with `<ns>` set
to `hotrod`.

```bash
OVERLAY=devmesh   # from the infra file: devmesh, istio, istio-ambient or linkerd
"$T/bin/kc" create namespace hotrod --dry-run=client -o yaml | "$T/bin/kc" apply -f -
"$T/bin/kc" -n hotrod apply -k "https://github.com/signadot/hotrod//k8s/overlays/prod/$OVERLAY?ref=b16178651580a8ba3ceb45ac7c59f4579611b0b3"
# Pre-pull the sandbox images on the kind node so sandboxes start quickly later.
for i in signadot/hotrod:f788b05bca80429425b814da62b2f17c3c564089-linux-amd64 \
         signadot/hotrod:97de62bf5a6d91482f62db23de565282ff97e60d-linux-amd64; do
  docker exec signadot-trial-control-plane crictl pull "$i" >> "$T/logs/prepull.log" 2>&1 &
done
"$T/bin/kc" -n hotrod wait --for=condition=available deploy --all --timeout=600s
"$T/bin/kc" -n hotrod rollout status statefulset/kafka --timeout=600s
"$T/bin/kc" -n hotrod rollout status statefulset/mysql --timeout=600s
```

The first start pulls about 3.5 GB of images; Kafka is the slowest. Every 30–60 s, tell the user what's still
pending (`"$T/bin/kc" -n hotrod get pods`). Done when every deployment is available and both statefulsets are
rolled out. Record `namespace hotrod` under Resources.

This is also when to start each chosen async demo app's deploy, so its images pull while you do the basics.
Temporal, RabbitMQ and Redis Streams come from `signadot/examples` at a pinned commit; fetch it once for all of
them, then run each chosen file's "Set up":

```bash
mkdir -p "$T/examples" && cd "$T/examples"
[ -d .git ] || { git init -q && git remote add origin https://github.com/signadot/examples.git; }
git fetch -q --depth 1 origin 26f759be92917adae40d9f928290863548d837fa && git checkout -q FETCH_HEAD
```

## 3. Operator (`operator`)

Run it once the CLI is logged in (`login` is `ok`) and HotROD is ready:

```bash
bash "$S/scripts/install-operator.sh" --trial-dir "$T" --cluster "signadot-trial<suffix>"   # plus the infra file's flags
```

It registers the cluster in the org, installs the operator (namespace `signadot`) with the cluster token passed
privately, waits until Signadot sees it, and restarts HotROD's four services so they get the routing proxy. Done when
it prints `operator_version: …` and `sidecars: 4/4`. Record the operator version under Run. Then open the
cluster's dashboard page, `https://app.signadot.com/cluster/<cluster>`, once in the user's browser, and link it in
your progress line ("Signadot sees your cluster: <link>"; SKILL.md, "Dashboard links"). If `sidecars` is short,
see troubleshooting.md. It's safe to re-run: it skips what's already done. The script installs the chart version the
skill was verified with; for installing the operator on a cluster of their own, the user follows
https://www.signadot.com/docs/installation/signadot-operator.md.

If you started a demo app's deploy before this step (its file's "Set up"), restart its deployments now so they get
the routing proxy too, or its sandbox stays Not Ready with `RoutingNotReady`:

```bash
"$T/bin/kc" -n <namespace> rollout restart deploy
```

## 4. Connection (`connect`)

The connection lets this computer reach services in the cluster. Write it into the trial's own CLI config,
`$T/home/.signadot/config.yaml` (the user's `~/.signadot` is never used). Replace any existing `local:` block and
keep the other keys:

```bash
CFG="$T/home/.signadot/config.yaml"
mkdir -p "$(dirname "$CFG")" && touch "$CFG"
awk '/^local:/ {skip=1; next} skip && /^[^ \t-]/ {skip=0} !skip' "$CFG" > "$CFG.new"
cat >> "$CFG.new" <<EOF
local:
  connections:
  - cluster: signadot-trial<suffix>
    type: PortForward
    kubeContext: kind-signadot-trial
    kubeConfig: $T/kubeconfig
EOF
mv "$CFG.new" "$CFG"
"$T/bin/sd" local connect --unprivileged
"$T/bin/sd" local status -o json | tr -d '\n ' | sed -n 's/.*"portforward":{[^}]*"localAddress":"\([^"]*\)".*/\1/p'
```

The last command prints the address of a local SOCKS proxy, e.g. `127.0.0.1:60123`. Record
`proxy: socks5h://<address>` and `connect_mode: unprivileged` under Run. Every request to a cluster service goes
through it (`curl --proxy socks5h://<address> …`, `ride.sh --proxy …`). Check:

```bash
curl -s -o /dev/null -w '%{http_code}\n' --proxy "socks5h://<address>" http://frontend.hotrod.svc:8080/
```

Done when it prints `200`.

**Privileged instead** (only if the user asked for cluster names to resolve on this computer): ask them to run
`"$T/bin/sd" local connect` in their own terminal; it asks for their sudo password once. Never type it yourself.
Then cluster names resolve on this computer: drop `--proxy` everywhere and record `connect_mode: privileged`.

The user may also switch to the privileged connection later, from a report page, or when you ask because a page's
main link is a cluster address (`references/finish/report.md`, "After each scenario").
Reconnecting moves the connection's proxy to a new address, so the recorded `proxy:` stops answering. If they say
so, or a request through the proxy fails, check the direct path:
`curl -s -o /dev/null -w '%{http_code}\n' http://frontend.hotrod.svc:8080/`. If it prints `200`, record
`connect_mode: privileged` and drop `--proxy` from then on. A running local-development route process keeps
working; if its sandbox link stops answering, start the process again with the commands in that file's Run.

`PortForward` is the direct path on a local cluster. `kubeContext` and `kubeConfig` point the CLI at the trial
cluster whatever the user's current context is, including when they reconnect with their own CLI or with sudo.
Connection settings: https://www.signadot.com/docs/getting-started/installation/signadot-cli.md (Connection
Configs); commands: https://www.signadot.com/docs/reference/cli/local.md.

## 5. Baseline ride (`baseline`)

```bash
bash "$S/scripts/ride.sh" --proxy "socks5h://<address>"
```

Done when it prints `completed: yes`, a plate, an ETA, and every hop as `baseline`. Explain in one line: "HotROD is a
ride-sharing demo; one ride goes through frontend, location, driver (via Kafka) and route." Record the step with the
plate and ETA.

Then create the baseline link: a route group that matches no sandbox, so its preview link always opens the unchanged
app. The report pages show it next to each sandbox's link.

```bash
"$T/bin/sd" routegroup apply -f "$S/assets/specs/core/hotrod-baseline.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" routegroup get hotrod-baseline<suffix> -o json | grep -oE '"url": *"https://[^"]+"' | head -1
```

The link can take a few seconds to appear; repeat the second command until it does. Record `routegroup
hotrod-baseline<suffix>` under Resources and `baseline_url: <the link>` under Run. Preview links open in any browser
signed in to the org: https://www.signadot.com/docs/reference/sandboxes/preview-urls.md.
