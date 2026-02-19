"""Detail view widget for showing app deployment details."""

import asyncio
import platform
import subprocess
from datetime import datetime, timezone
from typing import Optional

from textual.app import ComposeResult
from textual.containers import Vertical, Horizontal, VerticalScroll
from textual.widgets import Static, Button, LoadingIndicator, TabbedContent, TabPane
from textual.message import Message

import humanize

from ..models import App, BranchComparison, Commit, Environment, Release, Status, Workflow, get_status_icon
from ..github import fetch_health_check


def copy_to_clipboard(text: str) -> bool:
    """Copy text to clipboard. Returns True if successful."""
    try:
        if platform.system() == "Darwin":
            subprocess.run(["pbcopy"], input=text.encode(), check=True)
        else:
            # Linux - try xclip first, then xsel
            try:
                subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode(), check=True)
            except FileNotFoundError:
                subprocess.run(["xsel", "--clipboard", "--input"], input=text.encode(), check=True)
        return True
    except Exception:
        return False


class DetailView(Static):
    """A detailed view of an app's deployment status."""

    DEFAULT_CSS = """
    DetailView {
        width: 100%;
        height: 100%;
        padding: 1 2;
        background: $surface;
    }

    DetailView > Vertical {
        height: 100%;
    }

    DetailView TabbedContent {
        height: 1fr;
    }

    DetailView ContentSwitcher {
        height: 1fr;
    }

    DetailView TabPane {
        height: 100%;
    }

    DetailView TabPane > VerticalScroll {
        height: 100%;
    }

    DetailView .detail-header {
        height: 3;
        margin-bottom: 1;
        border-bottom: solid $surface-lighten-2;
    }

    DetailView .detail-title {
        text-style: bold;
        width: auto;
    }

    DetailView .detail-icon {
        width: 3;
        margin-right: 1;
    }

    DetailView .close-btn {
        dock: right;
        width: auto;
        min-width: 8;
    }

    DetailView .release-section {
        margin: 0 0 1 0;
        padding: 1;
        border: solid $primary 50%;
        background: $primary 10%;
    }

    DetailView .release-tag {
        color: $primary;
        text-style: bold;
    }

    DetailView .env-section {
        margin: 1 0;
        padding: 1;
        border: solid $surface-lighten-2;
    }

    DetailView .env-section.success {
        border: solid $success 50%;
    }

    DetailView .env-section.failure {
        border: solid $error 50%;
    }

    DetailView .env-section.running {
        border: solid $warning 50%;
    }

    DetailView .section-title {
        text-style: bold;
        margin-bottom: 1;
    }

    DetailView .info-row {
        height: 1;
    }

    DetailView .info-label {
        width: 12;
        color: $text-muted;
    }

    DetailView .info-value {
        width: 1fr;
    }

    DetailView .workflow-section {
        margin-top: 1;
        padding-left: 2;
    }

    DetailView .workflow-title {
        text-style: italic;
        margin-bottom: 1;
    }

    DetailView .error-section {
        margin-top: 0;
        padding: 1;
        background: $error 10%;
        border: solid $error 50%;
        height: auto;
    }

    DetailView .error-header {
        height: 3;
        margin-top: 1;
    }

    DetailView .copy-btn {
        width: 4;
        min-width: 4;
        height: 1;
        padding: 0;
        margin-left: 1;
        border: none;
        background: transparent;
    }

    DetailView .copy-error-btn {
        width: 12;
        min-width: 12;
        height: 3;
        margin-left: 2;
    }

    DetailView .commit-section {
        margin-top: 1;
        padding: 0 1;
        background: $surface-lighten-1;
        border: solid $surface-lighten-2;
    }

    DetailView .commit-title {
        text-style: bold;
        color: $primary;
    }

    DetailView .commit-sha {
        color: $warning;
        text-style: bold;
    }

    DetailView .actor {
        color: $primary;
    }

    DetailView .error-title {
        text-style: bold;
        color: $error;
        margin-bottom: 1;
    }

    DetailView .error-log {
        color: $text;
    }

    DetailView .status-success {
        color: $success;
    }

    DetailView .status-failure {
        color: $error;
    }

    DetailView .status-running {
        color: $warning;
    }

    DetailView .status-loading {
        color: $text-muted;
    }

    DetailView .status-none {
        color: $text-disabled;
    }

    DetailView .action-hint {
        margin-top: 1;
        color: $text-muted;
        text-style: italic;
    }

    DetailView .link {
        color: $primary-lighten-2;
        text-style: underline;
    }

    DetailView .hidden {
        display: none;
    }

    DetailView .no-data {
        color: $text-muted;
        text-style: italic;
        padding: 2;
    }

    DetailView .comparison-label {
        text-style: bold;
        color: $primary;
        margin-top: 1;
    }

    DetailView .stat {
        height: 1;
    }

    DetailView .stat-good {
        color: $success;
    }

    DetailView .stat-warn {
        color: $warning;
    }

    DetailView .stat-neutral {
        color: $text-muted;
    }

    DetailView .commits-title {
        color: $text-muted;
        margin-top: 1;
    }

    DetailView .env-commit-row {
        height: 1;
    }

    DetailView .env-commit-label {
        width: 6;
        color: $text-muted;
    }

    DetailView .commit-msg-short {
        width: 1fr;
    }

    DetailView .commit-time {
        width: 15;
        color: $text-muted;
        text-align: right;
    }

    DetailView .section-title {
        text-style: bold;
        margin-top: 1;
    }

    DetailView .commit-row {
        height: 1;
    }

    DetailView .commit-sha-small {
        width: 8;
        color: $warning;
    }

    DetailView .commit-msg {
        width: 1fr;
    }

    DetailView .commit-author {
        width: 12;
        color: $text-muted;
    }

    DetailView #detail-loading {
        height: auto;
        padding: 2;
        align: center middle;
    }

    DetailView .loading-text {
        text-align: center;
        color: $text-muted;
        margin-bottom: 1;
    }

    DetailView LoadingIndicator {
        height: 3;
        width: 100%;
    }

    """

    class CloseRequested(Message):
        """Message sent when the detail view should close."""
        pass

    class OpenGitHub(Message):
        """Message sent when user wants to open GitHub."""
        def __init__(self, repo: str, run_id: int) -> None:
            self.repo = repo
            self.run_id = run_id
            super().__init__()

    def __init__(self, app: App, **kwargs) -> None:
        super().__init__(**kwargs)
        self.app_data = app
        self._health_task: Optional[asyncio.Task] = None

    async def on_mount(self) -> None:
        """Start health checks when mounted."""
        self._health_task = asyncio.create_task(self._run_health_checks())

    async def _run_health_checks(self) -> None:
        """Run health checks for both environments."""
        tasks = []
        if self.app_data.dev.url:
            tasks.append(fetch_health_check(self.app_data.dev))
        if self.app_data.prod.url:
            tasks.append(fetch_health_check(self.app_data.prod))

        if tasks:
            await asyncio.gather(*tasks)
            self._update_health_display()

    def compose(self) -> ComposeResult:
        """Compose the detail view."""
        with Vertical(classes="detail-content"):
            # Header
            with Horizontal(classes="detail-header"):
                yield Static(self.app_data.icon, classes="detail-icon")
                yield Static(self.app_data.name, classes="detail-title")
                yield Button("Close [Esc]", id="close-btn", classes="close-btn", variant="default")

            # Loading indicator
            loading_class = "" if self.app_data.loading else "hidden"
            content_class = "hidden" if self.app_data.loading else ""

            with Vertical(id="detail-loading", classes=loading_class):
                yield Static("Fetching status...", classes="loading-text")
                yield LoadingIndicator()

            # Content with tabs
            with TabbedContent(id="detail-tabs", classes=content_class):
                with TabPane("Build Status", id="tab-builds"):
                    with VerticalScroll():
                        # Release info if tracking
                        if self.app_data.latest_release:
                            yield from self._render_release_section(self.app_data.latest_release)

                        yield from self._render_environment_section(self.app_data.dev, "Development")
                        yield from self._render_environment_section(self.app_data.prod, "Production")
                        yield Static("Press 'o' GitHub, 'u' URL, 'Esc' close", classes="action-hint")

                with TabPane("Git", id="tab-branches"):
                    with VerticalScroll():
                        # Last commits per environment
                        yield Static("Último commit por ambiente:", classes="section-title")
                        if self.app_data.dev.last_commit:
                            yield from self._render_env_commit(self.app_data.dev)
                        if self.app_data.prod.last_commit:
                            yield from self._render_env_commit(self.app_data.prod)

                        # Branch comparisons
                        if self.app_data.comparisons:
                            yield Static("Comparación de branches:", classes="section-title")
                            yield from self._render_comparisons()
                        elif not self.app_data.dev.last_commit and not self.app_data.prod.last_commit:
                            yield Static("No git info available", classes="no-data")

    def _render_release_section(self, release: Release) -> ComposeResult:
        """Render the latest release section."""
        status_icon = get_status_icon(release.build_status)
        status_class = f"status-{release.build_status.value}"

        with Vertical(classes="release-section"):
            yield Static("📦 Latest Release", classes="section-title")

            with Horizontal(classes="info-row"):
                yield Static("Version:", classes="info-label")
                yield Static(release.tag, classes="info-value release-tag")

            with Horizontal(classes="info-row"):
                yield Static("Build:", classes="info-label")
                yield Static(f"{status_icon} {release.build_status.value.upper()}", classes=f"info-value {status_class}")

            if release.published:
                time_ago = humanize.naturaltime(release.published, when=datetime.now(timezone.utc))
                with Horizontal(classes="info-row"):
                    yield Static("Published:", classes="info-label")
                    yield Static(f"{time_ago} by @{release.author}", classes="info-value")

    def _render_environment_section(self, env: Environment, title: str) -> ComposeResult:
        """Render an environment section."""
        status_class = env.overall_status.value

        with Vertical(classes=f"env-section {status_class}"):
            yield Static(f"{title} ({env.name})", classes="section-title")

            # URL
            with Horizontal(classes="info-row"):
                yield Static("URL:", classes="info-label")
                if env.url:
                    url = f"https://{env.url}"
                    yield Static(url, classes="info-value link")
                    yield Button("📋", id=f"copy-url-{env.name}", classes="copy-btn", variant="default")
                else:
                    yield Static("Not deployed", classes="info-value")

            # Health check
            if env.url:
                with Horizontal(classes="info-row"):
                    yield Static("Health:", classes="info-label")
                    yield Static("⏳ Checking...", id=f"health-{env.name}", classes="info-value status-loading")

            # Repo/Branch
            if env.repo:
                with Horizontal(classes="info-row"):
                    yield Static("Repository:", classes="info-label")
                    repo_url = f"https://github.com/{env.repo}"
                    yield Static(repo_url, classes="info-value link")
                    yield Button("📋", id=f"copy-repo-{env.name}", classes="copy-btn", variant="default")

                with Horizontal(classes="info-row"):
                    yield Static("Branch:", classes="info-label")
                    yield Static(env.branch, classes="info-value")

            # Status
            if env.has_workflows:
                # Show workflow details
                with Vertical(classes="workflow-section"):
                    yield Static("Workflows:", classes="workflow-title")
                    for workflow in env.workflows:
                        yield from self._render_workflow_info(workflow, env.name)
            else:
                # Show environment status
                yield from self._render_status_info(env)

    def _render_status_info(self, env: Environment) -> ComposeResult:
        """Render status info for an environment."""
        status_icon = get_status_icon(env.status)
        status_class = f"status-{env.status.value}"

        with Horizontal(classes="info-row"):
            yield Static("Status:", classes="info-label")
            yield Static(f"{status_icon} {env.status.value.upper()}", classes=f"info-value {status_class}")

        if env.time:
            with Horizontal(classes="info-row"):
                yield Static("Last run:", classes="info-label")
                time_ago = humanize.naturaltime(env.time, when=datetime.now(timezone.utc))
                yield Static(time_ago, classes="info-value")

        if env.actor:
            with Horizontal(classes="info-row"):
                yield Static("Triggered by:", classes="info-label")
                yield Static(f"@{env.actor}", classes="info-value actor")

        if env.duration_seconds:
            with Horizontal(classes="info-row"):
                yield Static("Duration:", classes="info-label")
                duration = humanize.naturaldelta(env.duration_seconds)
                yield Static(duration, classes="info-value")

        # Error logs
        if env.status == Status.FAILURE and env.error_lines:
            yield from self._render_error_section(env.error_lines, env.name)

    def _render_workflow_info(self, workflow: Workflow, env_name: str = "") -> ComposeResult:
        """Render info for a workflow."""
        status_icon = get_status_icon(workflow.status)
        status_class = f"status-{workflow.status.value}"

        with Horizontal(classes="info-row"):
            yield Static(f"  {workflow.icon}", classes="info-label")
            yield Static(f"{workflow.display_name}: {status_icon} {workflow.status.value.upper()}", classes=f"info-value {status_class}")

        if workflow.time:
            time_ago = humanize.naturaltime(workflow.time, when=datetime.now(timezone.utc))
            actor_info = f" by @{workflow.actor}" if workflow.actor else ""
            with Horizontal(classes="info-row"):
                yield Static("", classes="info-label")
                yield Static(f"Last run: {time_ago}{actor_info}", classes="info-value")

        if workflow.status == Status.FAILURE and workflow.error_lines:
            yield from self._render_error_section(workflow.error_lines, f"{env_name}-{workflow.name}")

    def _render_commit_info(self, commit: Commit) -> ComposeResult:
        """Render commit info section."""
        with Vertical(classes="commit-section"):
            yield Static("Last Commit:", classes="commit-title")
            with Horizontal(classes="info-row"):
                yield Static("SHA:", classes="info-label")
                yield Static(commit.sha, classes="info-value commit-sha")
            with Horizontal(classes="info-row"):
                yield Static("Message:", classes="info-label")
                yield Static(commit.message, classes="info-value")
            with Horizontal(classes="info-row"):
                yield Static("Author:", classes="info-label")
                yield Static(commit.author, classes="info-value")
            if commit.date:
                time_ago = humanize.naturaltime(commit.date, when=datetime.now(timezone.utc))
                with Horizontal(classes="info-row"):
                    yield Static("Date:", classes="info-label")
                    yield Static(time_ago, classes="info-value")

    def _render_env_commit(self, env: Environment) -> ComposeResult:
        """Render compact commit info for an environment."""
        commit = env.last_commit
        if not commit:
            return

        time_ago = ""
        if commit.date:
            time_ago = humanize.naturaltime(commit.date, when=datetime.now(timezone.utc))

        with Horizontal(classes="env-commit-row"):
            yield Static(f"{env.name}:", classes="env-commit-label")
            yield Static(commit.sha, classes="commit-sha-small")
            yield Static(commit.message[:30], classes="commit-msg-short")
            yield Static(time_ago, classes="commit-time")

    def _render_comparisons(self) -> ComposeResult:
        """Render branch comparisons."""
        for i, (config, comparison) in enumerate(zip(self.app_data.compare_configs, self.app_data.comparisons)):
            yield Static(f"{config.head} → {config.base}:", classes="comparison-label")

            # Clear explanation of what needs to happen
            if comparison.ahead_by > 0:
                ahead_msg = f"  📤 {comparison.ahead_by} commits para mergear"
                yield Static(ahead_msg, classes="stat stat-warn")
            else:
                yield Static(f"  ✓ Al día", classes="stat stat-good")

            if comparison.behind_by > 0:
                behind_msg = f"  📥 {comparison.behind_by} commits atrás"
                yield Static(behind_msg, classes="stat stat-warn")

            # Recent commits to merge (if any)
            if comparison.commits:
                yield Static(f"  Pendientes:", classes="commits-title")
                for commit in comparison.commits[-5:]:
                    with Horizontal(classes="commit-row"):
                        yield Static(f"    {commit.sha}", classes="commit-sha-small")
                        yield Static(commit.message[:35], classes="commit-msg")

    def _render_error_section(self, error_lines: list[str], env_name: str = "") -> ComposeResult:
        """Render error log section."""
        with Horizontal(classes="error-header"):
            yield Static(f"Error Log ({len(error_lines)} lines):", classes="error-title")
            yield Button("📋 Copy All", id=f"copy-error-{env_name}", classes="copy-error-btn", variant="default")
        with Vertical(classes="error-section"):
            for line in error_lines:
                yield Static(line, classes="error-log")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press."""
        btn_id = event.button.id or ""

        if btn_id == "close-btn":
            self.post_message(self.CloseRequested())
        elif btn_id.startswith("copy-url-"):
            env_name = btn_id.replace("copy-url-", "")
            env = self.app_data.dev if env_name == "DEV" else self.app_data.prod
            if env.url:
                if copy_to_clipboard(f"https://{env.url}"):
                    self.notify("URL copied!")
                else:
                    self.notify("Failed to copy", severity="error")
        elif btn_id.startswith("copy-repo-"):
            env_name = btn_id.replace("copy-repo-", "")
            env = self.app_data.dev if env_name == "DEV" else self.app_data.prod
            if env.repo:
                if copy_to_clipboard(f"https://github.com/{env.repo}"):
                    self.notify("Repository URL copied!")
                else:
                    self.notify("Failed to copy", severity="error")
        elif btn_id.startswith("copy-error-"):
            error_id = btn_id.replace("copy-error-", "")
            error_lines = []
            # Check if it's a workflow error (format: ENV-workflow_name)
            if error_id.startswith("DEV-") or error_id.startswith("PROD-"):
                env_name = error_id.split("-")[0]
                workflow_name = error_id[len(env_name)+1:]
                env = self.app_data.dev if env_name == "DEV" else self.app_data.prod
                for wf in env.workflows:
                    if wf.name == workflow_name:
                        error_lines = wf.error_lines
                        break
            else:
                # Direct environment error
                env = self.app_data.dev if error_id == "DEV" else self.app_data.prod
                error_lines = env.error_lines

            if error_lines:
                if copy_to_clipboard("\n".join(error_lines)):
                    self.notify("Error log copied!")
                else:
                    self.notify("Failed to copy", severity="error")

    def _update_health_display(self) -> None:
        """Update the health status widgets."""
        for env in [self.app_data.dev, self.app_data.prod]:
            if not env.url:
                continue
            try:
                widget = self.query_one(f"#health-{env.name}", Static)
                if env.health_ok is None:
                    widget.update("⏳ Checking...")
                    widget.set_classes("info-value status-loading")
                elif env.health_ok:
                    latency = f"{env.health_latency_ms}ms" if env.health_latency_ms else ""
                    widget.update(f"✓ {env.health_code} OK {latency}")
                    widget.set_classes("info-value status-success")
                else:
                    error = env.health_error or f"HTTP {env.health_code}"
                    widget.update(f"✗ {error}")
                    widget.set_classes("info-value status-failure")
            except Exception:
                pass

    def update_app(self, app: App) -> None:
        """Update with new app data."""
        self.app_data = app
        self.refresh(recompose=True)
