# Account and CLI login

## 1. Account (`account`) ★

About 3–4 minutes, mostly the user. Skip to §2 if the user already has an account they want to use; they pick the
org, and every org-scoped name gets the run suffix (see SKILL.md).

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

Keep this browser session open: the CLI login (§2) is confirmed in it, and C2's preview URL opens in it.

## 2. CLI login (`login`)

About 30 seconds. Skip it if `$T/bin/sd auth status` already shows the org the user wants (a resumed trial).

The login prints a URL and a code and tries to open a browser. Catch the URL instead, so it opens in the signed-in
session from §1. Add `--insecure-storage` when the trial isolates its config (`isolated: yes`): the credentials then
go to a file under `$T/home` rather than the system keychain.

```bash
T="${SIGNADOT_TRIAL_HOME:-$HOME/.signadot-trial}"
mkdir -p "$T/shim" "$T/logs" && : > "$T/logs/login-url"
for b in open xdg-open; do
  printf '#!/bin/sh\necho "$@" >> "%s/logs/login-url"\n' "$T" > "$T/shim/$b"; chmod 755 "$T/shim/$b"
done
PATH="$T/shim:$PATH" nohup "$T/bin/sd" auth login --insecure-storage > "$T/logs/login.log" 2>&1 &   # drop --insecure-storage when not isolated
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
Never print the token line from `auth status` in your messages or the trial log.
