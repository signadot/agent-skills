# Run a service on this computer against the cluster

Runs by default. About 3 minutes, most of it the first build. Needs Go 1.27.1+ or Docker, and port 8083 free.
`<cluster>`, `<suffix>` and `<proxy>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD; route is the changed service, and it runs on this computer.
- **The change:** one line in route's code (`services/route/server.go`, the trial's patch) makes ETAs seconds
  instead of minutes. Then a second change, made during the scenario by the agent or the user (ETAs between 10 and
  20 seconds), is rebuilt, restarted and proven in seconds. Route is built and run on this computer; nothing is
  built into an image or deployed.
- **The sandbox:** a local sandbox: no pod in the cluster. It maps the cluster's route to the route process on this
  computer (port 8083), which uses the cluster's Redis. Also created: that local process and, with the no-sudo
  connection, a port-forward to Redis.
- **Routing:** the sandbox's preview link adds its key; OpenTelemetry carries it to driver's call to route; the
  sidecar in the normal route's pod forwards calls with the key through Signadot's connection to the process on this
  computer.

## Set up: fetch, patch and build

SKILL.md's flow starts this in the background right after the CLI is installed, so the first build overlaps signup. The patch changes one line in
`services/route/server.go`, so ETAs are in seconds instead of minutes.

```bash
mkdir -p "$T/hotrod" && cd "$T/hotrod"
[ -d .git ] || { git init -q && git remote add origin https://github.com/signadot/hotrod.git; }
git fetch -q --depth 1 origin b16178651580a8ba3ceb45ac7c59f4579611b0b3 && git checkout -q FETCH_HEAD
git apply --reverse --check "$S/assets/patches/route-eta.patch" 2>/dev/null || grep -q '(20-10) + 10' services/route/server.go \
  || git apply "$S/assets/patches/route-eta.patch"
```

Build with Go if preflight shows 1.27.1 or newer (HotROD's `go.mod` asks for 1.27.1). The variables keep Go's module
and build caches in the trial folder, writable so teardown can delete them:

```bash
cd "$T/hotrod" && mkdir -p .trial-bin && GOPATH="$T/go" GOCACHE="$T/go/cache" GOFLAGS=-modcacherw GOTOOLCHAIN=local \
  go build -o .trial-bin/hotrod ./cmd/hotrod && mv -f .trial-bin/hotrod "$T/bin/hotrod"
```

Otherwise build in a container as the user, with a module cache so rebuilds take about a second. `<os>` is
`darwin` or `linux` and `<arch>` is `amd64` or `arm64`, from preflight:

```bash
cd "$T/hotrod" && mkdir -p .trial-bin && docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/src" -w /src -e CGO_ENABLED=0 \
  -e GOCACHE=/src/.trial-cache/build -e GOMODCACHE=/src/.trial-cache/mod -e GOFLAGS=-modcacherw -e GOOS=<os> -e GOARCH=<arch> \
  golang:1.27.1 go build -o /src/.trial-bin/hotrod ./cmd/hotrod && mv -f .trial-bin/hotrod "$T/bin/hotrod"
```

Both build to a staging path and then move the binary into place with `mv`, never `cp`. On Linux, `cp` over a
running executable fails with "Text file busy"; on macOS (Apple Silicon), `cp` rewrites the signed binary in place and
the next start can be killed at launch ("Killed: 9"). `mv` replaces the file, so it's safe on both, even while the old
process is still running. Record the container build under Fallbacks. Done when `"$T/bin/hotrod" --help` runs.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/core/local-route.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get-env local-route<suffix> > "$T/local-route.env"
```

With the no-sudo connection, cluster names don't resolve on this computer, so give the local process Redis through
a port-forward on a free local port (not 6379, which developers often use for their own Redis):

```bash
PORT=""; for p in $(seq 16379 16399); do lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1 || { PORT=$p; break; }; done
[ -n "$PORT" ] || { echo "no free port in 16379-16399"; exit 1; }
echo "$PORT" > "$T/redis-pf.port"
nohup "$T/bin/kc" -n hotrod port-forward svc/redis "$PORT:6379" > "$T/logs/redis-pf.log" 2>&1 &
echo $! > "$T/redis-pf.pid"
```

Start the route service with the sandbox's environment (it reads the port from `$T/redis-pf.port`, so it works in a
new shell):

```bash
( set -a; . "$T/local-route.env"; set +a; export REDIS_ADDR="localhost:$(cat "$T/redis-pf.port")"   # skip REDIS_ADDR when privileged
  nohup "$T/bin/hotrod" route > "$T/logs/route-local.log" 2>&1 & echo $! > "$T/route-local.pid" )
```

Record `sandbox local-route<suffix>`, `process <pid> hotrod route (local-development)` and `portforward <pid> redis <port>:6379`
under Resources. Done when `lsof -nP -iTCP:8083 -sTCP:LISTEN` shows the process.

To stop the local processes (for the edit loop below, or at teardown), kill them only if their recorded PIDs still
belong to the trial; after a reboot a PID can belong to something else:

```bash
for f in route-local redis-pf; do p=$(cat "$T/$f.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF "$T/" && kill "$p"; done
```

## Prove it

```bash
bash "$S/scripts/ride.sh" --proxy <proxy>
bash "$S/scripts/ride.sh" --proxy <proxy> --key <local-route routing key>
```

Done when the ride without the key has an ETA in minutes (like `12m30s`), and the keyed ride has an ETA in seconds
with the hop `route local-route<suffix>`. The log `$T/logs/route-local.log` shows the request arriving. Lines about
exporting traces to `jaeger.hotrod` are harmless: there is no tracing backend in the trial. On a mesh (Istio ambient
especially), routing to the local process can take a few seconds to apply after the sandbox is ready: if the route
hop still shows `baseline`, book another keyed ride.

### Change the code and prove it again

The loop a developer runs with their agent: change the code, rebuild, restart, and prove the change through the
cluster with a keyed ride, with no image build or deploy. The `signadot-validate` agent skill runs the same loop on
their own services.

**Step by step,** first offer the user the change to make themselves, as they would ask their agent, in the result
message after the proof above:

```markdown
Route is running on your computer, and the cluster sends it only rides with your key. Now change its code the way
you would with your own service: send me this prompt, or edit it.

> Change route so every ETA is between 10 and 20 seconds, then rebuild, restart it and prove it with a keyed ride.

Or say "go on" and I'll make that change myself.
```

**All at once,** or on "go on", make that change yourself. Either way, time it from the edit to the proof:

1. **Edit** `$T/hotrod/services/route/server.go`: in `FindRoute`, change the ETA line to
   `eta := time.Duration((rand.Float64()*(20-10) + 10) * float64(time.Second))`. Show the user the changed line. (If
   they asked for a different change, make theirs, and adapt the check in step 4.)
2. **Build** with the same build command as Set up (it builds to the staging path and moves the binary into place).
3. **Restart:** stop the route process (the stop command above, or just its `route-local` PID), then start it again
   with the start command under Run.
4. **Prove it:** `bash "$S/scripts/ride.sh" --proxy <proxy> --key <local-route routing key>`.

Done when the keyed ride's ETA is between 10 and 20 seconds with the hop `route local-route<suffix>`, the new
process logs it (`Finding route` in `$T/logs/route-local.log`), and edit to proof took seconds. Then send the
scenario's result: the first proof, the change, and the timed loop.

## Record

```markdown
## Scenario local-development
status: passed
seconds: <apply to proof>
baseline: ETA <minutes>
sandbox: ETA <seconds>
hops-baseline: <hops line>
hops-sandbox: <hops line, route served by local-route<suffix>; draw it as a "box local">
proof: route ran on this computer for keyed requests; after the code change, the keyed ride's ETA was <10–20 s> and edit to proof took <n> s
change: <the changed line, or the user's own change>
commands: sd sandbox apply -f assets/specs/core/local-route.yaml …; sd sandbox get-env local-route<suffix>; hotrod route
specs: assets/specs/core/local-route.yaml, assets/patches/route-eta.patch
links: https://www.signadot.com/docs/tutorials/quickstart/local-development
try: edit <T>/hotrod/services/route/server.go, rebuild, restart, and book a ride on the sandbox's link
```

## Try it yourself

- **Baseline:** request a ride on the baseline link: ETAs in minutes.
- **Sandbox:** request a ride on the sandbox's link: ETAs in seconds, from route on this computer.
- **Check:** follow `Finding route` in the local process's log, `tail -f <T>/logs/route-local.log | grep --line-buffered 'Finding route'`,
  and in the normal route (`deploy/route`): sandbox rides appear only in the local log.
- **More:** another change, led by the agent. Put a prompt the user can give their agent first, for example: "Change
  route so every ETA is exactly 42 seconds, then rebuild, restart it and prove it with a ride through the sandbox's
  link." That's the same loop the `signadot-validate` agent skill runs for the user's own services. Then, collapsed
  as a fallback for doing it by hand, the commands: the build command, the stop command and the start command. If the process or the Redis port-forward stopped (after a reboot), the agent starts them again with the
  commands under Run.

## Tear down

```bash
for f in route-local redis-pf; do p=$(cat "$T/$f.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF "$T/" && kill "$p"; done
"$T/bin/sd" sandbox delete local-route<suffix>
```

## Docs

https://www.signadot.com/docs/tutorials/quickstart/local-development.md. The tutorial has a coding agent make the
change; the trial applies a one-line patch so the result is predictable, and uses the no-sudo connection with a
Redis port-forward.
