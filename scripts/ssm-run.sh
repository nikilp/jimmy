#!/usr/bin/env bash
# Run a script on the shared host through SSM and report what it printed.
#
#   scripts/ssm-run.sh <comment> <script> <timeout-seconds> [NAME=value ...]
#
# Replaces "ssh host '...'" in the deploy workflows: the runner never connects
# to the host, so port 22 does not have to be open to GitHub's runners. The
# NAME=value pairs are exported at the top of the remote script, quoted with
# printf %q, so a value is never re-parsed by a second shell.
#
# Needs INSTANCE_ID, and AWS credentials allowed to ssm:SendCommand on it
# (the SsmDeploy policy in outfinity-ops terraform/deploy-access).
set -euo pipefail

: "${INSTANCE_ID:?INSTANCE_ID is required}"
comment="${1:?comment is required}"
script="${2:?script path is required}"
timeout="${3:?timeout in seconds is required}"
shift 3

remote="$(mktemp)"
trap 'rm -f "$remote"' EXIT
{
  # SSM runs the command as a file and honours its shebang; without one the
  # host falls back to dash, which rejects bash scripts.
  echo '#!/usr/bin/env bash'
  for kv in "$@"; do
    printf 'export %s=%q\n' "${kv%%=*}" "${kv#*=}"
  done
  sed '1{/^#!/d;}' "$script"
} > "$remote"

cmd_id="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --comment "${comment:0:100}" \
  --timeout-seconds 120 \
  --parameters "$(jq -n --rawfile s "$remote" --arg t "$timeout" '{commands: [$s], executionTimeout: [$t]}')" \
  --query 'Command.CommandId' --output text)"
echo "SSM command ${cmd_id}: ${comment}"

status=Pending
deadline=$(( $(date +%s) + timeout + 180 ))
while :; do
  status="$(aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
    --query 'Status' --output text 2>/dev/null || echo Pending)"
  case "$status" in
    Success|Failed|Cancelled|TimedOut|Undeliverable|Terminated) break ;;
  esac
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "Gave up waiting for ${cmd_id} (last status ${status})." >&2
    break
  fi
  sleep 10
done

# SSM keeps the first 24,000 characters of each stream; enough for deploy logs.
echo "--- remote stdout ---"
aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
  --query 'StandardOutputContent' --output text || true
echo "--- remote stderr ---"
aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
  --query 'StandardErrorContent' --output text || true
echo "SSM status: ${status}"
[ "$status" = Success ]
