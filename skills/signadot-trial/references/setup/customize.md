# Customize the trial (optional)

The first question after preflight, before the plan. It's optional: a user who wants the standard trial gets it with
no extra questions. A customized trial shows Signadot on the parts of the user's stack that matter to them, and ends
with a page on whether Signadot is a good fit for them (`references/finish/fit.md`). Only the customized path writes
that page.

Never read the user's repos, other projects or the agent's memory to answer these: people hesitate to point a
vendor's skill at real code, and one repo can't speak for an org whose services use different stacks. Ask.

## 1. The opening question

Send it with the preflight result (one line: "Your computer is ready." or what's missing), as formatted text:

```markdown
**Would you like to customize the trial to your use case, or run the standard trial?**

1. **Customize:** five quick questions about your stack and what slows your team down. I'll set the demo up the way
   you run things (for example on your service mesh), suggest the scenarios that matter to you, and end with a page
   on whether Signadot is a good fit for your stack.
2. **Standard:** the three basics on a small demo app, plus any add-ons you pick from the menu.
```

"Customize", "1" or anything about their stack: go to §2. "Standard", "2", "just go": send the plan (SKILL.md, "The
plan") and record `path: standard` under Run.

## 2. The questions

Send all five in one message, so the user can answer in one reply, in their own words. Each has examples, not a list
to pick from. Every one is about the **whole org**, not one service.

```markdown
Five quick questions about your **whole org**, not one service. Answer in your own words; "not sure" or skipping
one is fine.

1. **Where do your services run, and on which service mesh, if any?** (e.g. EKS with Istio, GKE with no mesh,
   on-prem Kubernetes, some services on ECS or VMs, a mix)
2. **How do your services talk to each other?** (e.g. mostly HTTP and gRPC, Kafka or SQS between some, Temporal
   workflows)
3. **Do requests carry tracing headers from service to service?** (e.g. OpenTelemetry everywhere, Datadog in some
   services, none)
4. **What do you test changes against before they merge, and where does the test data come from?** (e.g. a shared
   staging cluster, a namespace per pull request, Docker Compose on laptops; a shared database, data seeded per run)
5. **What are the main pain points with your current testing environment and code verification setup?** (e.g.
   slow feedback, environment drift, waiting for staging, flaky end-to-end tests, checking changes from coding
   agents)
```

Why these five: each feeds the fit page. 1 decides whether and how Signadot installs (and the trial's mesh); 2
whether requests and messages can be routed to a sandbox; 3 how much context-propagation work there is (usually
the biggest piece); 4 data isolation and what Signadot replaces; 5 what it solves for them.

Read the answers as free text. Map each thing they name to the matrix's rows (`assets/fit/compatibility.md`), and
give each part of a mixed answer its own item ("EKS, some on ECS" is two). Ask a follow-up only when the answer
changes what you set up (an unclear mesh); otherwise record it as given, and treat "not sure" or a skipped question
as unknown, not as a no.

Record the answers under Run, one line per question, in the user's words, and `path: customized`:

```markdown
answers-runs: EKS with Istio; a few services on ECS
answers-messaging: HTTP, gRPC, Kafka, SQS
answers-tracing: OpenTelemetry in some services
answers-testing: shared staging cluster; shared Postgres with seeded data
answers-pains: waiting for staging, flaky end-to-end tests
answers-mesh: istio
```

`answers-mesh` is the mesh read from answer 1: `none`, `istio`, `istio-ambient`, `linkerd`, `other`, `mixed` or
`unknown`.

## 3. The tailored plan

Turn the answers into the plan (SKILL.md, "The plan", customized version): the basics, the add-ons the answers
point to, the mesh, and what the trial can't demo. Then ask how they'd like to run it, as on the standard path.

- **The basics always run.** They're what every later scenario builds on.
- **Mesh:** Istio, Istio ambient or Linkerd: install it during setup (its infra file's "Install before HotROD",
  about 2 more minutes), so every scenario runs on it. Say so in the plan: "Everything will run on Istio, as in your
  clusters." `other`, `mixed` or `unknown`: use the default (DevMesh) and say the fit page covers the rest. Installed
  now, the basics themselves run on it; added after the basics, it would get its own copy of the demo app instead.
- **Suggested add-ons,** from what they named:

  | They mention | Suggest |
  |---|---|
  | Kafka | Kafka |
  | RabbitMQ | RabbitMQ |
  | Redis Streams | Redis Streams |
  | Temporal | Temporal |
  | a shared database, seeded or per-test data | Database per sandbox |
  | flaky or late end-to-end tests; checking coding agents' changes | Automated tests |
  | slow feedback | Run a service on your computer is already in the basics; point to it |
  | waiting for staging, environment drift | Test one change in isolation is already in the basics; point to it |
  | previewing pull requests for reviewers | Test a change that spans two services is already in the basics; point to it |

- **Named, not dropped:** anything they use that the trial can't demo (SQS/SNS, Pub/Sub, NATS, gRPC-only traffic,
  another mesh, services off Kubernetes) gets one line in the plan: "The trial has no demo for SQS; the fit page
  covers it, with the guide." Take the guide from the compatibility matrix (`assets/fit/compatibility.md`).
- **The rest of the menu** stays available: end the add-ons with "Or anything else from the full menu."
- **Memory:** add the picks' memory from the scenario index and settle it before the OK, as usual.

## Docs

The answers drive the fit page; its sources are listed in `assets/fit/compatibility.md`. Signadot's docs index:
https://www.signadot.com/docs/llms.txt.
