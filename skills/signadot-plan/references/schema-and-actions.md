# Schema And Actions

Fetch the schema and action catalog before drafting. They are the runtime source
of truth; do not rely on memory when the CLI can answer.

## Plan Schema

```bash
signadot plan schema
```

The schema is org-agnostic but should still be fetched during authoring. It
defines required fields, field names, nullable shapes, and field-level
descriptions. If this skill conflicts with the schema, the schema wins.

Before drafting, inspect the fields you will write:

```bash
signadot plan schema | jq '.properties.params, .properties.output, .properties.steps.items'
signadot plan schema | jq '.properties.steps.items.properties.routingContext, .properties.cluster'
```

## Action Catalog

Scan actions by name, description, ID, and enabled state:

```bash
signadot plan action list -o json | \
  jq '.[] | {id, name, description: .status.description, enabled: .status.enabled}'
```

Pick from actions with `status.enabled == true`. `plan create` rejects disabled
actions. Disabled entries are still useful for escalation: if a disabled action
is exactly the missing capability, name it and ask an org admin to enable it.

Fetch the full body for every action you intend to use:

```bash
signadot plan action get <name> -o json | jq -r .spec.body
```

The body is the action author's contract. It documents declared params and
outputs, schema policy, context/output file paths, expected environment
variables, anti-patterns, and cross-action rules. Cross-action rules (when one
action's existence affects how you compose another) are spelled out on
whichever action's body is most likely to be open at the moment of the mistake.
If an action body says "don't insert X before this," trust it.

Fetch the ID for `action.actionID`:

```bash
signadot plan action get <name> -o json | jq -r .id
```

The plan step uses the action ID, not the action name. Do not embed the action's
body, params, outputs, image, or schema policy in the step; the server snapshots
those from the registered action at create time.

## Capability Gaps

If no enabled action supports the requested capability, say so directly. Offer
the closest enabled alternative if one exists. If a disabled catalog entry is
the right fit, name the gated action and say it needs to be enabled by an org
admin before a plan can reference it.
