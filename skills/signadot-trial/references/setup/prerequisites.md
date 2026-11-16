# Prerequisites

Run `bash $S/scripts/preflight.sh` first. It changes nothing and prints one `key: value` line per fact. Use it to
fill the confirmation and to decide what's missing; SKILL.md's Prerequisites table says what each kind of gap means.

What each key decides:

- `os`, `docker`, `curl`: must haves. On anything but macOS or Linux, stop. If Docker is stopped, ask the user to
  start Docker Desktop, OrbStack, Colima or the Docker service.
- `docker_mem_gb`: about 4 GB for the basics; add each add-on's figure from the SKILL.md index. See "Docker memory"
  below.
- `kubectl`, `kind`, `helm`, `git`: show the install command below in the confirmation; its OK covers running it.
- `lsof` (local-development checks its port with it) and `unzip` (the jobs proof reads the test traces with it):
  present on macOS and most Linux desktops. If one is missing, the user installs it with their package manager (it
  needs sudo), or skip that scenario.
- `signadot`: `scripts/install-cli.sh` installs CLI 1.9.1 into `$T/bin`, or reuses theirs if it's 1.9.1 or newer.
- `go`: 1.27.1 or newer builds local-development's service directly; otherwise it builds in a `golang` container.
- `apparmor_userns: restricted`: Plans can't run until the user changes a kernel setting (troubleshooting.md,
  Testing). Mention it in the confirmation if they pick automated tests.
- `trial_dir`: the trial folder `T`. Use this absolute path in every command.
- `signadot_login`: the org the user's own CLI is logged in to, if any. The trial never uses or changes that login
  (it has its own in `$T/home`), but the account step offers that org as an alternative to signing up.
- `local_connect`: a connection is running. `(trial)` means it is the trial's own from an earlier run; otherwise see
  "Another local connection is running" in SKILL.md.
- `kube_context` and `kube_contexts`: the trial never changes their context. In the confirmation, offer the ones that
  look local (`docker-desktop`, `kind-*`, `k3d-*`, `minikube`, `orbstack`, `rancher-desktop`, `colima`) as an
  alternative to a new kind cluster.
- `port_8083: busy`: local-development runs the route service on port 8083. Ask the user to free it, or skip
  scenario 3.
- `trial_log: present`: a trial ran from this folder before. Offer to resume it.

## Install commands

Show the one for the user's platform and run it only after they agree.

**macOS (Homebrew):**

```bash
brew install kubectl kind helm git
```

**Linux, without sudo** (installs into `~/.local/bin`; make sure it's on `PATH`). Use `amd64` or `arm64` from
preflight's `arch`:

```bash
mkdir -p ~/.local/bin "$T/tmp/tools" && cd "$T/tmp/tools"   # downloads stay in the trial folder
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

If the user can't raise it, drop add-ons until the total fits; the basics alone need about 4 GB.
