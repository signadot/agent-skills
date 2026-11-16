# A database per sandbox

`<cluster>`, `<suffix>`, `<proxy>` and `<key>` as in SKILL.md.

## What it shows

The page's four sections come from these (`references/finish/report.md`, "Writing a scenario page"):

- **The demo app:** HotROD; location is the changed service, and its database matters here.
- **The change:** location reads the pickup and drop-off locations from MySQL (MariaDB). The change is the data:
  the sandbox's location, the same image, reads a database seeded with other locations, as a change that adds or
  rewrites data would need.
- **The sandbox:** a copy of `location` whose `MYSQL_DBNAME` comes from the resource. Also created: the database
  `location_<routing key>` on HotROD's MariaDB, made by the resource plugin `hotrod-trial-db<suffix>` when the
  sandbox is created, seeded with other locations, and dropped when the sandbox is deleted.
- **Routing:** the sandbox's preview link adds its key; the sidecar in the normal location's pod forwards frontend's
  calls with the key to the sandbox's location, which uses its own database.

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

For the page's diagram: without key `frontend(baseline) → location(baseline) → MySQL: location`; with key
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

- **Baseline:** open the baseline link: the pickup and drop-off lists show HotROD's usual locations, like "My Home".
- **Sandbox:** open the sandbox's link: the lists show the sandbox's own, "Sandbox HQ", "Test Kitchen", "Staging
  Cafe"….
- **Check:** follow `Loading location` in the normal location (`deploy/location`) and in
  `location-db<suffix>-dep-location-…`: sandbox requests appear only in the second. List the sandbox's database:
  `kubectl --kubeconfig <T>/kubeconfig -n hotrod exec mysql-0 -c mysql -- mariadb -uroot -pabc -N -e "SHOW DATABASES LIKE 'location\_%'"`
  prints `location_<key>`.
- **More:** write a location with the key and see it only with the key (the curl commands under Prove it, to the
  cluster addresses, after the reconnect); delete the sandbox (`<T>/bin/sd sandbox delete location-db<suffix>`) and
  list the databases again: the plugin drops `location_<key>` within a minute. Apply the sandbox again for a fresh
  database.

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
