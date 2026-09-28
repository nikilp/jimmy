#!/usr/bin/env bash
# Runs ON THE HOST, sent over SSM by the deploy workflow (scripts/ssm-run.sh).
#
# Takes the place of the old scp + ssh steps: fetch the bundle the workflow
# uploaded to S3, then run the unchanged deploy/server/deploy-jimmy.sh as
# ubuntu, exactly as the SSH deploy did, and check health.
#
# Expects BUNDLE_URI, AWS_REGION, APP_ROOT, APP_PORT, HEALTH_PATH.
set -euo pipefail

work="$(mktemp -d /tmp/jimmy-deploy.XXXXXX)"
trap 'rm -rf "$work"' EXIT

aws s3 cp "$BUNDLE_URI" "$work/bundle.tgz" --region "$AWS_REGION" --only-show-errors
tar -xzf "$work/bundle.tgz" -C "$work"
chown -R ubuntu:ubuntu "$work"
chmod +x "$work/deploy-jimmy.sh"

sudo -u ubuntu -H env APP_ROOT="$APP_ROOT" APP_PORT="$APP_PORT" HEALTH_PATH="$HEALTH_PATH" \
  "$work/deploy-jimmy.sh" "$work/jimmy-site.tgz" </dev/null

curl -fsS "http://127.0.0.1:${APP_PORT}${HEALTH_PATH}" >/dev/null
echo "Jimmy healthy"
