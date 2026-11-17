# Signadot compatibility matrix

The trial's fit summary (`references/finish/fit.md`) takes every status from this file, never from the agent's own
knowledge. Each row cites the published page it's based on. Refresh it when the docs change (MAINTAINING.md, "What's
pinned"); a Signadot reviewer owns the statuses, especially the "Gaps / unclear" section at the end.

Retrieved: 2026-11-16 (from https://www.signadot.com/docs/llms.txt, the linked `.md` page copies, and https://www.signadot.com/llms.txt)

Every row cites a published docs page. Status values mean:
- **supported**: a guide or tutorial exists.
- **supported, with work**: the docs describe extra setup the team has to do.
- **not documented**: we searched the docs and found nothing.
- **not supported**: the docs say it isn't supported.

## 1. Where services run

| Item | Status | What it takes | Docs |
|---|---|---|---|
| Any Kubernetes cluster (general) | supported | Install the operator with Helm and a cluster token; the cluster needs egress to `api.signadot.com` and `tunnel.signadot.com:443`. | https://www.signadot.com/docs/installation/signadot-operator |
| Amazon EKS | supported | The Vercel tutorial runs on EKS; Bottlerocket nodes need `user.max_user_namespaces` raised for Plan runners. | https://www.signadot.com/docs/tutorials/vercel-preview-environments |
| Google GKE | supported | The Pub/Sub tutorial runs on GKE with Workload Identity. | https://www.signadot.com/docs/tutorials/testing-google-pub-sub-flows |
| Azure AKS | not documented | No AKS guide or mention in the docs. | — |
| Red Hat OpenShift | supported, with work | Plan runners need `user.max_user_namespaces` raised and SELinux `userns_create` allowed; the docs have no OpenShift guide for installing the operator. | https://www.signadot.com/docs/reference/plans/cluster-requirements |
| minikube | supported | Used by several tutorials (Claude Code, Cursor, Neon, Apollo, Dapr). | https://www.signadot.com/docs/tutorials/closed-loop-microservices-validation-claude-code |
| kind / k3d / Docker Desktop | supported | The docs list them as working local clusters; on Ubuntu 23.10+ hosts, Plan runners need an AppArmor sysctl. | https://www.signadot.com/docs/tutorials/devin-signadot-sandboxes |
| k3s | supported | The quickstart names k3s as a cluster option. | https://www.signadot.com/docs/tutorials/quickstart/first-sandbox |
| Signadot Playground Cluster (trial) | supported | Self-provision it from the Dashboard with everything pre-installed; it has no Plan Runner Groups. | https://www.signadot.com/docs/tutorials/quickstart/first-sandbox |
| Minimum Kubernetes version | not documented | The docs give no minimum Kubernetes version for the operator. | — |
| Operator version support window | supported | Only the latest minor release and the one before it are supported, so plan to upgrade every 1–2 months. | https://www.signadot.com/docs/guides/admin/operator-version-policy |
| Workloads you can fork: Deployment, Argo Rollout | supported | Set `forkOf.kind` to `Deployment` or `Rollout`; a fork runs in the same namespace as its baseline. | https://www.signadot.com/docs/reference/sandboxes/spec |
| Argo Rollouts that use `workloadRef` | not supported | The spec says they aren't supported; embed the template in the Rollout instead. | https://www.signadot.com/docs/reference/sandboxes/spec |
| Forking a StatefulSet, DaemonSet, Job or CronJob | not supported | `forkOf.kind` accepts only `Deployment` or `Rollout`. | https://www.signadot.com/docs/reference/sandboxes/spec |
| Fully hosted, with no cluster of your own | not supported | The FAQ says no: the control plane is hosted, but sandboxes run in your cluster. | https://www.signadot.com/docs/concepts/faq |
| VMs / ECS / Lambda as dependencies of a sandbox | supported, with work | Write a resource plugin that creates and deletes the workload and passes its address to the fork. | https://www.signadot.com/docs/concepts/resources |
| VMs / ECS / Lambda as the sandboxed version of a service | not supported | Routing covers only in-cluster forks and local workloads, so your own gateway or proxy has to route keyed traffic (on the roadmap). | https://www.signadot.com/docs/concepts/resources |
| Forks in another cluster (multi-cluster routing) | not supported | Listed on the roadmap as not yet available. | https://www.signadot.com/docs/concepts/resources |
| Docker Compose / Nomad / Cloud Run (no Kubernetes) | not documented | Not mentioned in the docs. | — |

## 2. Service mesh / request routing

| Item | Status | What it takes | Docs |
|---|---|---|---|
| DevMesh (Signadot sidecar), no mesh | supported | Annotate pods with `sidecar.signadot.com/inject: "true"`, or label the namespace (operator v1.3.1+). | https://www.signadot.com/docs/guides/request-routing/devmesh |
| Istio (sidecar mode) | supported | Install the operator with `istio.enabled=true`; every forked baseline needs a VirtualService (or an HTTPRoute when Gateway API routing is on). | https://www.signadot.com/docs/guides/request-routing/istio |
| Istio ambient mode | supported, with work | Each forked Service that ambient workloads call needs a waypoint and an HTTPRoute or VirtualService, and the Gateway API CRDs must be installed. | https://www.signadot.com/docs/guides/request-routing/istio-ambient |
| Istio, ambient and sidecar namespaces mixed | supported, with work | Same waypoint requirement; ambient callers reach a fork only when the destination Service has a waypoint. | https://www.signadot.com/docs/guides/request-routing/istio-ambient |
| Istio route customization (alpha) | supported | Use annotations to customize the VirtualService routes Signadot derives. | https://www.signadot.com/docs/guides/request-routing/istio-route-customization |
| Linkerd | supported | Install with `linkerd.enabled=true`, then use DevMesh alongside the Linkerd proxy. | https://www.signadot.com/docs/guides/request-routing/linkerd |
| Gateway API, HTTPRoute/GRPCRoute (alpha) | supported, with work | Needs the Gateway API CRDs, Istio or Linkerd as the implementation, and baseline routes whose `parentRefs` include the Service. | https://www.signadot.com/docs/guides/request-routing/gateway-api |
| Gateway API route customization (alpha) | supported | Use annotations to customize derived routes, including copying labels for Kong or Contour. | https://www.signadot.com/docs/guides/request-routing/gateway-api-route-customization |
| Query-parameter routing (`?sd-routing-key=`) | supported | Add the parameter to the URL; propagating it downstream is best-effort. | https://www.signadot.com/docs/guides/request-routing/query-parameter-routing |
| External routing component (`devMesh.enabled: false` with `routing.signadot.com/external`) | supported, with work | Annotate each Service and provide your own routing; the docs cover it in one paragraph (operator v1.4.0+). | https://www.signadot.com/docs/installation/signadot-operator |
| Excluding a Service from routing | supported | Annotate the Service with `routing.signadot.com/ignore: "true"`. | https://www.signadot.com/docs/guides/request-routing |
| Consul / Cilium service mesh / Kuma / AWS App Mesh | not documented | The docs mention none of these meshes and say nothing about how DevMesh works alongside them. | — |

## 3. Service communication

| Item | Status | What it takes | Docs |
|---|---|---|---|
| HTTP | supported | DevMesh or the mesh routes on headers; services must propagate `baggage`/`tracestate` for multi-hop flows. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| gRPC | supported | DevMesh is an L7 HTTP/gRPC proxy, and GRPCRoute is supported under Gateway API. | https://www.signadot.com/docs/guides/request-routing |
| WebSockets | not documented | No guide; only a release note says DevMesh routes websocket connections. | https://www.signadot.com/docs/release-notes |
| Raw TCP / non-HTTP protocols | not documented | Routing docs cover only HTTP and gRPC, and local `tcp` mappings get no header injection. | https://www.signadot.com/docs/reference/cli/local |
| Routes API (basis for async isolation) | supported | Consumers ask the gRPC/REST Routes API (with a Go library) which routing keys belong to sandboxes. | https://www.signadot.com/docs/guides/set-up-message-queue-isolation |
| Apache Kafka | supported | Consumer group per sandbox, routing key in message headers, each consumer checks the key; or a topic per sandbox from a plugin, with producers co-forked (Node.js demo). | https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka |
| RabbitMQ | supported | Each sandboxed consumer gets its own queue bound to the exchange and filters on the header key (Python demo). | https://www.signadot.com/docs/tutorials/testing-rabbitmq-microservices |
| Amazon SQS | supported | On a shared queue, consumers release non-matching messages with `ChangeMessageVisibility=0`; or use a queue per sandbox from the `amazon-sqs` plugin (Python demo). | https://www.signadot.com/docs/tutorials/testing-sqs-microservices |
| Amazon SNS (+ SQS) | supported | Each sandboxed consumer gets its own SQS queue subscribed to the same SNS topic. | https://www.signadot.com/docs/guides/set-up-message-queue-isolation/sqs |
| Google Cloud Pub/Sub | supported | Each sandboxed subscriber gets its own subscription and filters on the routing-key attribute (Node.js demo on GKE). | https://www.signadot.com/docs/tutorials/testing-google-pub-sub-flows |
| NATS | supported, with work | Guide only, with no tutorial or demo: a wrapper puts the key in NATS headers and subscribers filter through the Routes API. | https://www.signadot.com/docs/guides/set-up-message-queue-isolation/nats |
| Redis Streams | supported | Consumer group per sandbox (`<group>-<key>`), key in entry fields, every entry checked and acknowledged (Python). | https://www.signadot.com/docs/tutorials/testing-redis-streams |
| Sidekiq | supported | The baseline worker moves jobs a sandbox claims to that sandbox's queue (Ruby). | https://www.signadot.com/docs/tutorials/testing-sidekiq-jobs |
| Temporal | supported | Interceptors reject tasks for other routing keys on the shared task queue (Python, TypeScript, Go, Java). | https://www.signadot.com/docs/tutorials/testing-temporal-workers |
| Dapr | supported, with work | Covers only HTTP service invocation and Redis Streams pub/sub in a single namespace; the app resolves the fork's app ID through the Routes API. | https://www.signadot.com/docs/tutorials/testing-dapr-services |
| Debezium CDC (Postgres → Kafka) | supported | A trigger stores the key on each row, Debezium moves it to Kafka headers, and each sandbox gets a consumer group (Python). | https://www.signadot.com/docs/tutorials/testing-debezium-cdc |
| ActiveMQ | not documented | Only the onboarding guide mentions writing wrappers; there is no guide. | https://www.signadot.com/docs/guides/onboarding |
| Amazon Kinesis | not documented | Not mentioned in the docs. | — |
| Amazon EventBridge | not documented | Not mentioned in the docs. | — |
| Azure Service Bus / Event Hubs | not documented | Not mentioned in the docs. | — |
| Apache Pulsar | not documented | Not mentioned in the docs. | — |
| Celery / BullMQ | not documented | Not mentioned in the docs. | — |
| MQTT | not documented | Not mentioned in the docs. | — |

## 4. Context propagation / tracing

| Item | Status | What it takes | Docs |
|---|---|---|---|
| OpenTelemetry `baggage` (`sd-routing-key`) | supported | OTel instrumentation propagates it automatically, with no trace backend needed. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| OpenTelemetry `tracestate` | supported | Enabled by default alongside `baggage`. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| Custom propagated header | supported, with work | Add it to the `routing.customHeaders` Helm value at operator install. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| Jaeger `uberctx-sd-routing-key` | supported, with work | Since operator v0.19.1, it must be listed in `routing.customHeaders`. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| Datadog APM `ot-baggage-sd-routing-key` | supported, with work | Since operator v0.19.1, it must be listed in `routing.customHeaders`. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| Distributed tracing backend | supported | Not required; the services only need to propagate headers. | https://www.signadot.com/docs/concepts/faq |
| Propagation when a test calls the sandboxed service directly | supported | Not needed for SmartTests or API tests that call the sandboxed service directly. | https://www.signadot.com/docs/concepts/faq |
| Per-language OTel instrumentation | supported, with work | The docs point to the OTel docs and the `signadot/examples/instrumentation` repo; no docs page covers a specific language. | https://www.signadot.com/docs/guides/set-up-context-propagation |
| Languages shown in tutorials | supported | Python, Node.js, TypeScript, Go, Java, Ruby, and Swift (iOS). | https://www.signadot.com/docs/tutorials/messaging-and-workflows |
| .NET / PHP / Rust | not documented | No language-specific guidance in the docs. | — |
| Preview URLs (key added automatically) | supported | Requests through a sandbox or route-group endpoint get the routing metadata automatically. | https://www.signadot.com/docs/reference/sandboxes/preview-urls |
| Chrome extension | supported | Injects routing headers into every browser request. | https://www.signadot.com/docs/guides/developer-environments/access-sandboxes |
| Automatic key injection in Jobs (`injectRoutingKey: auto`) | supported | Covers non-TLS HTTP and gRPC only; needs CLI v0.8.1+ and operator v0.18+. | https://www.signadot.com/docs/reference/jobs/spec |
| Mobile clients setting the header | supported | The app sets `baggage: sd-routing-key=<key>` (iOS tutorial; the same page answers for Android, React Native and Flutter). | https://www.signadot.com/docs/tutorials/mobile-app-previews |

## 5. Data isolation

| Item | Status | What it takes | Docs |
|---|---|---|---|
| Shared database with partitioned data (default) | supported | Partition test data by tenant or user ID and clean it up after tests. | https://www.signadot.com/docs/guides/set-up-data-isolation |
| Local database through a local mapping | supported, with work | Run the database on the workstation and route to it with a sandbox local mapping. | https://www.signadot.com/docs/guides/set-up-data-isolation |
| Resource plugins (general) | supported | A YAML spec plus create and delete scripts, run when a sandbox is created and deleted. | https://www.signadot.com/docs/reference/resource-plugins |
| MariaDB (temporary in-cluster server) | supported | The `mariadb` plugin installs a server per sandbox with Helm. | https://www.signadot.com/docs/tutorials/testing-database-schema-changes |
| Postgres, temporary database on an existing server (e.g. RDS) | supported | Complete example plugin that copies a seeded template database per sandbox. | https://www.signadot.com/docs/concepts/resources |
| Postgres with HashiCorp Vault | supported, with work | Example plugin `postgres-vault` only, with no tutorial. | https://www.signadot.com/docs/reference/resource-plugins/examples |
| Neon database branching | supported | A plugin creates a copy-on-write branch per sandbox and deletes it with the sandbox. | https://www.signadot.com/docs/tutorials/neon-database-branching |
| Xata database branching | supported | A plugin creates a copy-on-write Postgres branch per sandbox. | https://www.signadot.com/docs/tutorials/xata-database-branching |
| Other branching databases (PlanetScale, Supabase…) | not documented | The docs only say the same pattern works for any database with a branching API. | https://www.signadot.com/docs/concepts/resources |
| S3 / GCS buckets, DynamoDB, ElastiCache | supported, with work | Write a plugin, for example with the `terraform` example plugin. | https://www.signadot.com/docs/concepts/resources |
| Kubernetes objects per sandbox | supported | The `k8s-apply` example plugin. | https://www.signadot.com/docs/reference/resource-plugins/examples |
| MongoDB / Cloud SQL / Aurora / CockroachDB | not documented | Not mentioned in the docs. | — |

## 6. Testing / CI

| Item | Status | What it takes | Docs |
|---|---|---|---|
| Smart Tests (beta) | supported | Starlark API tests that run on the baseline and the sandbox with Smart Diff; REST/JSON only. | https://www.signadot.com/docs/reference/smart-tests |
| Jobs and Job Runner Groups (JRG in beta) | supported | Create a Job Runner Group with your toolchain image and submit Jobs against a sandbox. | https://www.signadot.com/docs/tutorials/quickstart/jobs |
| Plans and Plan Runner Groups (alpha) | supported, with work | Enable per cluster in the Dashboard; OCI actions need nodes that allow unprivileged user namespaces; not on Playground clusters. | https://www.signadot.com/docs/reference/plans/cluster-requirements |
| Synthetic API tests | supported | Run from the UI, on in-cluster sandboxes only. | https://www.signadot.com/docs/guides/use-cases/run-synthetic-tests |
| Playwright | supported | Run as a Job or Plan action, with a guide and a tutorial. | https://www.signadot.com/docs/guides/testing-frameworks/playwright-integration |
| Cypress | supported | Guide and tutorial. | https://www.signadot.com/docs/guides/testing-frameworks/cypress-integration |
| Postman / Newman | supported | Run Newman in CI or as a Job with the routing header. | https://www.signadot.com/docs/guides/testing-frameworks/postman-integration |
| Grafana k6 | supported | Run k6 as a Job, spread across pods by a Job Runner Group. | https://www.signadot.com/docs/tutorials/k6-load-testing |
| Any other framework (pytest, `go test`…) | supported | Custom test: send the routing header, then run in CI or as a Job. | https://www.signadot.com/docs/guides/testing-frameworks/custom-test |
| GraphQL federation, Apollo GraphOS | supported | An Apollo GraphOS variant plus a sandboxed subgraph. | https://www.signadot.com/docs/tutorials/apollo-graphql-schema-testing |
| GraphQL federation, WunderGraph Cosmo | supported | A Cosmo feature flag plus a sandboxed subgraph. | https://www.signadot.com/docs/tutorials/wundergraph-schema-testing |
| ZAP security scans | supported | Run a ZAP API scan as a Job. | https://www.signadot.com/docs/tutorials/zap-security-testing |
| Falco runtime security | supported | Scope Falco rules to sandbox pods and fail a Job on alerts. | https://www.signadot.com/docs/tutorials/falco-runtime-security |
| Selenium / JMeter / Locust / Gatling | not documented | No guide; the generic Job and custom-test approach would be the path. | https://www.signadot.com/docs/guides/testing-frameworks/custom-test |
| GitHub Actions | supported | Signadot Sandbox Action, or the CLI with a template. | https://www.signadot.com/docs/guides/integrate-ci/github |
| GitLab CI | supported | The CLI in a GitLab pipeline. | https://www.signadot.com/docs/guides/integrate-ci/gitlab |
| Bitbucket Pipelines | supported | The CLI in Bitbucket Pipelines. | https://www.signadot.com/docs/guides/integrate-ci/bitbucket |
| Jenkins | supported | The CLI in a Jenkins FreeStyle project. | https://www.signadot.com/docs/guides/integrate-ci/jenkins |
| Argo CD | supported | Sandboxes alongside an Argo CD baseline, or per PR from ApplicationSet hooks. | https://www.signadot.com/docs/guides/integrate-ci/argocd |
| Flux CD | supported, with work | No guide; with Istio, configure Flux to accept Signadot's VirtualService changes. | https://www.signadot.com/docs/guides/request-routing/istio |
| Other CI (CircleCI, Azure DevOps, Buildkite, Tekton…) | supported, with work | No specific guide; follow the generic CLI-based CI instructions. | https://www.signadot.com/docs/guides/integrate-ci |

## 7. Developer workflows

| Item | Status | What it takes | Docs |
|---|---|---|---|
| Local development (`signadot local connect` with local mappings) | supported | CLI on macOS or Linux; needs root (or `--unprivileged`); the sandbox maps a workload to localhost. | https://www.signadot.com/docs/guides/use-cases/set-up-local-testing |
| CLI on Windows | not supported | No native Windows builds; some features may work under WSL. | https://www.signadot.com/docs/getting-started/installation/signadot-cli |
| Local connection through the control plane (`ControlPlaneProxy`) | supported, with work | Rate-limited and meant for evaluation only; use `PortForward` or `ProxyAddress` (SOCKS5) day to day. | https://www.signadot.com/docs/getting-started/installation/signadot-cli |
| Devboxes / remote dev environments | supported | CLI v1.4.0+; one local-connect session per devbox. | https://www.signadot.com/docs/guides/admin/devboxes-remote-development |
| Record and inspect live traffic | supported | CLI v1.3.0+ and operator v1.2.0+. | https://www.signadot.com/docs/guides/local-development/record-inspect-traffic |
| Override individual APIs locally | supported | CLI v1.3.0+ and operator v1.2.0+, with a virtual workload. | https://www.signadot.com/docs/guides/local-development/override-apis-locally |
| PR sandboxes / preview URLs | supported | Declare endpoints on the sandbox or route group; serving them on your own domain needs operator v1.4.0+ and your ingress. | https://www.signadot.com/docs/guides/developer-environments/configuring-previews |
| Multi-PR features (route groups) | supported | A route group combines several sandboxes under one routing key. | https://www.signadot.com/docs/tutorials/multi-pr-feature-testing |
| Vercel frontend previews | supported | A GitHub Actions workflow pairs each Vercel preview with a backend sandbox. | https://www.signadot.com/docs/tutorials/vercel-preview-environments |
| Mobile app previews | supported | The app sends the routing key in `baggage` (iOS tutorial). | https://www.signadot.com/docs/tutorials/mobile-app-previews |
| MCP server | supported | CLI v1.4.0+; documented clients are Cursor, Claude Code, VS Code and any other MCP client. | https://www.signadot.com/docs/integrations/mcp |
| Agent skills (`signadot-validate`, `signadot-plan`) | supported | `npx skills add signadot/agent-skills`. | https://www.signadot.com/docs/integrations/coding-agents/agent-skills |
| Agentic local development | supported | A coding agent runs the service locally against the cluster through MCP and skills. | https://www.signadot.com/docs/tutorials/quickstart/local-development |
| Claude Code | supported | Tutorial: closed-loop validation with routing keys. | https://www.signadot.com/docs/tutorials/closed-loop-microservices-validation-claude-code |
| Cursor | supported | Tutorial: closed loop through the MCP server. | https://www.signadot.com/docs/tutorials/closed-loop-verification-cursor |
| OpenAI Codex | supported | Tutorial: an autonomous closed loop. | https://www.signadot.com/docs/tutorials/autonomous-closed-loop-codex |
| Devin | supported | CLI and MCP in Devin's VM, using `ControlPlaneProxy`. | https://www.signadot.com/docs/tutorials/devin-signadot-sandboxes |
| Modal Sandboxes | supported | Claude Code in a Modal Sandbox, needing only an API key. | https://www.signadot.com/docs/tutorials/modal-sandboxes-signadot |
| Jira Coding Agent | supported | With Bitbucket Pipelines and Playwright. | https://www.signadot.com/docs/tutorials/jira-coding-agent-signadot-sandboxes |
| CodeRabbit | supported | Explains and fixes failing sandbox tests on PRs. | https://www.signadot.com/docs/tutorials/coderabbit-signadot-failing-tests |

## 8. Known limitations stated in the docs

| Item | Status | What it takes | Docs |
|---|---|---|---|
| Smart Tests protocol scope | not supported | REST/JSON only; gRPC, SOAP and non-JSON formats are not supported. | https://www.signadot.com/docs/reference/smart-tests/spec |
| Gateway API route specificity | supported, with work | A more specific baseline route for another service can beat a derived route; use Istio or DevMesh where paths overlap. | https://www.signadot.com/docs/guides/request-routing/gateway-api |
| Istio VirtualService bound to a gateway without `mesh` | not supported | Routing works only for ingress traffic, not in-cluster traffic, and the sandbox reports not ready. | https://www.signadot.com/docs/guides/request-routing/istio |
| Istio with GitOps-managed VirtualServices | supported, with work | Signadot changes VirtualServices, so Argo or Flux must be set to ignore those changes. | https://www.signadot.com/docs/guides/request-routing/istio |
| Istio 1.26+ nftables with operator v0.19.3 or older | supported, with work | Set `routing.iptablesMode: nft` (cluster-wide). | https://www.signadot.com/docs/guides/request-routing/istio |
| Istio ambient without a waypoint | not supported | Requests from ambient workloads always reach the baseline. | https://www.signadot.com/docs/guides/request-routing/istio-ambient |
| Linkerd without Gateway API, with `devMesh.enabled: false` | not supported | Refused at install time. | https://www.signadot.com/docs/installation/signadot-operator |
| Topic-per-sandbox queue isolation | supported, with work | Every producer on the topic must be co-forked, or the sandbox topic stays empty. | https://www.signadot.com/docs/guides/set-up-message-queue-isolation/kafka |
| Dapr actors, workflows, state, other brokers, multi-namespace | not supported | The tutorial pattern covers HTTP invocation and Redis Streams pub/sub in one namespace only. | https://www.signadot.com/docs/tutorials/testing-dapr-services |
| Synthetic tests on sandboxes with local mappings | not supported | Synthetic tests run on in-cluster sandboxes only. | https://www.signadot.com/docs/guides/use-cases/run-synthetic-tests |
| Bare service names over local connect | not supported | Use `<svc>.<ns>` forms. | https://www.signadot.com/docs/reference/cli/local-name-resolution |
| IdP-initiated SSO | not supported | Logins must start at app.signadot.com. | https://www.signadot.com/docs/guides/admin/sso |
| Playwright report directory upload in Jobs | not supported | Compress the report directory into a single artifact. | https://www.signadot.com/docs/guides/testing-frameworks/playwright-integration |

(These limitations are also listed in sections 1, 2, 6 and 7: forking only Deployments and Rollouts, no fully hosted option, no routing to VMs, ECS or Lambda, no native Windows CLI, a rate-limited `ControlPlaneProxy`, Plans in alpha and unavailable on Playground clusters, and the operator support window.)

## Gaps / unclear

- **Kubernetes version**: the docs give no minimum version. The only clues are a release note fixing a schema error on clusters older than v1.18, and the Plans page saying pod-level user namespaces went GA in Kubernetes 1.33.
- **AKS**: no docs page. A release note fixed `signadot local connect` with Azure AD legacy kubeconfig auth, which hints at Azure use but is not a guide.
- **OpenShift**: covered only in the Plan Runner Groups node requirements. The docs don't say whether installing the operator on OpenShift (SCCs, sidecar injection) needs anything extra.
- **ARM64 nodes**: only implied, by demo build instructions such as `--platform linux/arm64` and `HOTROD_ARCH=arm64`. No support statement for operator images.
- **NATS and RabbitMQ "Signadot wrapper"**: both guides describe a wrapper library, but NATS has no tutorial, demo or published package. The RabbitMQ wrapper lives in a demo repo, not a published SDK. The Routes API client library is documented for Go only.
- **Datadog**: the onboarding guide says tracing tools like Datadog work "out of the box", but the context-propagation page says Datadog's `ot-baggage-*` headers must be configured as custom headers since operator v0.19.1. This depends on whether the Datadog tracer emits W3C `baggage`.
- **WebSockets**: only in a release note (DevMesh), with no guide and no word on Istio or Gateway API behavior.
- **TLS/mTLS between services**: no general statement. Jobs inject keys only into non-TLS HTTP. The Dapr tutorial shows the key can't be read inside sidecar mTLS, so the app routes itself. How Istio mTLS interacts is not discussed.
- **External routing annotation** (`routing.signadot.com/external`): covered in a single sentence on the operator install page, with no guide.
- **Meshes other than Istio and Linkerd**: the docs neither support nor exclude Consul, Cilium, Kuma or App Mesh, and don't say whether DevMesh coexists with them.
- **Per-language propagation**: the docs hand this off to the OpenTelemetry docs and the GitHub examples repo. Whether a given language or framework works is not stated on any docs page.
- **Resource-plugin agent skill**: the docs say Signadot is working on one; it is not yet available.
- **First-class routing to VMs, ECS, Lambda and forks in other clusters**: described as roadmap work, with no date.
- **Message systems people commonly ask about**: Kinesis, EventBridge, Azure Service Bus/Event Hubs, Pulsar, Celery, BullMQ, MQTT and ActiveMQ have no guidance. The general message-level-routing pattern may apply, but the docs don't confirm it per system.

## Pricing and comparison pages (not part of the matrix)

https://www.signadot.com/pricing/
https://www.signadot.com/comparison/garden/
https://www.signadot.com/comparison/mirrord/
https://www.signadot.com/comparison/okteto/
https://www.signadot.com/comparison/pact/
https://www.signadot.com/comparison/qovery/
https://www.signadot.com/comparison/release/
https://www.signadot.com/comparison/skaffold/
https://www.signadot.com/comparison/telepresence/
https://www.signadot.com/comparison/tilt/
https://www.signadot.com/comparison/vcluster/
