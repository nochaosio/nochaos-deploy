#!/bin/sh
# Lays out the single Garage node, creates the bucket and imports the key
# the services use. Idempotent: safe on every install and upgrade.
set -eu
A="http://$GARAGE_HOST:3903/v2"
api() { out=$(curl -fs -H "Authorization: Bearer $GARAGE_ADMIN_TOKEN" -H 'Content-Type: application/json' "$@") || return 1; printf '%s' "$out" | tr -d ' \n'; }
until api "$A/GetClusterStatus" >/dev/null 2>&1; do echo "waiting for garage"; sleep 2; done
node=$(api "$A/GetClusterStatus" | sed -n 's/.*"nodes":\[{"id":"\([0-9a-f]*\)".*/\1/p')
layout=$(api "$A/GetClusterLayout")
case $layout in
  *'"roles":[]'*)
    api -X POST -d "{\"roles\":[{\"id\":\"$node\",\"zone\":\"dc1\",\"capacity\":$GARAGE_CAPACITY,\"tags\":[]}]}" "$A/UpdateClusterLayout" >/dev/null
    ver=$(echo "$layout" | sed -n 's/^{"version":\([0-9]*\).*/\1/p')
    api -X POST -d "{\"version\":$((ver + 1))}" "$A/ApplyClusterLayout" >/dev/null
    echo "layout applied (node $node)" ;;
esac
# The first writes fail with "Layout not ready" for a few seconds after the layout.
retry() { i=0; until "$@"; do i=$((i + 1)); [ $i -lt 60 ] || return 1; sleep 2; done; }
ensure_bucket() { api "$A/GetBucketInfo?globalAlias=$S3_BUCKET" >/dev/null 2>&1 || api -X POST -d "{\"globalAlias\":\"$S3_BUCKET\"}" "$A/CreateBucket" >/dev/null; }
ensure_key() { api "$A/GetKeyInfo?id=$S3_ACCESS_KEY" >/dev/null 2>&1 ||
  api -X POST -d "{\"accessKeyId\":\"$S3_ACCESS_KEY\",\"secretAccessKey\":\"$S3_SECRET_KEY\",\"name\":\"nochaos\"}" "$A/ImportKey" >/dev/null; }
retry ensure_bucket
retry ensure_key
bucket=$(api "$A/GetBucketInfo?globalAlias=$S3_BUCKET" | sed -n 's/^{"id":"\([0-9a-f]*\)".*/\1/p')
api -X POST -d "{\"bucketId\":\"$bucket\",\"accessKeyId\":\"$S3_ACCESS_KEY\",\"permissions\":{\"read\":true,\"write\":true,\"owner\":true}}" "$A/AllowBucketKey" >/dev/null
echo "garage: bucket $S3_BUCKET ready"
