---
name: hot-dev-env
description: Start, check and troubleshoot the local HOTOSM environment (Traefik + mkcert on *.hotosm.test, Hanko SSO, per-app Docker services). Use when bringing up an app locally, testing HOT Login end to end, or when a container, certificate, database or `make dev` fails, especially on macOS.
---

# hot-dev-env

Apps live as **sibling repos** of `hot-dev-env` (`../portal`, `../login`,
`../openaerialmap`, …), never inside it. Compose builds from `../<repo>`.

## Start only what the task needs

`make dev` runs ~40 containers and is the most likely to fail. Prefer:

```bash
make dev-oam        # or dev-portal, dev-dronetm, dev-fair, …
docker compose up -d <service> [<service> …]   # anything finer
```

Sign-in needs `hanko`, `hanko-db`, `login-frontend` and `login-backend`: the
`<hotosm-auth>` "Log in" button opens `https://login.hotosm.test/app`.
Verification codes arrive at `https://mail.hotosm.test` (Mailhog).

## Check it works

```bash
make health
docker ps -a --filter name=hotosm- --format '{{.Names}}\t{{.Status}}'
```

`Exited (0)` on `*-migrate`, `*-init` and `*-migration` containers is normal.
`Created` means a dependency failed before it started.

curl does not read the macOS Keychain. Pass the mkcert CA:

```bash
curl --cacert "$(mkcert -CAROOT)/rootCA.pem" https://openaerialmap.hotosm.test
```

To test CORS for an app origin against Hanko:

```bash
curl --cacert "$(mkcert -CAROOT)/rootCA.pem" -s -D - -o /dev/null -X OPTIONS \
  https://login.hotosm.test/sessions/validate \
  -H "Origin: https://<app>.hotosm.test" -H "Access-Control-Request-Method: GET"
```

## Known failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| Browser rejects the cert; it is `TRAEFIK DEFAULT CERT` | `traefik-tls.yml` is an empty directory Docker created | `rmdir traefik-tls.yml && git checkout -- traefik-tls.yml`, then `docker compose up -d --force-recreate traefik` |
| `initdb: ... No space left on device` | Docker's virtual disk is full | `docker system df`, `docker builder prune`; raise the virtual disk limit only if the host has room. Never prune volumes without asking. |
| `make mountpoint ... file exists` / `outside of rootfs` on `export-tool-app` | Docker Desktop (macOS) cannot bind a file inside a bind-mounted folder | Start the needed app with its own target |
| `Permission denied (publickey)` from a non-interactive shell | No key in the ssh agent | Read-only: fetch over HTTPS. Pushing: the user runs it from their terminal |
| A 404 after clicking "Log in" | `login-frontend` is not running | `docker compose up -d login-frontend login-backend` |
| Edited a single-file bind mount and the app shows `ENOENT` | The editor replaced the file, so the container holds a deleted inode | `docker compose up -d --force-recreate <service>` |

## Rules

- Keep the repos out of iCloud Drive or other synced folders.
- `docker compose stop` is safe; `make clean` and `down -v` delete volumes.
  Ask before either.
- Adding a site to local SSO means adding its origin to
  `config/hanko-config.yaml` (CORS and redirect URLs) and a hosts entry
  (`scripts/add-hosts.sh`), then restarting `hanko`.
