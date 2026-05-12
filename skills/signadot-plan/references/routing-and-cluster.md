# Routing And Cluster

Use this reference whenever a plan targets a sandbox, route group, routing key,
or service URL that should hit isolated code.

## Routing Context

If a step issues traffic that should reach a sandbox or route group, set
`routingContext` on that step. Typical examples are request steps and shell
scripts that need `SIGNADOT_ROUTING_KEY`, `SIGNADOT_SANDBOX_NAME`, or
`SIGNADOT_ROUTEGROUP_NAME`.

Forms:

| Form | Use when |
|---|---|
| `routingContext.literal` | The sandbox, route group, or routing key is hardcoded |
| `routingContext.ref.sandboxRef` | A plan param holds a sandbox name, e.g. `params.sandbox` |
| `routingContext.ref.routeGroupRef` | A plan param holds a route group name |
| `routingContext.ref.routingKeyRef` | A plan param holds a raw routing key |
| `routingContext.ref.anyRef` | A plan param holds a polymorphic `RoutingTarget` |

Omit `routingContext` when the plan intentionally exercises baseline cluster
traffic with no sandbox or route group involved.

Forgetting `routingContext` on a sandboxed request is a silent failure mode: the
request can route to baseline, the sandbox sees no traffic, and the test may
pass against the wrong code.

## Injecting The Routing Key

`routingContext` sets routing env vars for the step, but outbound requests must
still carry the routing key in a header or query param the cluster accepts. Both
halves are required.

Identify the target cluster first. Conveyance methods are cluster-scoped, so do
not guess or use a default when the cluster is ambiguous.

Discover routing config:

```bash
signadot cluster list -o json | \
  jq '.[] | {name, routing: .clusterConfig.routing}'
```

Headers always accepted, using key name `sd-routing-key`:

```text
baggage:    sd-routing-key=<key>
tracestate: sd-routing-key=<key>
```

If `clusterConfig.routing.customHeaders` lists additional names, inject every
one with the routing key as the value. The cluster matches any configured
header, but downstream instrumentation may propagate only some of them.

If `queryParamRouting.enabled: true`, the cluster also accepts
`?<paramName>=<key>`. Use query-param routing only when the surface cannot set
headers, such as browser address-bar navigation or redirect URLs that strip
headers. Headers are the primary mechanism.

The value comes from `SIGNADOT_ROUTING_KEY`, set by `routingContext`. Read the
action body to learn whether the action auto-injects routing-key headers or
expects step code/tool syntax to do it.

## Cluster Affinity

`spec.cluster` and `routingContext` answer different questions:

- `spec.cluster` decides where the plan runner runs.
- `routingContext` decides how a step directs traffic.

For sandbox- or route-group-scoped plans, set both when needed. A common shape
is `cluster.fromSandbox: sandbox` plus
`routingContext.ref.sandboxRef: params.sandbox` on every traffic-issuing step.

At most one `spec.cluster` field should be set:

| Field | Use when |
|---|---|
| `fromCluster: <param>` | The plan takes a cluster name directly as a param |
| `fromSandbox: <param>` | The plan takes a sandbox name; cluster is the sandbox's cluster |
| `fromRouteGroup: <param>` | The plan takes a route group name; cluster resolves from the route group when bound to one cluster |
| `fromAnyTarget: <param>` | The plan takes a `RoutingTarget`; the variant decides at execution time |
| `pattern: "<glob>"` | The plan should run on whichever connected cluster matches |

If the plan has no cluster relationship, omit `cluster`; the execution caller
must specify a cluster explicitly. Surface that requirement before closeout.
