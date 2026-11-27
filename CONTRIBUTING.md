# Contributing

- One change per pull request, and bump the `version` of every chart it
  touches (`ct lint` refuses a chart change without a version bump).
- Run `scripts/check.sh`, and `IMAGES=local scripts/e2e.sh` for anything that
  changes what runs.
- Charts consume released nochaos images only: product changes go to
  [nochaos](https://github.com/nochaosio/nochaos).
- Never use the middle dot character as a separator in any text.
