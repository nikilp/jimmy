# BG Delivery Site

Static site for BG Delivery, built from the redesigned content and mirrored media assets in this workspace.

## Local development

Build the site:

```bash
python3 scripts/build_site.py
python3 scripts/check_site.py dist
```

Preview locally:

```bash
cd dist
python3 -m http.server 8000
```

Then open `http://localhost:8000/`.

## Deployment

The repo is set up for GitHub Actions deployment to the existing EC2 instance.

Required repository secrets:

- `EC2_HOST`
- `EC2_USER`
- `EC2_SSH_KEY`

The deploy workflow:

1. Builds `dist/`
2. Validates links and assets
3. Uploads a release bundle over SSH
4. Builds the Docker image on EC2
5. Restarts the `jimmy-site` container on `127.0.0.1:18503`

Server-side nginx should proxy `jimmy.outfinity.net` to `127.0.0.1:18503`.

The relevant files are:

- `scripts/build_site.py`
- `scripts/check_site.py`
- `deploy/server/deploy-jimmy.sh`
- `deploy/nginx/jimmy.outfinity.net.conf`
- `.github/workflows/deploy-jimmy.yml`
