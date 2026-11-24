# Customize the trial (optional)

The plan offers it in one line ("Want it tailored to your stack? Say "customize""), so it costs no extra reply. A user
who says "customize" answers five quick questions while the cluster builds, gets the scenarios that fit their stack
after the first one, and ends with a page on whether Signadot is a good fit (`references/finish/fit.md`). A user who
didn't is offered the questions once more at the hand-off. Only someone who answered gets the fit page.

Never read the user's repos, other projects or the agent's memory to answer these: people hesitate to point a
vendor's skill at real code, and one repo can't speak for an org whose services use different stacks. Ask.

## 1. When to ask

- **They said "customize" in reply to the plan:** send the questions in the same message as the account step
  (`references/setup/account.md`: the signup steps, or the login link and code), after it, with one line: "While
  you do that, five quick questions about your stack. Answer them in your reply, or skip them." The cluster builds
  meanwhile, so the questions add no wait and no extra reply.
- **At the hand-off, if they didn't:** offer once: "Want a page on whether Signadot fits your stack? Five quick
  questions." On a yes, send them, then write the fit page.

## 2. The questions

Send all five together, so the user can answer in one reply, in their own words. Each has examples, not a list
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

Why these five: each feeds the fit page. 1 decides whether and how Signadot installs (and which mesh to suggest); 2
whether requests and messages can be routed to a sandbox; 3 how much context-propagation work there is (usually
the biggest piece); 4 data isolation and what Signadot replaces; 5 what it solves for them.

Read the answers as free text. Map each thing they name to the matrix's rows (`assets/fit/compatibility.md`), and
give each part of a mixed answer its own item ("EKS, some on ECS" is two). Ask a follow-up only when the answer
changes what you suggest (an unclear mesh); otherwise record it as given, and treat "not sure" or a skipped question
as unknown, not as a no.

Record the answers under Run, one line per question, in the user's words:

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

## 3. The suggestions

Turn the answers into the menu after the first scenario (SKILL.md, "After the first scenario"): the add-ons their
answers point to, the mesh they use, and what the trial can't demo.

- **The basics always run.** They're what every later scenario builds on.
- **Mesh:** Istio, Istio ambient or Linkerd: suggest it. It runs after the basics in its own copy of the demo app
  (`references/infra/add-mesh.md`), so they see Signadot on their mesh. `other`, `mixed` or `unknown`: say the fit
  page covers it.
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
  | waiting for staging, environment drift | Test one change in isolation, which they've just seen; point to it |
  | previewing pull requests for reviewers | Test a change that spans two services is already in the basics; point to it |

- **Named, not dropped:** anything they use that the trial can't demo (SQS/SNS, Pub/Sub, NATS, gRPC-only traffic,
  another mesh, services off Kubernetes) gets one line: "The trial has no demo for SQS; the fit page covers it, with
  the guide." Take the guide from the compatibility matrix (`assets/fit/compatibility.md`).
- **The rest of the menu** stays available: end with "Or anything else from the full menu."
- **Answers that arrive late** (after the first scenario's menu, or at the hand-off) only feed the fit page.

## Docs

The answers drive the fit page; its sources are listed in `assets/fit/compatibility.md`. Signadot's docs index:
https://www.signadot.com/docs/llms.txt.
