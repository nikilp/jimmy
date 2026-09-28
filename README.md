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

It deploys over AWS Systems Manager (SSM), so the runner never opens an SSH
connection to the host.

Required repository settings:

- secret `AWS_ROLE_TO_ASSUME`: `arn:aws:iam::599019184800:role/github-actions-jimmy-deploy`
- secret `EC2_INSTANCE_ID`: the shared host
- variable `DEPLOY_ARTIFACTS_BUCKET`: where deploy bundles are staged

The role, the bucket and their permissions are defined in
`outfinity-ops` (`terraform/deploy-access`).

The deploy workflow:

1. Builds `dist/`
2. Validates links and assets
3. Uploads a release bundle to S3
4. Runs `deploy/ssm/remote-deploy.sh` on the host over SSM, which builds the
   Docker image there with `deploy/server/deploy-jimmy.sh`
5. Restarts the `jimmy-site` container on `127.0.0.1:18503` and checks health

Server-side nginx should proxy `jimmy.outfinity.net` to `127.0.0.1:18503`.

The relevant files are:

- `scripts/build_site.py`
- `scripts/check_site.py`
- `deploy/server/deploy-jimmy.sh`
- `deploy/nginx/jimmy.outfinity.net.conf`
- `.github/workflows/deploy-jimmy.yml`
