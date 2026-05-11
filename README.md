# Signadot Agent Skills

Skills for AI coding agents to work with [Signadot](https://www.signadot.com).
They give the agent structured workflows for planning and validating
changes against real Kubernetes microservice dependencies.

## Skills

- **`signadot-plan`** — Author and iterate on Signadot plan specs:
  discover schema and actions, compose params and steps, run plans, and
  inspect outputs and logs.
- **`signadot-validate`** — Validate code changes against real Kubernetes
  microservice dependencies using Signadot signals: local sandboxes,
  cluster reachability, logs, endpoints, and routing-key isolation.

## Usage

The skills follow the [Agent Skills specification](https://agentskills.io/specification),
a vendor-neutral `SKILL.md` format auto-loaded by [Claude Code](https://claude.com/claude-code)
and other compatible agents.

For Claude Code, copy the skill into your skills folder:

    cp -r skills/signadot-plan ~/.claude/skills/

It is picked up on next start and triggers when the conversation matches
its scope.

For other agents (Cursor, Codex CLI, Aider, etc.), each `SKILL.md` works
as plain markdown guidance — drop it into whatever rules / context
mechanism your tool uses (`.cursorrules`, `AGENTS.md`, system prompts,
etc.).

## Requirements

- An AI coding agent
- The Signadot CLI, configured against your cluster

## License

Apache 2.0 — see [LICENSE](LICENSE).
