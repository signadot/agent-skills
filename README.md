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

### Install with the `skills` CLI (recommended)

The [`skills`](https://github.com/vercel-labs/skills) CLI installs these
skills into any [supported agent](https://github.com/vercel-labs/skills#supported-agents)
(Claude Code, Codex, Cursor, OpenCode, and 50+ more) — no manual copying:

    # Install all skills to detected agents in the current project
    npx skills add signadot/agent-skills

    # Install globally for a specific agent
    npx skills add signadot/agent-skills -g -a claude-code

    # Install a single skill
    npx skills add signadot/agent-skills --skill signadot-plan

The skill is picked up on next agent start and triggers when the
conversation matches its scope.

### Manual install

For Claude Code, copy the skill into your skills folder:

    cp -r skills/signadot-plan ~/.claude/skills/

For other agents, each `SKILL.md` works as plain markdown guidance — drop
it into whatever rules / context mechanism your tool uses
(`.cursorrules`, `AGENTS.md`, system prompts, etc.).

## Requirements

- An AI coding agent
- The Signadot CLI, configured against your cluster

## License

Apache 2.0 — see [LICENSE](LICENSE).
