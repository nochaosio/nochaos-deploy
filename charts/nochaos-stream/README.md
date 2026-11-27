# nochaos-stream

Stream analytics for a nochaos community installation: one Kafka node (KRaft)
with the topics the pipeline writes, and one Flink pod (JobManager and
TaskManager) running the community jobs: usage aggregator, telemetry
insights, trace analytics, log patterns and schema drift. A post-install job
submits every job that does not run the image's build.

Install it with the same prefix as nochaos-platform, and set
`stream.enabled=true` on the platform (the [nochaos](../nochaos) chart does
both with `global.stream.enabled=true`). It reads the platform's Secret for
the PostgreSQL and Redis passwords. Every value: [values.yaml](values.yaml).
