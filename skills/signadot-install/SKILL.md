---
name: signadot-install
description: Install and configure Signadot — CLI, Kubernetes Operator, authentication, and routing setup. Use when a platform team needs to set up Signadot in a new cluster or onboard developers.
argument-hint: "[component: cli|operator|routing|all]"
---

# Signadot Installation

Help the user install and configure Signadot components: the CLI, the Kubernetes Operator, and authentication. Follow the steps below precisely. If the user specifies a component ($ARGUMENTS), focus on that section. Otherwise, walk through all steps.

## Prerequisites

- A Signadot account (sign up at https://www.signadot.com/signup/)
- A Kubernetes cluster for the Operator installation
- Helm installed (https://helm.sh/docs/intro/install/)
- For local workloads: a Linux or macOS machine for the CLI

## Step 1: Install the Signadot CLI

The CLI binary is called `signadot`. Install using one of these methods:

### Homebrew (macOS or Linux, recommended)

```bash
brew tap signadot/tap
brew install signadot-cli
```

### Install Script

```bash
curl -sSLf https://raw.githubusercontent.com/signadot/cli/main/scripts/install.sh | sh
```

Environment variables for the script:
- `SIGNADOT_CLI_VERSION` — specific version (default: latest)
- `SIGNADOT_CLI_PATH` — install directory (default: `/usr/local/bin`)

### Direct Download

Download the archive for your platform from https://github.com/signadot/cli/releases and extract it.

### Docker

```bash
docker run signadot/signadot-cli <command>
```

### Upgrade

```bash
# Homebrew
brew update && brew upgrade signadot-cli

# Script — just re-run it
curl -sSLf https://raw.githubusercontent.com/signadot/cli/main/scripts/install.sh | sh
```

## Step 2: Authenticate the CLI

### Interactive Login (recommended, v0.9.1+)

```bash
signadot auth login
```

This opens a browser for authentication. Verify with:

```bash
signadot auth status
```

### API Key Login

```bash
signadot auth login --with-api-key <api-key>
```

### Environment Variables (for CI/automation)

```bash
export SIGNADOT_ORG=<org-name>
export SIGNADOT_API_KEY=<api-key>
```

## Step 3: Install the Signadot Operator

The Operator runs in your Kubernetes cluster and manages sandboxes.

### Generate a Cluster Token

1. Go to the Signadot Dashboard: https://app.signadot.com/settings/clusters
2. Navigate to Clusters > Connect Cluster
3. Provide a name for your cluster
4. Copy the generated cluster token (it is shown only once)

### Install via Helm

```bash
kubectl create ns signadot
helm repo add signadot https://charts.signadot.com
helm install signadot-operator signadot/operator \
  --set agent.clusterToken='<cluster-token>'
```

### Custom Configuration

Use a `values.yaml` file or `--set` flags:

```bash
helm install signadot-operator signadot/operator \
  --set agent.clusterToken='<cluster-token>' \
  --set 'commonLabels.team=platform'
```

For all configurable parameters, see: https://github.com/signadot/charts/tree/main/signadot/operator#parameters

### Upgrade the Operator

```bash
helm repo update
helm upgrade signadot-operator signadot/operator
```

### Uninstall the Operator

```bash
helm uninstall signadot-operator
kubectl delete ns signadot
```

## Step 4: Set Up Routing

Routing determines how sandbox traffic is directed. Choose one:

### DevMesh (recommended for most users)

DevMesh is Signadot's built-in envoy-based sidecar system. No service mesh required. Enable it by adding an annotation to pod templates in your deployments. See: https://www.signadot.com/docs/guides/request-routing/devmesh

### Istio

If you already run Istio, enable Signadot's Istio integration:

```bash
helm install signadot-operator signadot/operator \
  --set agent.clusterToken='<cluster-token>' \
  --set istio.enabled=true
```

Each workload tested with Signadot must have an associated VirtualService. See: https://www.signadot.com/docs/guides/request-routing/istio

### Linkerd

Enable Linkerd support, then use DevMesh on top:

```bash
helm install signadot-operator signadot/operator \
  --set agent.clusterToken='<cluster-token>' \
  --set linkerd.enabled=true
```

### Gateway API (Alpha)

```bash
helm install signadot-operator signadot/operator \
  --set agent.clusterToken='<cluster-token>' \
  --set gatewayAPI.enabled=true
```

## Step 5: Configure the CLI

The CLI reads configuration from `$HOME/.signadot/config.yaml` by default. Use
the `--config` flag on any command to point to a different file:

```bash
signadot --config ~/configs/staging.yaml sandbox list
signadot --config ~/configs/production.yaml cluster list
```

This is useful for switching between orgs, clusters, or local connection
profiles without editing a single file.

### Config File Structure

A complete config file can contain authentication, local connection settings,
and advanced options:

```yaml
# ~/.signadot/config.yaml
org: my-org              # optional if using `signadot auth login`
api_key: sd-...          # optional if using `signadot auth login`

local:
  virtualIPNet: 242.242.0.0/16   # optional, default shown
  connections:
  - cluster: staging
    type: PortForward            # PortForward | ControlPlaneProxy | ProxyAddress
    kubeContext: staging-ctx     # required for PortForward
    # kubeConfig: ~/.kube/config-staging  # optional, defaults to ~/.kube/config
    inbound:
      protocol: xap             # xap | ssh (default)
    outbound:
      excludeCIDRs:             # optional CIDR exclusions
      - 10.43.0.1/32
      macOSVPNInterface: utun6  # optional, for VPN on macOS
  - cluster: production
    type: ControlPlaneProxy     # no kubeContext needed
```

### Local Development Configuration

If developers will use `signadot local connect`, the config file needs a `local` section:

```yaml
local:
  connections:
  - cluster: <cluster-name>       # from Signadot dashboard
    kubeContext: <kube-context>    # from your kubeconfig
```

### Connection Types

- **PortForward** (default) — uses kubectl port-forwarding. Requires kubeContext.
- **ControlPlaneProxy** — routes through Signadot control plane. No kubectl access needed.
- **ProxyAddress** — for clusters with an exposed SOCKS5 proxy (e.g. behind a VPN).

```yaml
# ControlPlaneProxy example (no kubectl needed)
local:
  connections:
  - cluster: staging
    type: ControlPlaneProxy
```

## Step 6: Verify the Setup

1. Check the cluster is connected in the dashboard: https://app.signadot.com/settings/clusters
2. If using DevMesh, verify pods have the `sd-sidecar` container
3. Test with a simple sandbox:

```yaml
# test-sandbox.yaml
name: test-sandbox-routing
spec:
  description: Test Sandbox Routing
  cluster: "@{cluster}"
  forks:
    - forkOf:
        kind: Deployment
        namespace: "@{namespace}"
        name: "@{name}"
```

```bash
signadot sandbox apply -f test-sandbox.yaml \
  --set cluster=<cluster> \
  --set namespace=<namespace> \
  --set name=<deployment-name>
```

If the sandbox reaches Ready state, your setup is complete.

## Troubleshooting

- **Cluster not connecting**: Verify the cluster token is correct and the operator pods are running (`kubectl get pods -n signadot`)
- **Routing not working**: Ensure DevMesh annotations or Istio VirtualServices are configured for your workloads
- **CLI auth issues**: Run `signadot auth status` to check. Re-authenticate with `signadot auth login`
- **Local connect issues**: Check `signadot local status` and ensure `~/.signadot/config.yaml` has the correct cluster/kubeContext
