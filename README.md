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

### `signadot-trial`

Try Signadot hands-on, end to end, from your coding agent. It signs you up, sets
up a local kind cluster with the HotROD demo app, and proves each capability by
sending the same request with and without a routing key: one service in
isolation, a multi-service preview URL, and a service running on your computer.
Optional variations cover Istio, Istio ambient and Linkerd, a database per
sandbox, Kafka, Temporal, RabbitMQ and Redis Streams, and test automation with
Jobs and Plans. It ends with an HTML report and leaves everything running until
you ask for teardown.

    npx skills add signadot/agent-skills --skill signadot-trial

Then ask your agent to "try Signadot". Needs Docker with about 4 GB of memory
for the core tutorial, plus curl; kubectl, kind, helm and git are installed
with your consent if missing. No sudo is needed by default.

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
