# nochaos-deploy

How to run **nochaos**, and the catalog of the open-source tools it is built on.

## Software on one side, machines on the other

nochaos keeps a strict line:

- **The software** (the platform and its plugins) does not know where it
  runs. It is the same code on a laptop and on a large cluster. It lives in
  `nochaos` and [`nochaos-plugins`](https://github.com/nochaosio/nochaos-plugins).
- **The topology** (how many machines, which tools, how they are wired) lives
  here. This repository holds recipes and no product code: it only consumes
  released versions of the software.

So improving the product and scaling an installation are separate jobs that
do not block each other.

## Profiles

| Profile | For | How it runs | Status |
|---|---|---|---|
| [`single`](profiles/single) | One person or a small team, low volume | One machine, Docker Compose, few tools | planned |
| [`ha`](profiles/ha) | A company self-hosting at volume | Kubernetes (Helm), components scaled apart | planned |
| cloud | The managed service | Operated by the nochaos team | not in this repository |

The recipes land here as the platform gains the mode each one needs (see each
profile). Nothing in this repository is a working installer yet: this is the
layout and the decisions, written before the code so they can be reviewed.

## Capabilities

A profile does not run every tool, so it does not offer everything. Each
installation tells the platform which **capabilities** it has, and each plugin
declares the ones it needs. A plugin whose capabilities are missing shows as
unavailable in that installation, with the reason, instead of failing.

| Capability | Provided by | single | ha | cloud |
|---|---|---|---|---|
| `metrics-store` | VictoriaMetrics, or ClickHouse in `single` | yes | yes | yes |
| `logs-store` | VictoriaLogs, or ClickHouse in `single` | yes | yes | yes |
| `traces-store` | VictoriaTraces, or ClickHouse in `single` | yes | yes | yes |
| `events-store` | ClickHouse | yes | yes | yes |
| `object-store` | Garage or any S3, or local disk in `single` | yes | yes | yes |
| `stream-aggregation` | Apache Flink, or in-process aggregation in `single` | partial | optional | yes |
| `internet-egress` | The network (the platform can reach the internet) | operator's choice | operator's choice | yes |

"partial" is the honest word for `single`: aggregations that need Flink today
(usage, quotas, SLOs, log patterns, the service graph) need an in-process
version before they work there.

## Tools

nochaos is a layer above open-source tools, and says which. The full list,
with licenses, versions and which plugins use each one: **[TOOLS.md](TOOLS.md)**
(generated from [tools/catalog.yaml](tools/catalog.yaml)).

## Check

```sh
pip install pyyaml
scripts/check.py           # the catalog is valid and TOOLS.md is up to date
scripts/check.py --write   # regenerate TOOLS.md after editing the catalog
```

## License

Apache-2.0.
