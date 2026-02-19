"""GitHub API client for fetching workflow status."""

import asyncio
import subprocess
from datetime import datetime
from typing import Optional

import httpx

from .models import App, BranchComparison, BranchCompareConfig, Commit, Environment, Status, Workflow


async def fetch_workflow_status(
    client: httpx.AsyncClient,
    repo: str,
    branch: str,
    workflow_name: Optional[str] = None,
) -> dict:
    """Fetch the latest workflow run status from GitHub API."""
    if not repo or not branch:
        return {"status": Status.NONE}

    try:
        # Use gh CLI to get the status (handles auth automatically)
        cmd = [
            "gh", "run", "list",
            "-R", repo,
            "--branch", branch,
            "-L", "1",
            "--json", "status,conclusion,createdAt,databaseId,updatedAt,name,workflowName",
        ]

        if workflow_name:
            cmd.extend(["--workflow", workflow_name])

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return {"status": Status.NONE, "error": stderr.decode()}

        import json
        data = json.loads(stdout.decode())

        if not data:
            return {"status": Status.NONE}

        run = data[0]
        status_str = run.get("status", "")
        conclusion = run.get("conclusion", "")
        created_at = run.get("createdAt", "")
        updated_at = run.get("updatedAt", "")
        run_id = run.get("databaseId")

        # Parse time
        time = None
        duration = None
        if created_at:
            try:
                time = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                if updated_at:
                    end_time = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
                    duration = int((end_time - time).total_seconds())
            except ValueError:
                pass

        # Determine status
        if status_str == "completed":
            status = Status.SUCCESS if conclusion == "success" else Status.FAILURE
        elif status_str in ("in_progress", "queued", "waiting"):
            status = Status.RUNNING
        else:
            status = Status.NONE

        return {
            "status": status,
            "run_id": run_id,
            "time": time,
            "duration_seconds": duration,
        }

    except Exception as e:
        return {"status": Status.NONE, "error": str(e)}


async def fetch_error_logs(repo: str, run_id: int, max_lines: int = 30) -> list[str]:
    """Fetch error logs for a failed run."""
    try:
        cmd = [
            "gh", "run", "view",
            str(run_id),
            "-R", repo,
            "--log-failed",
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return []

        lines = stdout.decode().strip().split("\n")
        return lines[-max_lines:] if len(lines) > max_lines else lines

    except Exception:
        return []


async def fetch_latest_commit(repo: str, branch: str) -> Optional[Commit]:
    """Fetch the latest commit for a branch."""
    if not repo or not branch:
        return None

    try:
        cmd = [
            "gh", "api",
            f"repos/{repo}/commits/{branch}",
            "--jq", '{sha: .sha[0:7], message: .commit.message, author: .commit.author.name, date: .commit.author.date}',
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return None

        import json
        data = json.loads(stdout.decode())

        # Parse date
        commit_date = None
        if data.get("date"):
            try:
                commit_date = datetime.fromisoformat(data["date"].replace("Z", "+00:00"))
            except ValueError:
                pass

        # Truncate message to first line and limit length
        message = data.get("message", "").split("\n")[0][:60]

        return Commit(
            sha=data.get("sha", ""),
            message=message,
            author=data.get("author", ""),
            date=commit_date,
        )

    except Exception:
        return None


async def fetch_branch_comparison(repo: str, config: BranchCompareConfig) -> BranchComparison:
    """Fetch comparison between two branches."""
    comparison = BranchComparison(base=config.base, head=config.head)

    if not repo:
        return comparison

    try:
        cmd = [
            "gh", "api",
            f"repos/{repo}/compare/{config.base}...{config.head}",
            "--jq", '{ahead_by, behind_by, commits: [.commits[-5:][] | {sha: .sha[0:7], message: .commit.message, author: .commit.author.name, date: .commit.author.date}]}',
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return comparison

        import json
        data = json.loads(stdout.decode())

        comparison.ahead_by = data.get("ahead_by", 0)
        comparison.behind_by = data.get("behind_by", 0)

        # Parse commits
        for c in data.get("commits", []):
            commit_date = None
            if c.get("date"):
                try:
                    commit_date = datetime.fromisoformat(c["date"].replace("Z", "+00:00"))
                except ValueError:
                    pass

            message = c.get("message", "").split("\n")[0][:50]
            comparison.commits.append(Commit(
                sha=c.get("sha", ""),
                message=message,
                author=c.get("author", ""),
                date=commit_date,
            ))

        return comparison

    except Exception:
        return comparison


async def fetch_environment_status(env: Environment) -> Environment:
    """Fetch status for an environment."""
    if not env.repo:
        env.status = Status.NONE
        return env

    if env.has_workflows:
        # Fetch each workflow separately
        for workflow in env.workflows:
            result = await fetch_workflow_status(
                None, workflow.repo, workflow.branch, workflow.name
            )
            workflow.status = result.get("status", Status.NONE)
            workflow.run_id = result.get("run_id")
            workflow.time = result.get("time")
            workflow.duration_seconds = result.get("duration_seconds")

            if workflow.status == Status.FAILURE and workflow.run_id:
                workflow.error_lines = await fetch_error_logs(
                    workflow.repo, workflow.run_id
                )
    else:
        result = await fetch_workflow_status(None, env.repo, env.branch)
        env.status = result.get("status", Status.NONE)
        env.run_id = result.get("run_id")
        env.time = result.get("time")
        env.duration_seconds = result.get("duration_seconds")

        if env.status == Status.FAILURE and env.run_id:
            env.error_lines = await fetch_error_logs(env.repo, env.run_id)

    # Fetch latest commit
    env.last_commit = await fetch_latest_commit(env.repo, env.branch)

    return env


async def fetch_app_status(app: App) -> App:
    """Fetch status for all environments of an app."""
    # Fetch dev and prod in parallel
    app.dev, app.prod = await asyncio.gather(
        fetch_environment_status(app.dev),
        fetch_environment_status(app.prod),
    )

    # Fetch branch comparisons if configured
    repo = app.dev.repo or app.prod.repo
    if repo and app.compare_configs:
        comparisons = await asyncio.gather(*[
            fetch_branch_comparison(repo, config)
            for config in app.compare_configs
        ])
        app.comparisons = list(comparisons)

    app.loading = False
    return app


def open_in_browser(url: str) -> None:
    """Open a URL in the default browser."""
    import webbrowser
    webbrowser.open(url)


def open_github_run(repo: str, run_id: int) -> None:
    """Open a GitHub Actions run in the browser."""
    url = f"https://github.com/{repo}/actions/runs/{run_id}"
    open_in_browser(url)
