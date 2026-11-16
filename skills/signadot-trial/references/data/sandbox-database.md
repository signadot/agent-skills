# A database per sandbox

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

- **Problem:** a change that writes data, or needs different test data, can't safely share one database with
  everyone else, and copying the database for every pull request is slow.
- **What Signadot does:** a resource plugin creates a database for each sandbox and removes it when the sandbox is
  deleted. Here it creates `location_<routing key>` on HotROD's MariaDB, seeded with different locations, and points
  a fork of `location` (same image as the baseline) at it through an environment variable.
- **Why it matters:** each change tests against its own data, and nothing it writes leaks into the shared
  environment.

## Costs

About 3 minutes. No extra memory: the database lives on HotROD's MariaDB. Namespace `hotrod`; the plugin's jobs run
in `signadot`.

## Before you start

Nothing beyond the core setup.

## Set up

A published plugin can't be applied again (Signadot rejects re-applying an existing version), so apply it only if
it isn't there yet, for example on a retry or a resumed trial:

```bash
"$T/bin/sd" resourceplugin get hotrod-trial-db<suffix> >/dev/null 2>&1 \
  || "$T/bin/sd" resourceplugin apply -f "$S/assets/specs/data/hotrod-trial-db-plugin.yaml" --set suffix=<suffix>
```

Record `plugin hotrod-trial-db<suffix>` under Resources.

## Run

```bash
"$T/bin/sd" sandbox apply -f "$S/assets/specs/data/location-db.yaml" --set cluster=<cluster> --set suffix=<suffix>
"$T/bin/sd" sandbox get location-db<suffix> -o json | sed -n 's/.*"routingKey": *"\([^"]*\)".*/\1/p' | head -1
```

`sandbox apply` waits while the plugin creates the database. Record `sandbox location-db<suffix>` under Resources.

## Prove it

Pickup locations without and with the key:

```bash
curl -s --proxy <proxy> http://frontend.hotrod.svc:8080/splash | grep -oE '"name":"[^"]*"' | head -5
curl -s --proxy <proxy> -H "baggage: sd-routing-key=<key>" http://frontend.hotrod.svc:8080/splash | grep -oE '"name":"[^"]*"' | head -5
```

Write a location with the key, then list locations both ways:

```bash
curl -s --proxy <proxy> -H "baggage: sd-routing-key=<key>" -H 'Content-Type: application/json' \
  -d '{"name":"Only In Sandbox","coordinates":"400,500"}' http://location.hotrod.svc:8081/location
curl -s --proxy <proxy> http://location.hotrod.svc:8081/locations | grep -c 'Only In Sandbox'
curl -s --proxy <proxy> -H "baggage: sd-routing-key=<key>" http://location.hotrod.svc:8081/locations | grep -c 'Only In Sandbox'
```

Show the sandbox's own database:

```bash
"$T/bin/kc" -n hotrod exec mysql-0 -c mysql -- mariadb -uroot -pabc -N -e "SHOW DATABASES LIKE 'location\_%'"
```

Done when:
- the baseline shows HotROD's usual locations (like "My Home") and the keyed request shows the seeded ones ("Sandbox
  HQ", "Test Kitchen", "Staging Cafe", …);
- the counts are `0` without the key and `1` with it: the write stayed in the sandbox's database;
- the database list includes `location_<key>`.

Flow for the card: without key `frontend(baseline) → location(baseline) → MySQL: location`; with key
`frontend(baseline) → location(location-db<suffix>) → MySQL: location_<key>`.

## Record

```markdown
## Scenario sandbox-database
status: passed
seconds: <apply to proof>
baseline: locations My Home, …; "Only In Sandbox" absent
sandbox: locations Sandbox HQ, Test Kitchen, …; "Only In Sandbox" present after the write
hops-baseline: frontend(baseline) → location(baseline) → mysql(location)
hops-sandbox: frontend(baseline) → location(location-db<suffix>) → mysql(location_<key>)
proof: the sandbox read and wrote its own database location_<key>; the baseline data didn't change
commands: sd resourceplugin apply -f assets/specs/data/hotrod-trial-db-plugin.yaml …; sd sandbox apply -f assets/specs/data/location-db.yaml …
specs: assets/specs/data/hotrod-trial-db-plugin.yaml, assets/specs/data/location-db.yaml
links: https://www.signadot.com/docs/tutorials/testing-database-schema-changes
try: book rides on both links; delete the sandbox and watch location_<key> disappear
```

## Try it yourself

- Book rides on the baseline and sandbox links: the sandbox's pickup and drop-off locations come from its own
  database.
- See the sandbox's database next to the shared one:
  `kubectl --kubeconfig <T>/kubeconfig -n hotrod exec mysql-0 -c mysql -- mariadb -uroot -pabc -N -e "SHOW DATABASES LIKE 'location\_%'"`.
- Delete the sandbox (`<T>/bin/sd sandbox delete location-db<suffix>`) and run that command again: the plugin drops
  `location_<key>` within a minute. Apply the sandbox again to get a fresh database.

## Tear down

```bash
"$T/bin/sd" sandbox delete location-db<suffix>
"$T/bin/kc" -n hotrod exec mysql-0 -c mysql -- mariadb -uroot -pabc -N -e "SHOW DATABASES LIKE 'location\_%'"   # until location_<key> is gone
"$T/bin/sd" resourceplugin delete hotrod-trial-db<suffix>
```

Delete the plugin only after every sandbox that uses it is gone, or its delete step can't run.

## Docs

https://www.signadot.com/docs/tutorials/testing-database-schema-changes.md uses the same MariaDB plugin to test a
schema change, with an image build. The trial keeps the baseline image and only changes the data. For the other
ways to isolate data, see https://www.signadot.com/docs/guides/set-up-data-isolation.md.
