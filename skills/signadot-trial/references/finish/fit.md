# Fit summary

At the end of a customized trial (`path: customized`), or on the standard path after the user answers the six
questions, write one more page: how Signadot would fit the stack the user described, where the gaps are, and what an
install in their own cluster would take. It's written for the person who ran the trial to forward to their platform
team or leadership, who didn't see the trial. Be plain and factual: no sales lines.

## Rules

- **Fit claims come from `assets/fit/compatibility.md`, never from your own knowledge.** Map each answer to its rows
  and use their status and guide links. If an answer has no row, mark it **?** and say the team should ask
  Signadot. Don't upgrade a status because something seems likely to work.
- **Check that the matrix is current:** fetch each guide you cite (its `.md` copy). If a page moved or says
  something different from the matrix, follow the page and note it in the trial log under Fallbacks.
- **Org-wide:** the answers describe the whole org. When an answer lists several things (EKS and services off
  Kubernetes; Kafka and SQS), give each its own row, so a gap in one part doesn't hide behind support in another.
- **Point to proof:** when a scenario the user ran shows a row working, link its report page ("You saw this:
  Kafka").
- **Never read their repos, other projects or the agent's memory** to fill gaps. The answers are the input.

## The page

`cp "$S/assets/report/fit.html" "$T/report/fit.html"` and fill its `FILL:` slots:

- **headline:** two sentences: the overall picture (for example "Signadot covers most of your stack today. Two
  things need work: OpenTelemetry in the services that don't have it, and SQS consumers.").
- **stack:** one row per answer item: what they said, the status (`✓ supported`, `⚠ supported, with work`,
  `✗ not supported`, `? not documented, ask Signadot`), what it takes in one sentence, and the guide link (plus the
  trial page if a scenario showed it).
- **pains:** one row per pain they picked: the scenario that addressed it (with its page), and one sentence on what
  it means for them.
- **effort:** what an install in their own cluster takes, in order, from the matrix's rows for their answers: install
  the operator (one Helm chart per cluster), the routing mode for their mesh, context propagation (the biggest piece
  of work when tracing isn't everywhere: say which services need it, from their answer), message-queue and data
  isolation for what they use, then CI (Jobs or Plans) if they picked testing pains. Say who usually does each part
  (platform team, service owners).
- **questions:** what their platform team will want to know before an install, each with the guide that answers
  it: what runs in the cluster and with which permissions, network and security requirements, how routing affects
  production-like traffic, and cost (link https://www.signadot.com/pricing/; don't estimate).
- **open:** everything marked **?**, as questions to ask Signadot.

Then rebuild the overview page with a link to it, open it, and give a three-line summary in chat: the overall
picture, the biggest gap, and the page.

## Record

```markdown
## Fit summary
supported: <items>
with-work: <items: what>
not-supported: <items>
unknown: <items>
page: report/fit.html
```

## Docs

Every row of `assets/fit/compatibility.md` links its guide. Index: https://www.signadot.com/docs/llms.txt.
