# Contributing

1. Open an issue before a large change. One change per pull request.
2. A tool is added to `tools/catalog.yaml` with its license, the version the
   platform ships and the plugins that use it; then run
   `scripts/check.py --write`.
3. A chart change bumps the `version` of every chart it touches (`ct lint`
   refuses a chart change without a version bump). Run `scripts/check.sh`,
   and `IMAGES=local scripts/e2e.sh` for anything that changes what runs.
4. Charts consume released nochaos images only: product changes go to
   [nochaos](https://github.com/nochaosio/nochaos).
5. Never use the middle dot character as a separator in any text.
6. Sign your commits off (`git commit -s`): the
   [Developer Certificate of Origin](https://developercertificate.org/).
