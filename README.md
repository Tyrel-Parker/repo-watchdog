# repo-watchdog

A lightweight bash script for homelab servers that sends a daily [ntfy](https://ntfy.sh) notification summarizing the health of all your local git repos. No dashboard, no polling — just a morning digest if something needs your attention.

## What it checks

For every repo found in `REPOS_DIR`:

- **Uncommitted changes** — staged, unstaged, or untracked files
- **Unpushed commits** — local commits not yet on origin
- **Unpulled commits** — commits on origin you haven't pulled
- **Fork divergence** — if an `upstream` remote is configured, reports commits ahead of or behind upstream

Only sends a notification if there is actually something to report.

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/youruser/repo-watchdog.git
   ```

2. Copy and configure the env file:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your `REPOS_DIR`, `NTFY_URL`, and `NTFY_TOPIC`.

3. Make the script executable:
   ```bash
   chmod +x watchdog.sh
   ```

4. Test it:
   ```bash
   ./watchdog.sh
   ```

5. Schedule it with cron. To run every morning at 8am:
   ```bash
   crontab -e
   ```
   Add:
   ```
   0 8 * * * /path/to/repo-watchdog/watchdog.sh
   ```

## Fork monitoring

If you have a forked repo and want to track divergence from the upstream source, add an `upstream` remote to that repo:

```bash
git remote add upstream https://github.com/original-owner/original-repo.git
```

repo-watchdog will automatically detect it and include upstream comparisons in the digest.

## ntfy authentication

If your ntfy instance requires authentication, add your access token to `.env`:

```
NTFY_TOKEN=your-token-here
```

## Requirements

- `bash` 4+
- `git`
- `curl`
- A running [ntfy](https://ntfy.sh) instance (self-hosted or ntfy.sh)
