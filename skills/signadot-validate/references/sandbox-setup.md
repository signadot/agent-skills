# Sandbox Setup Reference

## Contents

- Discovery and confirmation
- Devbox detection
- Reuse before create
- Creating or updating a sandbox
- Env and config reconstruction
- Starting the service
- Shell portability

## Discovery And Confirmation

Use MCP tools when available; use CLI fallbacks otherwise. Search by intent:
cluster listing, sandbox listing/get/create/update, routegroup inspection,
workload resolution, endpoint resolution, and devbox listing.

Common MCP tool names include `list_clusters`, `resolve_workload`,
`resolve_workload_port`, `list_devboxes`, `list_sandboxes`, `create_sandbox`,
`get_sandbox`, and auth/identity tools; discover the actual names and schemas
at runtime. Calling a tool before its schema is loaded may fail with
`InputValidationError` or another input validation error.

Always honor confirmation flags or ambiguous results. Some MCP responses expose
this as `requiresConfirmation`:

- Multiple clusters: show the list and ask the user to pick one.
- Multiple workloads: show candidates and ask; do not auto-select.
- Multiple devboxes: show candidates and ask.

If using CLI fallbacks, prefer repo-owned `.signadot/` specs over freshly
invented specs. Use `kubectl get` only when MCP/Signadot CLI cannot return the
needed object.

Resolve workloads with a single-term query when the MCP resolver expects one.

## Devbox Detection

If the current environment is a Signadot devbox, run the service there and skip
`signadot local connect`.

Check:

```bash
grep -c '^242\.242\.' /etc/hosts
hostname
```

Non-zero `242.242.x.x` entries are a strong signal that in-cluster names are
injected locally. Compare `hostname` with the devbox names returned by the
Signadot devbox listing. If the host has Signadot entries but does not match a
known devbox, show the mismatch to the user instead of guessing.

Use the confirmed devbox ID as `connection.devboxId` for local workloads.

## Reuse Before Create

List live sandboxes scoped to the same user and workload. Reuse one that is
ready and has a connected tunnel. Reuse keeps the routing key stable for env
vars, existing curls, browser scripts, and tagged plan params.

Then check the repo for sandbox definitions:

```bash
ls .signadot/
ls .signadot/dev/
```

If a matching definition exists, use it and substitute any devbox placeholder
with the confirmed devbox ID. Fall back to creating from scratch only when no
live sandbox or repo spec fits.

## Creating Or Updating A Sandbox

If MCP provides workflow documentation for sandbox creation, read it before
calling create/update. When available, call `get_workflow_docs` with
`topic: "creating_sandbox"` before creating a sandbox. Key requirements:

- `connection.devboxId` is required for local workloads.
- The `from` workload must come from workload resolution output.
- The sandbox mapping port is the workload/container port, not the Service port.
- Do not add public preview endpoints unless the user explicitly asks.

After create/update, poll until both are true:

- `status.ready = true`
- the local tunnel is `connected: true`

A ready sandbox with a disconnected tunnel will not route traffic to the local
process.

## Env And Config Reconstruction

Read repo docs first: `README`, Makefiles, package scripts, Dockerfiles,
service-specific docs, and any local development notes the repository provides.
Treat repo docs as the source of truth for run commands and env var names.

Try the automated Signadot pull. `get-env` may require `~/.kube/config`:

```bash
eval $(signadot sandbox get-env <sandbox-name>)
signadot sandbox get-files <sandbox-name>
```

If unavailable, reconstruct from the workload spec. With MCP, fetch the workload
through the workload-object tool (commonly named `get_workload_object`) and use
the same tool for referenced ConfigMaps and Secrets.

| Entry type | Resolution |
|---|---|
| Literal `value` | Export as-is |
| `configMapKeyRef` | Fetch the named ConfigMap key |
| `secretKeyRef` | Fetch the named Secret key, base64-decode, do not print |
| `envFrom.configMapRef` | Fetch all ConfigMap keys |
| `envFrom.secretRef` | Fetch all Secret keys, base64-decode, do not print |
| `fieldRef` / `resourceFieldRef` | Pod-injected values such as `POD_NAME`, `POD_IP`, or `status.hostIP`; use plausible local values, or run in devbox if real pod identity is required |

Resolve service-to-service addresses explicitly. Grep for config lookups such as
`*_ADDR`, `*_HOST`, `*_URL`, `GetXxxAddr`, and language-specific helpers.
Convert in-cluster defaults such as `other-svc:8081` to resolvable `.svc`
addresses when the local process needs them.

## Starting The Service

Find the repo's normal start command before running anything. Check Makefiles,
package scripts, Dockerfiles, service READMEs, and scripts directories. For
frontends or compiled UIs, prefer repo build scripts or Make targets over raw
`npm run build` / `yarn build` when those scripts perform asset path rewriting,
file copying, or other post-processing.

Build or compile in the foreground first so errors are visible. Kill only the
specific process or port you own, then start the new process and verify:

- process is alive
- expected port is listening
- primary data endpoint responds, not just `/healthz`

Port conflicts and stale background processes often look like app bugs. Defunct
processes can also confuse `pgrep`, so verify the listener and log, not just the
process name.

## Shell Portability

Choose process-management commands for the current OS:

| Task | Linux/devbox | macOS |
|---|---|---|
| Find listener | `ss -ltnp` or `lsof -nP -iTCP:<port> -sTCP:LISTEN` | `lsof -nP -iTCP:<port> -sTCP:LISTEN` |
| Stop owned listener | `fuser -k <port>/tcp` or `kill <pid>` | `kill <pid>` |
| Keep process alive | `setsid ./start.sh >> /tmp/svc.log 2>&1 &` or `nohup` | `nohup ./start.sh >> /tmp/svc.log 2>&1 &` |

Never use a broad kill pattern that can stop unrelated user processes. Capture
PIDs and log paths so final cleanup is precise.
