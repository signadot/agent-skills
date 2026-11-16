# Prerequisites

Run `bash $S/scripts/preflight.sh` first. It changes nothing and prints one `key: value` line per fact. Use it to
fill the briefing and to decide what's missing; SKILL.md's Prerequisites table says what each kind of gap means.

What each key decides:

- `os`, `docker`, `curl`: must haves. On anything but macOS or Linux, stop. If Docker is stopped, ask the user to
  start Docker Desktop, OrbStack, Colima or the Docker service.
- `docker_mem_gb`: about 4 GB for the core; add each variation's figure from the SKILL.md index. See "Docker memory"
  below.
- `kubectl`, `kind`, `helm`, `git`: show the install command below; run it only after a yes.
- `lsof` (C3 checks its port with it) and `unzip` (the Jobs proof reads the test traces with it): present on macOS
  and most Linux desktops. If one is missing, the user installs it with their package manager (it needs sudo), or
  skip that scenario.
- `signadot`: `scripts/install-cli.sh` installs CLI 1.9.1 into `$T/bin`, or reuses theirs if it's 1.9.1 or newer.
- `go`: 1.27.1 or newer builds C3 directly; otherwise C3 builds in a `golang` container.
- `apparmor_userns: restricted`: Plans can't run until the user changes a kernel setting (troubleshooting.md,
  Testing). Mention it if they pick the testing variations.

- `signadot_config` and `signadot_login`: if either shows the user already uses Signadot, the trial isolates its
  config (`--isolate yes`), so `~/.signadot` and their login stay untouched. On resume, keep `isolated:` from the trial log
  instead: a run that didn't isolate created `~/.signadot/config.yaml` itself, and re-deriving would wrongly switch
  to isolation.
- `local_connect`: a connection is running. `(trial)` means it is the trial's own from an earlier run; otherwise see
  "Another local connection is running" in SKILL.md.
- `kube_context` and `kube_contexts`: name their current context in the briefing, and list the ones that look local
  (`docker-desktop`, `kind-*`, `k3d-*`, `minikube`, `orbstack`, `rancher-desktop`, `colima`) as alternatives.
- `port_8083: busy`: C3 runs the route service on port 8083. Ask the user to free it, or skip C3.
- `trial_log: present`: a trial ran here before. Offer to resume it.

## Install commands

Show the one for the user's platform and run it only after they agree.

**macOS (Homebrew):**

```bash
brew install kubectl kind helm git
```

**Linux, without sudo** (installs into `~/.local/bin`; make sure it's on `PATH`). Use `amd64` or `arm64` from
preflight's `arch`:

```bash
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
ARCH=amd64   # or arm64
curl -fsSLo kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$ARCH/kubectl"
curl -fsSLo kind "https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-$ARCH"
curl -fsSL "https://get.helm.sh/helm-v3.16.2-linux-$ARCH.tar.gz" | tar -xz
install -m 755 kubectl kind "linux-$ARCH/helm" ~/.local/bin/
```

git, lsof and unzip come from the distribution's package manager (for example
`sudo apt-get install git lsof unzip`). That needs sudo, so the user runs it themselves.

Done when preflight shows a version for each tool.

## Docker memory

- **Docker Desktop:** Settings → Resources → Memory, then Apply & Restart.
- **Colima:** `colima stop && colima start --memory 8`.
- **OrbStack:** uses memory as needed; nothing to set.
- **Docker Engine on Linux:** uses the host's memory; check `free -g`.

If the user can't raise it, drop variations until the total fits; the core alone needs about 4 GB.
