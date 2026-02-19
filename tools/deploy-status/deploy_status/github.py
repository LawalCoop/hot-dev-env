"""GitHub API client for fetching workflow status."""

import asyncio
import subprocess
from datetime import datetime
from typing import Optional

import httpx

from .models import App, BranchComparison, BranchCompareConfig, Commit, Environment, Release, Status, Workflow


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
        # Build API URL with query params
        api_path = f"repos/{repo}/actions/runs?branch={branch}&per_page=1"
        if workflow_name:
            # Need to get workflow ID first or filter by name after
            pass

        jq_filter = '.workflow_runs[0] | {id, status, conclusion, created_at, updated_at, actor: .actor.login, workflow_name: .name}'

        cmd = ["gh", "api", api_path, "--jq", jq_filter]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return {"status": Status.NONE, "error": stderr.decode()}

        import json
        output = stdout.decode().strip()
        if not output or output == "null":
            return {"status": Status.NONE}

        run = json.loads(output)

        status_str = run.get("status", "")
        conclusion = run.get("conclusion", "")
        created_at = run.get("created_at", "")
        updated_at = run.get("updated_at", "")
        run_id = run.get("id")
        actor = run.get("actor", "")

        # If workflow_name specified, verify it matches
        if workflow_name and run.get("workflow_name") != workflow_name:
            # Fallback to gh run list for specific workflow
            return await _fetch_workflow_status_by_name(repo, branch, workflow_name)

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
            "actor": actor,
        }

    except Exception as e:
        return {"status": Status.NONE, "error": str(e)}


async def _fetch_workflow_status_by_name(repo: str, branch: str, workflow_name: str) -> dict:
    """Fetch workflow status for a specific workflow name."""
    try:
        cmd = [
            "gh", "run", "list",
            "-R", repo,
            "--branch", branch,
            "--workflow", workflow_name,
            "-L", "1",
            "--json", "status,conclusion,createdAt,databaseId,updatedAt",
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            return {"status": Status.NONE}

        import json
        data = json.loads(stdout.decode())

        if not data:
            return {"status": Status.NONE}

        run = data[0]
        run_id = run.get("databaseId")

        # Get actor from API
        actor = ""
        if run_id:
            actor_cmd = ["gh", "api", f"repos/{repo}/actions/runs/{run_id}", "--jq", ".actor.login"]
            actor_proc = await asyncio.create_subprocess_exec(
                *actor_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            actor_stdout, _ = await actor_proc.communicate()
            if actor_proc.returncode == 0:
                actor = actor_stdout.decode().strip()

        status_str = run.get("status", "")
        conclusion = run.get("conclusion", "")
        created_at = run.get("createdAt", "")
        updated_at = run.get("updatedAt", "")

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
            "actor": actor,
        }

    except Exception:
        return {"status": Status.NONE}


async def fetch_error_logs(repo: str, run_id: int, max_lines: int = 500) -> list[str]:
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
            workflow.actor = result.get("actor")

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
        env.actor = result.get("actor")

        if env.status == Status.FAILURE and env.run_id:
            env.error_lines = await fetch_error_logs(env.repo, env.run_id)

    # Fetch latest commit
    env.last_commit = await fetch_latest_commit(env.repo, env.branch)

    return env


async def fetch_health_check(env: Environment) -> None:
    """Check if the environment URL is responding."""
    if not env.url:
        return

    url = f"https://{env.url}"
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            import time
            start = time.monotonic()
            response = await client.get(url)
            latency = int((time.monotonic() - start) * 1000)

            env.health_code = response.status_code
            env.health_latency_ms = latency
            env.health_ok = 200 <= response.status_code < 400
    except httpx.TimeoutException:
        env.health_ok = False
        env.health_error = "Timeout"
    except httpx.ConnectError:
        env.health_ok = False
        env.health_error = "Connection failed"
    except Exception as e:
        env.health_ok = False
        env.health_error = str(e)[:50]


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

    # Fetch latest release if tracking releases
    if app.track_releases and repo:
        app.latest_release = await fetch_latest_release(repo)

    app.loading = False
    return app


async def fetch_latest_release(repo: str) -> Optional[Release]:
    """Fetch the latest release and its build status."""
    try:
        # Get latest release
        cmd = [
            "gh", "api", f"repos/{repo}/releases/latest",
            "--jq", '{tag: .tag_name, name: .name, published: .published_at, author: .author.login}'
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

        published = None
        if data.get("published"):
            try:
                published = datetime.fromisoformat(data["published"].replace("Z", "+00:00"))
            except ValueError:
                pass

        release = Release(
            tag=data.get("tag", ""),
            name=data.get("name", ""),
            author=data.get("author", ""),
            published=published,
        )

        # Get build status for this release
        # Look for workflow runs triggered by the release
        run_cmd = [
            "gh", "api", f"repos/{repo}/actions/runs?event=release&per_page=5",
            "--jq", f'[.workflow_runs[] | select(.head_branch == "{release.tag}" or .display_title == "{release.tag}")] | .[0] | {{id, status, conclusion}}'
        ]

        run_proc = await asyncio.create_subprocess_exec(
            *run_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        run_stdout, _ = await run_proc.communicate()

        if run_proc.returncode == 0:
            run_output = run_stdout.decode().strip()
            if run_output and run_output != "null":
                run_data = json.loads(run_output)
                status_str = run_data.get("status", "")
                conclusion = run_data.get("conclusion", "")
                release.build_run_id = run_data.get("id")

                if status_str == "completed":
                    release.build_status = Status.SUCCESS if conclusion == "success" else Status.FAILURE
                elif status_str in ("in_progress", "queued", "waiting"):
                    release.build_status = Status.RUNNING
                else:
                    release.build_status = Status.NONE

        return release

    except Exception:
        return None


def open_in_browser(url: str) -> None:
    """Open a URL in the default browser."""
    import webbrowser
    webbrowser.open(url)


def open_github_run(repo: str, run_id: int) -> None:
    """Open a GitHub Actions run in the browser."""
    url = f"https://github.com/{repo}/actions/runs/{run_id}"
    open_in_browser(url)
