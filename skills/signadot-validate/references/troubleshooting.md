# Troubleshooting Reference

## Contents

- Fast symptom table
- Port and routing mistakes
- Env var failures
- Routing-key propagation
- Async protocols
- Browser failures
- Process and gRPC issues

## Fast Symptom Table

| Symptom | Likely cause | Check |
|---|---|---|
| Envoy 503 from devbox, pod healthy | Used container port for `.svc` traffic | Service object or endpoint resolver |
| Ready sandbox, connected tunnel, no local traffic | Sandbox mapping used wrong container port | `/etc/hosts` virtual sandbox entry |
| Response is fast and old-looking | Request reached baseline | URL, routing headers, propagation |
| First real request returns 500 | Missing env or bad dependency address | Exported env and config lookup sites |
| Browser blanks after click | Frontend runtime error | Console errors and body/accessibility state |
| Downstream sandbox log is quiet | Routing key dropped before downstream | Sync or async propagation path |
| Background service exits soon, sometimes code 144 | SIGHUP, port conflict, missing env | PID, listener, log file |
| gRPC dial stalls around 30s | Go gRPC SRV lookup delay | `passthrough:///` and connection reuse |

## Port And Routing Mistakes

Two port rules are easy to mix up:

- Sandbox mapping uses the workload/container port.
- Validation traffic uses the Kubernetes Service port.

If the sandbox is ready but requests go to baseline, verify the mapping port and
look for a virtual sandbox host in `/etc/hosts`. If curl to `.svc` returns Envoy
503 while the pod is healthy, verify the Service port.

Do not "fix" routing by pointing a proxy, gateway, or upstream env var at
`localhost:<port>`. That bypasses the cluster path, hides the propagation bug,
and silently breaks the service for any consumer not running on the same
devbox. Always fix propagation at the hop that drops the routing key — copy
the incoming `baggage` and any cluster custom headers onto outbound requests,
or switch the call site to the service's existing instrumented client.

## Env Var Failures

A local service can start successfully and still fail on the first real request
because a dependency address, credential, or feature flag is missing.

Actions:

- Grep for every config lookup related to addresses and credentials.
- Compare env vars from the baseline workload spec, ConfigMaps, and Secrets.
- Convert in-cluster service defaults to resolvable `.svc` addresses.
- Redact secret values in all summaries and logs.
- Restart after changing env; many services read config only at startup.

## Routing-Key Propagation

For synchronous HTTP/gRPC, propagation is automatic only when the service uses
instrumented clients or sidecars that forward routing context, such as an
`otelhttp`-wrapped transport, a gRPC interceptor, or an Istio/Envoy sidecar with
tracing enabled. Raw clients often drop the key:

- Go `http.DefaultClient.Do`
- Node `fetch`
- Python `requests.get`
- handwritten gRPC clients without interceptors

For new proxy, gateway, or forwarder code, assume propagation is missing until
proven otherwise. Copy incoming `baggage` and any cluster custom routing headers
onto outbound requests, or use the service's existing instrumented client.

Diagnostic signal: direct calls to the local service work, but a proxied path
returns stale data or 404s that match the baseline service.

## Async Protocols

For Kafka, SQS, RabbitMQ, pub/sub systems, and job queues, routing context is
never automatic unless the app explicitly implements it.

Check:

- producer writes routing key into message headers/metadata
- consumer reads headers/metadata and restores request context
- sandboxed consumer logs show activity for the routed request

If messages lack routing metadata, baseline consumers may process them and make
the test appear to pass against the wrong code.

## Browser Failures

A passing API response is not enough for UI changes. Browser checks catch:

- stale bundles or wrong build command
- blank UI after JavaScript exception
- type drift between backend and frontend
- fields populated in API but not rendered
- route hook missing headers for navigation or XHR/fetch requests

After each interaction, inspect console errors and verify body text or the
accessibility tree is still populated. A healthy SPA generally has substantial
HTML content; an empty root or tiny `page.content().length` after a click
usually means an unhandled runtime error. One common trigger is wire-type drift,
such as comparing a numeric ID to a string ID and then dereferencing an
undefined result.

If a shared type or API changed, rebuild and restart every affected local
process, not just the service inspected most recently.

## Process And gRPC Issues

Background processes can die from SIGHUP, missing env, or port conflicts. Build
in the foreground, start with `setsid` or `nohup` as appropriate for the OS, and
verify the PID, listener, and log file after every restart.

Go gRPC clients can spend about 30 seconds on SRV DNS lookups for targets that
do not publish `_grpclb._tcp` records. Mitigations:

- Prefix fresh targets with `passthrough:///`, for example
  `passthrough:///cartservice.ns.svc:7070`.
- Dial once at startup and reuse the connection.

`passthrough:///` helps only on fresh dials; it does not change connections
already opened at process start.
