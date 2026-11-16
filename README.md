# Signadot Agent Skills

Skills for AI coding agents to work with [Signadot](https://www.signadot.com).
They give the agent structured workflows for trying Signadot, and for planning
and validating changes against real Kubernetes microservice dependencies.

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

New to Signadot? Start with [`signadot-trial`](skills/signadot-trial/): it creates
your account and a local cluster, so nothing needs to be set up first.

### [`signadot-trial`](skills/signadot-trial/)

Try Signadot hands-on, end to end, from your coding agent. It signs you up, sets
up a local kind cluster with the HotROD demo app, and proves each capability by
sending the same request with and without a routing key: one service in
isolation, a multi-service preview URL, and a service running on your computer.
Optional variations cover Istio, Istio ambient and Linkerd, a database per
sandbox, Kafka, Temporal, RabbitMQ and Redis Streams, and test automation with
Jobs and Plans. It runs one scenario at a time and writes a page for each that
explains what was tested and why it matters, then leaves everything running until
you ask for teardown.

    npx skills add signadot/agent-skills --skill signadot-trial

Run it in an empty folder, then start your agent there and ask it to "try
Signadot". The trial keeps everything it creates in a `.signadot-trial` folder
inside it, so the agent needs no access elsewhere. Needs Docker with
about 4 GB of memory, plus curl; kubectl, kind, helm and git are installed
with your consent if missing. No sudo is needed by default.

### [`signadot-validate`](skills/signadot-validate/)

Validate code changes against real Kubernetes microservice dependencies
using Signadot signals: local sandboxes, cluster reachability, logs,
endpoints, and routing-key isolation.

    npx skills add signadot/agent-skills --skill signadot-validate

### [`signadot-plan`](skills/signadot-plan/)

Author and iterate on Signadot plan specs: discover schema and actions,
compose params and steps, run plans, and inspect outputs and logs.

    npx skills add signadot/agent-skills --skill signadot-plan

## Requirements

- An AI coding agent
- For `signadot-validate` and `signadot-plan`: the Signadot CLI, configured
  against your cluster. `signadot-trial` installs what it needs (see above).

## Contributing

Changing `signadot-trial`? Read [tests/signadot-trial/MAINTAINING.md](tests/signadot-trial/MAINTAINING.md) for its
pinned versions, checks and live checklist.

## License

Apache 2.0 — see [LICENSE](LICENSE).
