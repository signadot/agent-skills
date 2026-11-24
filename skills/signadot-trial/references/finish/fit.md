# Is Signadot a good fit?

Only when the user answered the stack questions (`answers-*` lines under Run, from
`references/setup/customize.md`): at the hand-off, write one more page that answers "Is Signadot a
good fit?" for the stack the user described: a verdict, how it fits their stack, what it solves for them, what an
install in their own cluster would take, and the common questions. The person reading it may be the developer who
ran the trial or a platform lead deciding on it. Be plain and factual: no sales lines. Without answers there's no
page; the overview shows a short fit checklist instead (`references/finish/report.md`, "The overview page").

## Rules

- **Fit claims come from `assets/fit/compatibility.md`, never from your own knowledge.** Map each answer to its rows
  and use their status and guide links. If an answer has no row, mark it **?** and say the team should ask
  Signadot. Don't upgrade a status because something seems likely to work.
- **Check that the matrix is current:** fetch each guide you cite (its `.md` copy). If a page moved or says
  something different from the matrix, follow the page and note it in the trial log under Fallbacks.
- **Org-wide:** the answers describe the whole org. When an answer names several things (EKS and services on ECS;
  Kafka and SQS), give each its own row, so a gap in one part doesn't hide behind support in another.
- **Point to proof:** when a scenario the user ran shows a row working, link its report page ("you saw this").
- **Never read their repos, other projects or the agent's memory** to fill gaps. The answers are the input; an
  unanswered question ("not sure", skipped) is unknown, so leave its rows out or mark them **?**, never assume.

## The verdict

One word, from the statuses of the rows (not from how the trial went):

- **Yes:** every item they named is ✓ or ⚠. The ⚠ work goes under "What an install in your cluster takes".
- **Partially:** their services run on Kubernetes, but at least one item they named is ✗ or ?.
- **No:** the services they'd test don't run on Kubernetes (Signadot runs sandboxes inside a Kubernetes cluster;
  the matrix's "Fully hosted" and "VMs / ECS / Lambda" rows), or every item they named is ✗.

Then two sentences: what's covered today, and the biggest gap or piece of work, by name.

## The page

`cp "$S/assets/report/fit.html" "$T/report/fit.html"` and fill its `FILL:` slots:

- **verdict:** the verdict (`class="verdict yes|partial|no"` and the word), the two sentences, then the meta line
  (org and date).
- **stack** ("How it fits your stack"): one row per answer item: what they said, the status (`✓ supported`,
  `⚠ supported, with work`, `✗ not supported`, `? not covered in the docs: ask Signadot`), what it takes in one
  sentence, and the guide link (plus the trial page if a scenario showed it). For a **?** row, "what it takes" says
  to ask Signadot (support, or a call from https://www.signadot.com).
- **solves** ("What it solves for you"): one row per pain point from answer 5, in their words: the scenario that
  addressed it (with its page), and one sentence on what it means for them. Skip pain points no scenario or matrix
  row speaks to, rather than stretching one.
- **effort:** what an install in their own cluster takes, in order, from the matrix's rows for their answers:
  install the operator (one Helm chart per cluster), the routing mode for their mesh, context propagation (the
  biggest piece of work when tracing isn't everywhere: say which services need it, from their answer), message-queue
  and data isolation for what they use, then CI (Jobs or Plans) if their pain points are about testing. Say who
  usually does each part (platform team, service owners).
- **questions** ("Common questions"): what a platform lead or the team will want to know before an install, each
  with the guide that answers it: what runs in the cluster and with which permissions, network and security
  requirements, how routing affects production-like traffic, and cost (link https://www.signadot.com/pricing/;
  don't estimate).

Then rebuild the overview page so its "Is Signadot a good fit?" section shows the verdict and links here
(`references/finish/report.md`, "The overview page"), open this page, and give a three-line summary in chat: the
verdict, the biggest gap, and the page.

## Record

```markdown
## Fit
verdict: partially
summary: <the two sentences>
supported: <items>
with-work: <items: what>
not-supported: <items>
unknown: <items>
page: report/fit.html
```

## Docs

Every row of `assets/fit/compatibility.md` links its guide. Index: https://www.signadot.com/docs/llms.txt.
