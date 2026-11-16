# Maintaining the signadot-trial skill

For people who change this skill. Agents don't read this file: SKILL.md doesn't link it, and a check keeps it that
way.

## How it's built

- `SKILL.md`: the interaction model (when to ask, defaults, prerequisites, guardrails), the flow, the menu and
  briefing, and an index that links every reference file.
- `references/`: one file per step or variation. Agents read only what the user chose.
- `scripts/`: four bash 3.2 scripts for steps that run on every trial (preflight, CLI install, operator install,
  booking a ride). No jq, python or node.
- `assets/`: Signadot specs (`@{suffix}` and `@{cluster}` are filled with `--set`), the C3 patch and the report
  template.
- `../../tests/signadot-trial/`: the checks (below).

Design rules: the skill works with any coding agent, so it never names one agent's tools; every variation runs on
open-source software only, with no cloud account; each demo app gets its own namespace; nothing expires, and
teardown runs only when the user asks.

## Adding a variation

1. Copy the closest file in `references/<category>/`. Variation files have these sections, in order:
   1. **What it shows:** the card copy: problem, what Signadot does, why it matters.
   2. **Costs:** time (`About N minutes`), memory, namespace.
   3. **Before you start:** requirements and choices.
   4. **Set up:** commands, each with "done when". Make them safe to run twice (resume and retries run them again).
   5. **Run:** the scenario's commands.
   6. **Prove it:** without key vs with key, "done when", and the hops or message path for the flow diagram.
   7. **Record:** the trial-log scenario entry.
   8. **Try it yourself:** lines for the hand-off.
   9. **Tear down:** commands that remove everything the file created.
   10. **Docs:** the docs page's markdown copy (`https://www.signadot.com/docs/<page>.md`) and where the trial
       differs from it.

   Infra files instead have: What it shows · Install before HotROD · Overlay and operator values · Mesh check ·
   Tear down · Docs.
2. Add a row to the SKILL.md index (the minutes must match Costs; a check compares them) and a line to the menu.
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
| HotROD | commit `b16178651580…` | `references/setup/cluster.md` (overlay), `references/core/local-development.md`, `assets/specs/testing/playwright-job.yaml`, `assets/specs/testing/hotrod-e2e-plan.yaml` |
| HotROD sandbox images | `signadot/hotrod:f788b05…`, `:97de62bf…` | `assets/specs/core/`, `references/setup/cluster.md` (pre-pull) |
| signadot/examples | commit `26f759be92…` | `references/setup/cluster.md` §2 |
| Go | 1.27.1 (HotROD's `go.mod`) | SKILL.md, `references/setup/prerequisites.md`, `references/core/local-development.md` |
| Playwright image | `v1.45.1-jammy` (HotROD's `package.json`) | `assets/specs/testing/` |
| Istio | 1.30.8 | `references/infra/istio.md`, `references/infra/istio-ambient.md` |
| Gateway API | v1.5.1 | `references/infra/istio-ambient.md` |
| Linkerd (edge) | 2026.11.2 | `references/infra/linkerd.md` |
| kind, helm (Linux install) | v0.33.0, v3.16.2 | `references/setup/prerequisites.md` |
| MariaDB (plugin runner) | 11.6 | `assets/specs/data/hotrod-trial-db-plugin.yaml` |

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
  `local status -o json`; `"id"` in `plan create` and `plan run` JSON.
- **Config:** the `local.connections` block (`type: PortForward`, `kubeContext`, `kubeConfig`).
- **Specs:** sandbox `forks`, `customizations.images|env`, `local` mappings, `resources`, `labels`; route group
  `match.any.label` and `endpoints`; resource plugin `runner`, `create`, `delete`, outputs; job runner group;
  job `routingContext` and `uploadArtifact`; plan `cluster.fromSandbox`, `routingContext.ref.sandboxRef`,
  `extraInputs`, `extraOutputs`, `output`.
- **Operator chart values:** `controlPlane.clusterToken`, `istio.enabled`, `linkerd.enabled`,
  `trafficManager.replicas`.
- **Dashboard and signup:** the signup page's Sign Up tab and "I've verified my email" button; the organization
  form's fields, "How did you hear about us" and Terms box; Platform → Managed Runners → cluster → Plan Runners;
  Settings → Plan Runner Actions → run-container → Allowed images; Settings → Clusters.
- **Docs pages** linked from each file's Docs section (a check confirms they resolve).

## Checks

```bash
tests/signadot-trial/run.sh            # everything (check-external needs the network)
tests/signadot-trial/run.sh --offline  # check-static and the three behavior tests
tests/signadot-trial/check-drift.sh    # fails when a newer CLI or operator chart is out
```

| Check | Guards against |
|---|---|
| `check-static.sh` | Unlinked or missing files, pins that disagree across files, invalid YAML or shell, bash features macOS lacks, missing report slots, zsh-unsafe snippets, and an edit dropping a safety command (teardown retiring the log, existing-cluster and existing-mesh checks, the plugin guard, no `plan delete`) |
| `test-token-not-logged.sh` | The cluster token reaching a log or the output. The stub mirrors CLI 1.9.1, which prints the token on stderr; check `internal/command/cluster/add.go` when the CLI pin moves |
| `test-config-blocks.sh` | The snippets that edit the user's Signadot config losing other keys, or teardown removing a block that isn't the trial's |
| `test-stale-pid.sh` | Stopping a recorded PID that now belongs to another process |
| `check-external.sh` | Moved docs pages, and pinned commits, images, releases, charts or downloads that no longer exist |
| `check-drift.sh` | Newer Signadot releases than the skill was verified with |

The checks look for commands and structure, never wording, so rewriting prose doesn't fail them. Add a check only
for a failure that would break the trial or touch something of the user's, and that an edit could plausibly cause.

CI (`.github/workflows/signadot-trial.yml`) runs `run.sh` on every pull request that touches the skill or its tests,
and weekly runs it with `check-drift.sh`. The checks can't prove the trial works end to end; that needs the live
checklist.

## Live checklist

Run it before a release and after bumping a pin, on a clean machine (or with `SIGNADOT_TRIAL_HOME` pointing to an
empty folder), with a coding agent following the skill literally. Use a test org.

1. **Default path:** "try Signadot", default choices, a new org. Core passes; report opens; hand-off lists what's
   running; the local proxy URL shows `SD-` plates in a browser.
2. **Existing user:** with a `~/.signadot` config and login present. The trial isolates its config; checksum
   `~/.signadot` before and after (`find ~/.signadot -type f -exec shasum {} + | sort | shasum`): unchanged.
3. **Every variation:** each infra option on a fresh cluster with C1–C3; then data, Kafka, Temporal, RabbitMQ,
   Redis Streams, Jobs and Plans (Plans needs the two org settings in `references/testing/plans.md`).
4. **Resume and retry:** stop mid-run and resume; rerun a variation's Set up (it must succeed twice).
5. **Teardown:** org lists are clean, the kind cluster is gone, `~/.kube/config` and the kube context are unchanged,
   the trial log is renamed, and a new "try Signadot" starts fresh.
6. **Another agent:** repeat the default path with a second coding agent product.

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
