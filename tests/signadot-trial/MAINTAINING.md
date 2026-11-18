# Maintaining the signadot-trial skill

For people who change `skills/signadot-trial`. This file lives next to the checks, outside the skill folder, so it
isn't installed with the skill. Paths below are relative to `skills/signadot-trial/` unless they start with `tests/`
or `.github/`.

## How it's built

- `SKILL.md`: the interaction model (when to ask, defaults, prerequisites, guardrails), the flow, the plan, the menu of more
  scenarios, and an index that links every reference file.
- `references/`: one file per step or variation. Agents read only what the user chose.
- `scripts/`: four bash 3.2 scripts for steps that run on every trial (preflight, CLI install, operator install,
  booking a ride). No jq, python or node.
- `assets/`: Signadot specs (`@{suffix}` and `@{cluster}` are filled with `--set`), the local-development patch,
  the report templates in `assets/report/` (the overview page, the scenario page, the fit page and their shared
  CSS), and `assets/fit/compatibility.md`, the matrix the fit page takes every status from.
- `tests/signadot-trial/`: this file and the checks (below).

Nothing else belongs in the skill folder: everything there is installed for every user, and a check fails on any
other top-level file.

Design rules: the skill works with any coding agent, so it never names one agent's tools; every variation runs on
open-source software only, with no cloud account; each demo app gets its own namespace; nothing expires, and
teardown runs only when the user asks. Everything the trial creates stays in its folder (`.signadot-trial` in the
agent's working folder): the CLI's config and login, the kubeconfig, tool caches, builds and the report, so the
agent needs no access outside it and `~/.signadot` is never touched. The user sees the menu's words (the basics,
add-ons), never file names, step IDs or section numbers.

## Adding an add-on

1. Copy the closest file in `references/<category>/`. Variation files have these sections, in order:
   1. **What it shows:** the card copy: problem, what Signadot does, why it matters.
   2. **Costs:** time (`About N minutes`), memory, namespace.
   3. **Before you start:** requirements and choices.
   4. **Set up:** commands, each with "done when". Make them safe to run twice (resume and retries run them again).
   5. **Run:** the scenario's commands.
   6. **Prove it:** without key vs with key, "done when", and what the page's diagram shows (which services get a
      sandbox copy, and where the routing decision is made).
   7. **Record:** the trial-log scenario entry.
   8. **Try it yourself:** lines for the hand-off.
   9. **Tear down:** commands that remove everything the file created.
   10. **Docs:** the docs page's markdown copy (`https://www.signadot.com/docs/<page>.md`) and where the trial
       differs from it.

   Infra files instead have: What it shows · Install before HotROD · Overlay and operator values · Mesh check ·
   Tear down · Docs.
2. Add a row to the SKILL.md index (the minutes must match Costs), a numbered line to the menu that says in plain
   words what Signadot does in it (for someone new to Signadot), and its number in the menu-to-file list. The
   message before more scenarios draws on its "What it shows".
3. Put specs in `assets/specs/<category>/`, named `<name>@{suffix}` (30 characters or fewer with a suffix), with no
   TTL.
4. Run it live on kind by following the file literally, then run the checks.

## What's pinned

Bump a pin deliberately: change it everywhere it appears, run the live checklist below, and update
`metadata.verified` in SKILL.md's frontmatter.

| What | Pinned to | Where |
|---|---|---|
| Signadot CLI | 1.9.1 | `scripts/install-cli.sh` (`VERSION`), SKILL.md, `references/setup/prerequisites.md` |
| Signadot Operator chart | 1.4.0 | `scripts/install-operator.sh` (`OPERATOR_VERSION`) |
| HotROD | commit `b16178651580…` | `references/setup/cluster.md` (overlay), `references/infra/add-mesh.md` (overlay), `references/core/local-development.md`, `assets/specs/testing/playwright-job.yaml`, `assets/specs/testing/hotrod-e2e-plan.yaml` |
| HotROD sandbox images | `signadot/hotrod:f788b05…`, `:97de62bf…` | `assets/specs/core/`, `references/setup/cluster.md` (pre-pull) |
| signadot/examples | commit `26f759be92…` | `references/setup/cluster.md` §2 |
| Go | 1.27.1 (HotROD's `go.mod`) | SKILL.md, `references/setup/prerequisites.md`, `references/core/local-development.md` |
| Playwright image | `v1.45.1-jammy` (HotROD's `package.json`) | `assets/specs/testing/` |
| Istio | 1.30.8 | `references/infra/istio.md`, `references/infra/istio-ambient.md` |
| Gateway API | v1.5.1 | `references/infra/istio-ambient.md` |
| Linkerd (edge) | 2026.11.2 | `references/infra/linkerd.md` |
| kind, helm (Linux install) | v0.33.0, v3.16.2 | `references/setup/prerequisites.md` |
| MariaDB (plugin runner) | 11.6 | `assets/specs/data/hotrod-trial-db-plugin.yaml` |
| Compatibility matrix | `Retrieved:` date | `assets/fit/compatibility.md`: re-read the docs index and every cited page; a Signadot reviewer signs off status changes and the "Gaps / unclear" section |

## Product details the skill depends on

If you change one of these in Signadot, search this skill for it first.

- **CLI commands and flags:** `auth login --insecure-storage`, `auth status`, `cluster add|list|token create`,
  `cluster devmesh analyze`, `local connect --unprivileged|status|disconnect|proxy`, `sandbox apply --set|get|get-env|delete`,
  `routegroup apply|get|delete`, `resourceplugin get|apply|delete`, `jobrunnergroup apply|delete|list`,
  `job submit --attach|get`, `artifact download --job`, `plan action get|create --set|tag apply|get|delete|run --tag --param`,
  `plan execution get|get-output|logs`, `mcp`.
- **CLI output the skill parses** (with sed, not jq): the `Organization:` line of `auth status`; `"routingKey"` in
  `sandbox get -o json`; `"name"` and `"operator":{"version"}` in `cluster list -o json`; `"token"` in
  `cluster token create -o json`; `token='…'` in `cluster add`; `"portforward":{"localAddress"}` in
  `local status -o json`; `"id"` in `plan create` and `plan run` JSON (a failing `plan run` prints its JSON on
  stderr in CLI 1.9.1, so the skill captures `2>&1`).
- **Config:** the `local.connections` block (`type: PortForward`, `kubeContext`, `kubeConfig`).
- **Specs:** sandbox `forks`, `customizations.images|env`, `local` mappings, `resources`, `labels`; route group
  `match.any.label` and `endpoints`; resource plugin `runner`, `create`, `delete`, outputs; job runner group;
  job `routingContext` and `uploadArtifact`; plan `cluster.fromSandbox`, `routingContext.ref.sandboxRef`,
  `extraInputs`, `extraOutputs`, `output`.
- **Operator chart values:** `controlPlane.clusterToken`, `istio.enabled`, `linkerd.enabled`,
  `trafficManager.replicas`.
- **Dashboard and signup:** the signup page's Sign Up tab and "I've verified my email" button; the organization
  form's fields, "How did you hear about us" and Terms box; Platform → Managed Runners → cluster → Plan Runners;
  Settings → Plan Runner Actions → run-container → Allowed images (Add saves at once; Apply stays greyed out);
  Settings → Clusters.
- **Demo images:** the RabbitMQ demo's published images are arm64-only, so on amd64 the skill builds them locally;
  arm64 (Apple Silicon) pulls them as published. If `signadot/examples` publishes multi-arch images, the build in
  `references/async/rabbitmq.md` can go.
- **Docs pages** linked from each file's Docs section (a check confirms they resolve).

## Checks

```bash
tests/signadot-trial/run.sh            # everything (check-external needs the network)
tests/signadot-trial/run.sh --offline  # check-static and the three behavior tests
tests/signadot-trial/check-drift.sh    # fails when a newer CLI or operator chart is out
```

| Check | Guards against |
|---|---|
| `check-static.sh` | Unlinked or missing files, pins that disagree across files, invalid YAML or shell, bash features macOS lacks, missing slots in either report template, zsh-unsafe snippets, files or caches landing outside the trial folder (it runs preflight and `install-cli.sh` with a stub CLI and an empty HOME), and an edit dropping a safety command (teardown retiring the log, existing-cluster and existing-mesh checks, the plugin guard, no `plan delete`) |
| `test-token-not-logged.sh` | The cluster token reaching a log or the output. The stub mirrors CLI 1.9.1, which prints the token on stderr; check `internal/command/cluster/add.go` when the CLI pin moves |
| `test-config-blocks.sh` | The connection snippet losing other keys in the trial's CLI config, or not naming the trial's kubeconfig, context and cluster |
| `test-stale-pid.sh` | Stopping a recorded PID that now belongs to another process |
| `check-external.sh` | Moved docs pages, and pinned commits, images (including Istio's on Docker Hub), releases, charts or downloads that no longer exist |
| `check-drift.sh` | Newer Signadot releases than the skill was verified with |

The checks look for commands and structure, never wording, so rewriting prose doesn't fail them. Add a check only
for a failure that would break the trial or touch something of the user's, and that an edit could plausibly cause.

CI (`.github/workflows/signadot-trial.yml`) runs `run.sh` on every pull request that touches the skill or its tests,
and weekly runs it with `check-drift.sh`. The checks can't prove the trial works end to end; that needs the live
checklist.

## Live checklist

Run it before a release and after bumping a pin, on a clean machine or at least with the agent started in an empty
folder, with a coding agent following the skill literally. Use a test org.

To test a pull request before merging, install the skill from its branch, with the branch after `#` in a git URL
(a tree URL breaks on a branch name with a slash, and `owner/repo@x` means the skill named `x`, not a ref):

```bash
npx skills add "https://github.com/signadot/agent-skills.git#<branch>" --skill signadot-trial
```

The CLI records the branch, so `npx skills update` in the same folder later picks up the branch's newest commit. To
pin one commit instead, use a tree URL with the full 40-character SHA (a short SHA fails):
`npx skills add https://github.com/signadot/agent-skills/tree/<full commit SHA>/skills/signadot-trial`.

1. **Default path:** "try Signadot", default choices, a new org. The first message is the plan (the three basics),
   the basics run one by one with a menu of more after them, and progress lines show no file names or step IDs. The basics pass; each scenario's page opens after it and the trial waits before the next one; the hand-off
   lists what's running; the first sandbox's preview link gives 1s ETAs and the baseline link doesn't; every page has the
   same four sections (the demo app, the change, the sandbox, test it yourself), every try-it step works as written
   (baseline flow, sandbox flow, the check shows which version handled each), and command blocks copy. After the page's sudo reconnect,
   its curl to `frontend.hotrod.svc` prints a 1s ETA with the key and minutes without, and the agent's next scenario
   still works (it notices the reconnect and drops its proxy). The agent never asks for access
   outside its working folder, and afterwards the only new thing there is `.signadot-trial`.
2. **Existing user:** with a `~/.signadot` config and login present. The trial uses its own login in the trial folder; checksum
   `~/.signadot` before and after (`find ~/.signadot -type f -exec shasum {} + | sort | shasum`): unchanged.
3. **Every variation:** each infra option on a fresh cluster with the basics; then, after the default basics, the
   meshes added next to them: Istio, Istio ambient beside it, then the switch to Linkerd. Each mesh's copy proves
   routing, and the basics' keyed ride still reaches `fast-route` after each. Then data, Kafka, Temporal, RabbitMQ,
   Redis Streams, Jobs and Plans (Plans needs the two org settings in `references/testing/plans.md`). Each page's
   diagram puts the decision where the routing makes it: the sidecar inside the normal pod of the called service
   (DevMesh, Linkerd), the Envoy sidecar inside the caller's pod (Istio), the waypoint in front of the called
   service (ambient), nothing for messages and workflows. For Temporal, Redis Streams and RabbitMQ, the demo app's
   UI opens through its tools preview link, with no sudo reconnect.
4. **Resume and retry:** stop mid-run and resume; rerun a variation's Set up (it must succeed twice).
5. **Teardown:** org lists are clean, the kind cluster is gone, `~/.kube/config` and the kube context are unchanged,
   the trial log is renamed, and a new "try Signadot" starts fresh.
6. **Another agent:** repeat the default path with a second coding agent product.
7. **Customized path:** "try Signadot", choose "I already have an account" and then, on a second run, "Create a new
   account": each gets the matching steps, and the login message says to sign in after Confirm. Choose Customize and
   answer the five questions in your own words, with a mesh and two brokers (one with a demo, one without). The plan
   installs the mesh during setup, suggests the right add-ons, names the broker without a demo, and asks "step by
   step or all at once". Step by step: what's left after each scenario is a list, one per line. All at once: no
   pauses except the steps only the user can do, then a summary. The hand-off writes `fit.html` ("Is Signadot a
   good fit?", a verdict and every status from the matrix with a guide link per row), the overview shows the
   verdict with a button to it, then it asks "anything else?". Ask about pricing and a competitor: the answers cite
   `/pricing/` and `/comparison/<tool>/`. On the standard path there's no fit page; the overview shows the fit
   checklist. The agent never reads files outside its working folder.
8. **WSL:** the default path and one demo-app add-on on Windows with WSL2 and Docker Desktop. Preflight shows
   `wsl: yes`; pages and the login link open in the Windows browser (`explorer.exe`), not a Linux browser inside
   WSL; every link the user is asked to open is a preview link; RabbitMQ's images build for amd64.
9. **Apple Silicon Mac:** the default path and RabbitMQ on an arm64 Mac. RabbitMQ pulls its published images with no
   local build; the local-development edit loop starts the new binary (no "Killed: 9") and the next keyed ride
   reaches it.

Change signals worth watching: CLI releases (`https://api.github.com/repos/signadot/cli/releases/latest`), the
operator chart index (`https://charts.signadot.com/index.yaml`), the docs release notes
(`https://www.signadot.com/docs/release-notes.md`) and the docs index (`https://www.signadot.com/docs/llms.txt`).

## Ideas not built yet

- A scheduled live run in CI: kind on a runner, a test org, and an agent running every variation. It needs a CI mode
  that skips signup and logs in with an API key (the CLI wrapper deliberately ignores `SIGNADOT_API_KEY` today, so
  it would be an explicit `SIGNADOT_TRIAL_API_KEY`).
- An "agent loop" step: the user asks their agent to change the route service and validate it with the
  `signadot-validate` skill on the trial cluster. It works today only for new users with the CLI on PATH and the
  sudo connection.
