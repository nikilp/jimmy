#!/usr/bin/env bash

set -Eeuo pipefail

ARCHIVE_PATH="${1:-}"
APP_ROOT="${APP_ROOT:-/home/ubuntu/projects/jimmy}"
RELEASE_DIR="${APP_ROOT}/release"
APP_CONTAINER="${APP_CONTAINER:-jimmy-site}"
APP_PORT="${APP_PORT:-18503}"
IMAGE_NAME="${IMAGE_NAME:-jimmy-site}"
HEALTH_PATH="${HEALTH_PATH:-/healthz/}"

if [[ -z "${ARCHIVE_PATH}" || ! -f "${ARCHIVE_PATH}" ]]; then
  echo "Usage: deploy-jimmy.sh /path/to/jimmy-site.tgz" >&2
  exit 1
fi

mkdir -p "${RELEASE_DIR}"
rm -rf "${RELEASE_DIR:?}"/*
tar -xzf "${ARCHIVE_PATH}" -C "${RELEASE_DIR}"

IMAGE_TAG="$(date +%Y%m%d%H%M%S)"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"

docker build -t "${IMAGE_REF}" "${RELEASE_DIR}"

if docker inspect "${APP_CONTAINER}" >/dev/null 2>&1; then
  docker rm -f "${APP_CONTAINER}"
fi

docker run -d \
  --name "${APP_CONTAINER}" \
  --restart unless-stopped \
  -p "127.0.0.1:${APP_PORT}:80" \
  "${IMAGE_REF}"

echo "Waiting for health check..."
for attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${APP_PORT}${HEALTH_PATH}" >/dev/null 2>&1; then
    docker image prune -f >/dev/null 2>&1 || true
    echo "Deployment healthy on attempt ${attempt}"
    exit 0
  fi
  sleep 2
done

echo "Health check failed; recent logs:" >&2
docker logs --tail 200 "${APP_CONTAINER}" >&2 || true
exit 1
