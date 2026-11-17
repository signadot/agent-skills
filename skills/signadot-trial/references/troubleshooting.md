# Troubleshooting

Try the matching fix once, record what you did under Fallbacks, and move on. A failed scenario never blocks the
others. For symptoms not listed here, see https://www.signadot.com/docs/guides/troubleshooting.md. First look at the
state:

```bash
"$T/bin/sd" sandbox get <name> -o json        # status.message says what it's waiting for
"$T/bin/kc" -n <namespace> get pods
"$T/bin/kc" -n <namespace> describe pod <pod>  # events: image pulls, scheduling, memory, crash loops
"$T/bin/kc" -n <namespace> logs <pod> -c <container> --tail=50
```

## Setup

**Docker isn't running, or has too little memory.** Preflight shows `docker: stopped` or a small `docker_mem_gb`.
Ask the user to start Docker or raise its memory (`references/setup/prerequisites.md`), or drop add-ons.

**Image pulls are slow.** HotROD's first start pulls about 3.5 GB (Kafka is the largest); the Playwright runner about
2 GB. Keep narrating what's pending (`get pods`) rather than failing; the waits allow 10 minutes.

**Pods stay `Pending`, or restart with `OOMKilled`.** The node is out of memory: `describe pod` shows "Insufficient
memory" or the last state `OOMKilled`. Remove an add-on you've finished with (its "Tear down"), or ask the user to
raise Docker's memory.

**`install-operator.sh` shows fewer sidecars than workloads.** Pods get the proxy only when they restart after the
operator is installed. Re-run the script; it restarts them again and re-counts. To see which workloads lack it and
why: `"$T/bin/sd" cluster devmesh analyze --cluster <cluster> --namespace hotrod`.

**A Signadot command fails with "Authentication expired".** The CLI login has expired (common when resuming a trial
a day later; `auth status` shows `Expired:`). Run the login again (`references/setup/account.md` §2), then retry.

**The login shows the wrong account, or never finishes.** The confirmation page uses whichever Signadot account the
browser is signed in to. Use the browser from signup; if it's another account, sign out there and start the login
again. The trial's login uses `--insecure-storage`, so no keychain dialog should appear; if one does, cancel it and
start the login again with that flag.

**Another local connection is running.** Only one can run per computer, across orgs and CLI installs. If preflight
doesn't mark it `(trial)`, the user disconnects it with their own CLI (`signadot local disconnect`; if their login
expired, `signadot auth login` first). Record `disconnected_user_connection: yes`.

**The frontend doesn't answer 200 through the connection.** Give it up to a minute after connecting. Check
`"$T/bin/sd" local status` says healthy and names `signadot-trial<suffix>`; read the proxy address again (it changes
on every connect). The connection needs `kubeContext: kind-signadot-trial` and `kubeConfig: <T>/kubeconfig` in the
CLI config the trial uses.

**`sandbox get-env` fails with "not found".** The connection's `kubeContext` or `kubeConfig` is missing or wrong, so
the CLI looks for the workload in another cluster. Fix the `local:` block, then `sd local disconnect` and connect again.

## Scenarios

**A sandbox stays Not Ready with `RoutingNotReady: DevMesh Sidecar absent on baseline <ns>/<deployment>`.** The
baseline started before the operator was installed, so it has no routing proxy. Restart it:
`"$T/bin/kc" -n <ns> rollout restart deploy`; the sandbox turns Ready within seconds.

**An apply fails with a limit, such as "can't go over" a number of clusters or sandboxes.** The org is at one of its
plan's limits, which is likely in an existing org. Delete sandboxes or clusters it no longer needs, or ask the user
which to remove; see https://www.signadot.com/docs/guides/admin/quotas-limits.md.

**A sandbox doesn't become ready.** Read `status.message`, then `describe` its pod (fork pods are named
`<sandbox>-dep-<workload>-…`). HotROD's sandbox images are amd64; on Apple Silicon they run under emulation, which
starts more slowly but works.

**A keyed request still reaches the baseline.** Make sure the header is exactly `baggage: sd-routing-key=<key>`, and
that the snippet passed it as its own argument (copy the snippets as written: they avoid shell constructs that
behave differently in bash and zsh). Right after a sandbox becomes ready, give routing a few seconds.

**A sandboxed consumer or worker doesn't take its message.** Async consumers refresh their routing rules on a timer:
about 10 seconds in the trial's demo apps. Wait, then send the message again.

**local-development: port 8083 is busy.** `lsof -nP -iTCP:8083 -sTCP:LISTEN` shows what holds it. Stop the trial's own process
(the guarded stop command in `references/core/local-development.md`), or ask the user about another one.

**local-development: the build fails.** Without Go 1.27.1+, the build runs in Docker (`golang:1.27.1`); make sure Docker is running.
The first container build downloads modules (about a minute); later ones take seconds.

**local-development: keyed rides stop at "Resolving routes".** The local route service can't reach Redis. With the no-sudo
connection it needs the Redis port-forward and `REDIS_ADDR=localhost:<port>`; check `$T/logs/redis-pf.log` and
`$T/logs/route-local.log`. Lines about exporting traces to `jaeger.hotrod` are harmless.

**A demo app's image build or load fails.** The build needs Docker and network access. `kind load docker-image` only
works on a kind cluster; on another local cluster, use its own image-load command (for example
`minikube image load`).

## Testing

**A job's log says "The execution has been restarted".** The log stream reconnected and replayed; the job ran once.
Check `"$T/bin/sd" job get <job name>`.

**A job's artifacts aren't listed yet.** They're uploaded just after the job finishes; run `job get` again a few
seconds later.

**`plan run` fails with "no plan runner group on cluster".** The plan runner org setting isn't on for this cluster
(`references/testing/plans.md` "Before you start"). It takes about a minute to start after it's enabled.

**A plan step fails on an image policy.** The org doesn't allow `mcr.microsoft.com/playwright:*` for `run-container`
yet (same section).

**A plan step fails at start with "operation not permitted" (Linux).** On Ubuntu 23.10 or newer, AppArmor stops
the unprivileged user namespaces that plan steps run in, and a kind node inherits the host's setting (preflight shows
`apparmor_userns: restricted`). The user runs `sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0` on the host;
never run sudo yourself. Then run the plan again. See
https://www.signadot.com/docs/reference/plans/cluster-requirements.md.

**A plan run is `failed`, but `plan execution get-output <id> exit_code` prints `0`.** The tests passed; uploading the
report afterwards failed (the run's error says "artifact upload failed … unexpected EOF"). Run the plan again.

## Meshes

**`install-operator.sh` stops with "operator deployments not available", or mesh pods stay `Pending`.** On a
single-node cluster, Istio's default requests (istiod asks for 2 GiB, each sidecar 128 MiB) and the operator's two
traffic-manager replicas don't fit. `describe pod` shows "Insufficient memory". Install the mesh with the infra
file's resource flags and `trafficManager.replicas: 1` from the start. On a cluster where the mesh is already
installed, run the infra file's helm commands again (they upgrade in place), then delete the old, larger pod so the
new one can schedule.

**Sandboxes on Istio ambient stay Not Ready with `RoutingNotReady`.** A forked service has no route object: the
operator adds sandbox routes to HotROD's VirtualServices, so check they exist (`"$T/bin/kc" -n <ns> get
virtualservices`, where `<ns>` is `hotrod` or `hotrod-ambient`) and that the operator values have `istio.enabled:
true`.

**On Istio ambient, a sandbox is Ready but keyed requests still reach the baseline.** No waypoint is applying the
routes. Check that HotROD's namespace has `istio.io/dataplane-mode=ambient` and `istio.io/use-waypoint=waypoint`,
and that the `waypoint` Gateway's pod is running.
