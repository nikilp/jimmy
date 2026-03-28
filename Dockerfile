FROM nginx:1.27-alpine

COPY deploy/nginx/container.default.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1/healthz/ >/dev/null 2>&1 || exit 1
