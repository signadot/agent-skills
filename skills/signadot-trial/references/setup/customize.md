# Customize the trial (optional)

The first question after preflight, before the plan. It's optional: a user who wants the standard trial gets it with
no extra questions. A customized trial shows Signadot on the parts of the user's stack that matter to them, and ends
with a fit summary they can take to their platform team (`references/finish/fit.md`).

Never read the user's repos, other projects or the agent's memory to answer these: people hesitate to point a
vendor's skill at real code, and one repo can't speak for an org whose services use different stacks. Ask.

## 1. The opening question

Send it with the preflight result (one line: "Your computer is ready." or what's missing), as formatted text:

```markdown
**Would you like to customize the trial to your use case, or run the standard trial?**

1. **Customize** (about 1 minute of questions): tell me about your stack and what slows your team down. I'll set
   the demo up the way you run things (for example on your service mesh), show only the scenarios that matter to
   you, and end with a summary of how Signadot would fit your stack and where the gaps are.
2. **Standard:** the three basics on a small demo app, then a menu of more to try.
```

"Customize", "1" or anything about their stack: go to §2. "Standard", "2", "just go": send the plan (SKILL.md, "The
plan") and record `path: standard` under Run.

## 2. The questions

Send all six in one message, numbered, so the user can answer in one reply ("1 EKS, 2 Istio, 3 HTTP Kafka SQS, …").
Every one is about the **whole org**, not one service, and "not sure" is always a fine answer.

```markdown
A few quick questions, about your **whole org**, not one service. Pick all that apply; "not sure" is fine.

1. **Where do your services run?** EKS · GKE · AKS · on-prem or self-managed Kubernetes · OpenShift · some services
   aren't on Kubernetes (VMs, ECS, serverless)
2. **Service mesh?** none · Istio (sidecars) · Istio ambient · Linkerd · other · differs between teams
3. **How do services talk to each other?** HTTP/REST · gRPC · Kafka · RabbitMQ · SQS/SNS · Google Pub/Sub · NATS ·
   Redis Streams · Temporal · other
4. **Tracing today?** OpenTelemetry in every service · in some services · another tracer · none
5. **Data:** do environments share databases? Do your tests need their own or seeded data? (yes / no / sometimes)
6. **What slows your team down most?** Pick up to two: waiting for or fighting over a shared staging environment ·
   slow feedback before merge · flaky or late end-to-end tests · the cost of extra environments · previewing PRs
   for reviewers and PMs · checking changes made by coding agents
```

Record the answers under Run as `answers:` lines, one per question (`answers-mesh: istio`, `answers-messaging:
http, kafka, sqs`, …), and `path: customized`.

## 3. The tailored plan

Turn the answers into the plan (SKILL.md, "The plan", with these changes) and get one OK:

- **The basics always run.** They're what every later scenario builds on.
- **Mesh (question 2):** Istio, Istio ambient or Linkerd: install it during setup (its infra file's "Install before
  HotROD", about 2 more minutes), so every scenario runs on it. Say so in the plan: "Everything will run on Istio, as
  in your clusters." "Differs between teams" or "other": use the default (DevMesh) and say the fit summary covers
  the rest. This is the only time a mesh is cheap: later it means rebuilding the cluster.
- **Add-ons to offer after the basics,** in place of the full menu:

  | Answer | Offer |
  |---|---|
  | Kafka | Kafka |
  | RabbitMQ | RabbitMQ |
  | Redis Streams | Redis Streams |
  | Temporal | Temporal |
  | shared databases, or tests need their own data | Database per sandbox |
  | flaky or late end-to-end tests; checking coding agents' changes | Automated tests |
  | slow feedback before merge | Run a service on your computer is already in the basics; point to it |
  | previewing PRs for reviewers and PMs | Test a change that spans two services is already in the basics; point to it |

- **Named, not dropped:** anything they use that the trial can't demo (SQS/SNS, Pub/Sub, NATS, gRPC-only traffic,
  another mesh, services off Kubernetes) gets one line in the plan: "The trial has no demo for SQS; the fit summary
  covers it, with the guide." Take the guide from the compatibility matrix (`assets/fit/compatibility.md`).
- **Memory:** add the picks' memory from the scenario index and settle it before the OK, as usual.

After the basics, show the tailored menu (SKILL.md, "More scenarios", only the offered items, with their
explainers), and keep "anything else from the full menu" as the last line.

## Docs

The answers drive the fit summary; its sources are listed in `assets/fit/compatibility.md`. Signadot's docs index:
https://www.signadot.com/docs/llms.txt.
