# Signadot Agent Skills

Skills for AI coding agents to work with [Signadot](https://www.signadot.com).
They give the agent structured workflows for planning and validating
changes against real Kubernetes microservice dependencies.

## Install

The skills follow the [Agent Skills specification](https://agentskills.io/specification),
a vendor-neutral `SKILL.md` format. Install into any
[supported agent](https://github.com/vercel-labs/skills#supported-agents)
with the [`skills`](https://github.com/vercel-labs/skills) CLI.

Install everything:

    npx skills add signadot/agent-skills

Or install skills individually — see below. Add `-g` to install globally
and `-a <agent>` to target a supported runtime. The skill is picked up
on next start and triggers when the conversation matches its scope.

## Skills

### `signadot-install`

Install and configure Signadot in a cluster: CLI, Operator (Helm),
authentication, routing (DevMesh / Istio / Linkerd / Gateway API),
and CLI config for local development.

    npx skills add signadot/agent-skills --skill signadot-install

### `signadot-validate`

Validate code changes against real Kubernetes microservice dependencies
using Signadot signals: local sandboxes, cluster reachability, logs,
endpoints, and routing-key isolation.

    npx skills add signadot/agent-skills --skill signadot-validate

### `signadot-plan`

Author and iterate on Signadot plan specs: discover schema and actions,
compose params and steps, run plans, and inspect outputs and logs.

    npx skills add signadot/agent-skills --skill signadot-plan

## Requirements

- An AI coding agent
- The Signadot CLI, configured against your cluster

## License

Apache 2.0 — see [LICENSE](LICENSE).
