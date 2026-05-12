# Tagging

Default to **no tag**. Plans do not need names; they have IDs. A tag is a thin
pointer (`name → planID`) — a stable handle for humans, CI, or automation that
need to run a reusable plan later. Consumers that hardcode the tag name pick up
new versions transparently when the tag is re-pointed.

## When To Tag

Tag when the plan is reusable:

- multiple consumers will invoke it
- CI or scheduled automation will reference it
- a human-friendly stable name is part of the workflow
- re-pointing the tag is the desired update mechanism

Do not tag one-off plans, exploratory drafts, or in-progress iterations. Stale
tags clutter the org's namespace and make later selection harder.

## Retagging Safety

Before applying a tag, inspect it:

```bash
signadot plan tag get <name> -o json
```

`plan tag apply` silently creates or re-points the tag:

```bash
signadot plan tag apply <name> --plan <plan-id>
```

Ask before overwriting an existing tag unless the user explicitly requested that
exact retag. Be especially careful with production-ish names, CI-owned names,
and tags whose current target has a clear reusable purpose.

## Selection Hint

If a plan is likely to be tagged, set `spec.selectionHint` when creating the
plan. Use one concise sentence describing what the plan does and when to choose
it, for example:

```text
Verifies checkout returns 200 for a valid cart; pick when changing checkout-svc or payment-svc.
```

The hint belongs to the plan spec, not the tag. It surfaces in tag-list
responses so future consumers can pick by purpose without reading every plan
body.
