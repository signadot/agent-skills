# Account and CLI login

## 1. Account (`account`) ★

The trial needs a Signadot account: its CLI and the operator in the cluster connect to an org in it. The plan asks
which applies (SKILL.md, "The plan"): **1. Create a new account** or **2. I already have an account**, recorded as
`account: new` or `account: existing`. If the reply didn't say, ask that one question now, with both options, and
end your turn.

If they said "customize", add the five stack questions after this step's message
(`references/setup/customize.md` §1).

### Option 1: create a new account

**If you can drive a browser the user can see and type into,** ask for the organization name and their first and
last name in one line, then:

1. Open `https://www.signadot.com/signup`. It opens on the Sign Up tab.
2. Suggest Google or GitHub sign-in first: no password and no verification email. With an email instead, type it,
   then hand over: "Please type a password in the browser window and press Continue. Then open the verification
   email and click the link. Tell me when you've done that."
3. With an email, when they confirm, click "I've verified my email" in the original tab; it doesn't refresh by itself.
4. On "Create a new Organization", fill Organization Name, First Name and Last Name, and put
   `Signadot trial agent skill` in "How did you hear about us". Tick the Terms box only if the user said so;
   otherwise ask them to tick it. Submit.

**If you can't drive a browser,** send this and end your turn:

```markdown
**Create your Signadot account:**

1. Open https://www.signadot.com/signup and sign up with **Google or GitHub**: it's quickest, with no password or
   verification email. (With an email instead: type a password, click the link in the verification email, then go
   back to the signup tab and click "I've verified my email".)
2. Create your organization (any name works, for example "Acme trial") with your first and last name. Put
   "Signadot trial agent skill" under "How did you hear about us", accept the Terms, and submit.

**Tell me when you see the Signadot dashboard,** and I'll connect the trial to your new account.
```

When they reply, go to §2.

### Option 2: I already have an account

Go straight to §2. Tell them in one line that the trial's names get a short suffix (SKILL.md, "Existing org") and
that teammates can see the trial's sandboxes in the dashboard.

For a new account: done when the dashboard's Overview page loads. Record the step, and under User actions: "Typed
the signup password and clicked the verification link".

Keep this browser session open: the CLI login (§2) is confirmed in it, and the preview URL (multi-service-preview) opens in it.

## 2. CLI login (`login`)

About 30 seconds. Skip it only if `$T/bin/sd auth status` shows `Authenticated` and the org the user wants (a resumed
trial). An expired login still shows the org, with an `Expired:` line instead of `Authenticated`: log in again.

The login prints a sign-in link and a code, then waits until someone confirms that code in a browser signed in to
the org. The shims below catch the link instead of letting the CLI open a browser on its own (it could open one that
isn't signed in). `--insecure-storage` keeps the credentials in a file under `$T/home` rather than the system
keychain, so the login stays inside the trial folder and never touches the user's own.

```bash
T="<trial_dir>"   # the absolute path preflight printed
mkdir -p "$T/shim" "$T/logs" && : > "$T/logs/login-url"
for b in open xdg-open; do
  printf '#!/bin/sh\necho "$@" >> "%s/logs/login-url"\n' "$T" > "$T/shim/$b"; chmod 755 "$T/shim/$b"
done
PATH="$T/shim:$PATH" nohup "$T/bin/sd" auth login --insecure-storage > "$T/logs/login.log" 2>&1 &
sleep 3; cat "$T/logs/login-url"; grep -iE 'code|https://' "$T/logs/login.log"
```

The link is the `https://` URL in `login-url`, or in `login.log` if the CLI didn't try to open a browser; the code is
on the line that mentions it in `login.log`. If neither has appeared yet, wait a few seconds and read them again.

**Always give the user the link and the code in chat, as soon as you have them,** even when you'll confirm it
yourself. Someone new to Signadot must never be left waiting without knowing what is happening or what to do. Show
the full link as text, never only a "click here".

- **If you can drive the browser from §1:** say so in the same message ("I'm confirming it in the browser you signed
  up in; you don't need to do anything unless it asks you to sign in"). Open the link there, check that the page
  shows the same code, and click Confirm. If the page then asks to sign in, ask the user to sign in there (never
  type a password yourself): the login completes only after that. If that browser shows a different Signadot
  account, stop and tell the user.
- **If you can't:** also open the link with the system's own `open` (macOS), `xdg-open` (Linux) or `explorer.exe
  "<link>"` (WSL, where `xdg-open` would start a Linux browser that isn't signed in), not the shims;
  it usually lands in the browser they signed up in, and it does nothing harmful when there's no desktop. Send the
  message below and end your turn. Check the login only after the user says they've confirmed and signed in: some
  agents show a message only when the turn ends, so never wait or poll before the user has seen the link.

Confirming the code isn't the last step: after Confirm, the page asks the user to sign in (unless that browser is
already signed in), and the CLI is logged in only once they have. Say so, as a numbered step:

```markdown
**Connect the trial to your Signadot account.** This lets the trial's own copy of the Signadot CLI work in your
org; nothing on your computer outside the trial folder changes.

1. Open this link: https://app.signadot.com/…
2. Check that the page shows the code **WXYZ-1234**, and click **Confirm**.
3. Sign in with your Signadot account if the page asks you to. The connection completes only after you've signed
   in.
4. Tell me when you've done both. The code expires after a few minutes; if it does, tell me and I'll send a new one.
```

Then check that the login finished:

```bash
"$T/bin/sd" auth status | grep -E "^(Status|Organization)"   # repeat every few seconds for up to a minute
```

If it isn't `Authenticated` after the user confirmed and signed in, or they say the code expired, look at
`login.log`: if the login stopped ("The device code has expired", or it was confirmed in the wrong account), run the
login commands again and send the new link and code the same way, in a short message that says the old one expired.

Done when it shows `Authenticated` and `Organization: <org>`. Signadot derives the org's short name from the name
typed, for example "Acme Trial" becomes `acmetrial`; use the short name from here on. Record the step with the org.
Never print the token line from `auth status` in your messages or the trial log.

**Register the trial's cluster now,** before the rest of setup, so an org that's at its cluster limit is caught
straight away rather than after the cluster is built (an org on the free plan allows one cluster, and an earlier
trial's registration may still hold it):

```bash
bash "$S/scripts/install-operator.sh" --trial-dir "$T" --cluster <cluster> --register-only
```

It prints `cluster: <cluster> (added)` (or `(existing)` on a resumed trial). Exit 9 means the cluster limit is
reached: follow `references/troubleshooting.md`, "Cluster limit", before going on. Command reference:
https://www.signadot.com/docs/reference/cli/auth.md.
