# Worked Example

The user says: "I changed `frontend` so the cart page shows item subtotals.
Validate it."

## Contents

- Phase A: Define validation
- Phase B: Set up the sandbox
- Phase C: Run browser validation
- Phase D: Iterate
- Close out

## Phase A: Define Validation

Ask which validation type to run because the user did not specify one:
integration tests, existing e2e suite, ad-hoc browser automation, or an
existing tagged Signadot plan.

The user picks ad-hoc browser automation (driven via Playwright) because they
want to see the page.

## Phase B: Set Up The Sandbox

Discover cluster tools and list clusters. There is one cluster, so no user
choice is needed.

Discover workload tools and resolve `frontend`. The resolved workload is in
namespace `hipster-shop`; its container port is `8080`.

Check whether the current environment is a devbox:

```bash
grep -c '^242\.242\.' /etc/hosts
hostname
```

The host has Signadot entries and matches a listed devbox, so use that devbox ID
as `connection.devboxId` and skip `signadot local connect`.

Look for a reusable sandbox for the same user/workload. None exists. Check
`.signadot/dev/frontend.yaml`; it exists, so apply it with the devbox ID
substituted. Poll until the sandbox is ready and the tunnel is connected.

Pull env:

```bash
eval $(signadot sandbox get-env frontend-dev)
signadot sandbox get-files frontend-dev
```

The repo `Makefile` documents `make run-local`. Build first, stop any owned
listener on the service port, start `make run-local`, and verify the process and
listener.

Resolve the frontend Service port. The Service exposes port `80`, while the
container uses `8080`. Validate against `:80`, not `:8080`.

```bash
curl -sS "http://frontend.hipster-shop.svc:80/cart" \
  -H "baggage: sd-routing-key=$KEY" \
  -H "tracestate: sd-routing-key=$KEY"
```

The response is status 200, so routing reaches the local process.

## Phase C: Run Browser Validation

Install a route hook before navigation:

```js
async (page) => {
  await page.unrouteAll();
  await page.route('**/*', async route => {
    await route.continue({
      headers: {
        ...route.request().headers(),
        'baggage': 'sd-routing-key=<key>',
        'tracestate': 'sd-routing-key=<key>'
      }
    });
  });
  await page.goto('http://frontend.hipster-shop.svc:80/cart');
  await page.waitForLoadState('networkidle');
}
```

Drive the cart path. The page renders, but one row reads `$NaN`.

## Phase D: Iterate

Read browser console errors and service logs. The error shows frontend code
dereferencing `item.qty` as a number after the wire type changed to string.

Fix the coercion, rebuild the frontend bundle, restart the local service, and
run the same browser path against the same sandbox and routing key.

Subtotals render correctly and no relevant console errors remain.

Because the existing tests would not have caught this wire-type drift, consider
whether to codify the check as a Signadot plan. If the team wants durable
coverage, use the `signadot-plan` skill to author and tag it.

## Close Out

Report:

- sandbox `frontend-dev`
- routing key used
- service URL `http://frontend.hipster-shop.svc:80/cart`
- browser path validated
- local process stopped or still running, with PID/port
- optional cleanup command:

```bash
signadot sandbox delete frontend-dev
```
