# Account and CLI login

## 1. Account (`account`) ★

About 3–4 minutes, mostly the user. Start by asking, in one message:

- how they'd like to sign up: with an email address, with Google or GitHub, or by signing in to an org they already
  have (if preflight shows `signadot_login: <org>`, offer that org by name);
- for a new account: the organization name, and their first and last name.

If they use an org they already have, skip to §2. Tell them in one line that the trial's names get a short suffix
(SKILL.md, "Existing org") and that teammates can see the trial's sandboxes in the dashboard.

**If you can drive a browser the user can see and type into:**

1. Open `https://www.signadot.com/signup`. It opens on the Sign Up tab.
2. Type the email, or let the user choose Google or GitHub sign-in. Then hand over: "Please type a password in the
   browser window and press Continue. Then open the verification email and click the link. Tell me when you've done
   that."
3. When they confirm, click "I've verified my email" in the original tab; it doesn't refresh by itself.
4. On "Create a new Organization", fill Organization Name, First Name and Last Name, and put
   `Signadot trial agent skill` in "How did you hear about us". Tick the Terms box only if the user said so;
   otherwise ask them to tick it. Submit.

**If you can't drive a browser,** give the user these steps in one message:

1. Open https://www.signadot.com/signup and sign up with your email (or Google/GitHub).
2. Type a password, then click the link in the verification email, and go back to the signup tab and click "I've
   verified my email".
3. Create the organization "<org>" with your first and last name, put "Signadot trial agent skill" under "How did you
   hear about us", accept the Terms, and submit.
4. Tell me when you see the dashboard.

Done when the dashboard's Overview page loads. Record the step, and under User actions: "Typed the signup password
and clicked the verification link".

Keep this browser session open: the CLI login (§2) is confirmed in it, and the preview URL (multi-service-preview) opens in it.

## 2. CLI login (`login`)

About 30 seconds. Skip it only if `$T/bin/sd auth status` shows `Authenticated` and the org the user wants (a resumed
trial). An expired login still shows the org, with an `Expired:` line instead of `Authenticated`: log in again.

The login prints a URL and a code and tries to open a browser. Catch the URL instead, so it opens in the signed-in
session from §1. `--insecure-storage` keeps the credentials in a file under `$T/home` rather than the system
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

Open the URL in the signed-in browser, check that the code on the page matches the one in `login.log`, and click
Confirm. If you can't drive a browser, give the user the URL and the code and ask them to confirm it in the browser
where they signed up. If that browser shows a different Signadot account, stop and tell the user.

Then wait for the login to finish:

```bash
"$T/bin/sd" auth status | grep -E "^(Status|Organization)"   # repeat every few seconds for up to 2 minutes
```

Done when it shows `Authenticated` and `Organization: <org>`. Signadot derives the org's short name from the name
typed, for example "Acme Trial" becomes `acmetrial`; use the short name from here on. Record the step with the org.
Never print the token line from `auth status` in your messages or the trial log. Command reference:
https://www.signadot.com/docs/reference/cli/auth.md.
