"""Detail view widget for showing app deployment details."""

from datetime import datetime, timezone
from typing import Optional

from textual.app import ComposeResult
from textual.containers import Vertical, Horizontal, ScrollableContainer
from textual.widgets import Static, Button, LoadingIndicator, TabbedContent, TabPane
from textual.message import Message

import humanize

from ..models import App, BranchComparison, Commit, Environment, Status, Workflow, get_status_icon


class DetailView(Static):
    """A detailed view of an app's deployment status."""

    DEFAULT_CSS = """
    DetailView {
        width: 100%;
        height: 100%;
        padding: 1 2;
        background: $surface;
    }

    DetailView .detail-content {
        height: 100%;
    }

    DetailView #detail-tabs {
        height: auto;
        max-height: 100%;
    }

    DetailView ScrollableContainer {
        height: auto;
        max-height: 100%;
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
        margin-top: 1;
        padding: 1;
        background: $error 10%;
        border: solid $error 50%;
        max-height: 15;
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
                    with ScrollableContainer():
                        yield from self._render_environment_section(self.app_data.dev, "Development")
                        yield from self._render_environment_section(self.app_data.prod, "Production")
                        yield Static("Press 'o' GitHub, 'u' URL, 'Esc' close", classes="action-hint")

                with TabPane("Git", id="tab-branches"):
                    with ScrollableContainer():
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

    def _render_environment_section(self, env: Environment, title: str) -> ComposeResult:
        """Render an environment section."""
        status_class = env.overall_status.value

        with Vertical(classes=f"env-section {status_class}"):
            yield Static(f"{title} ({env.name})", classes="section-title")

            # URL
            with Horizontal(classes="info-row"):
                yield Static("URL:", classes="info-label")
                if env.url:
                    yield Static(f"https://{env.url}", classes="info-value link")
                else:
                    yield Static("Not deployed", classes="info-value")

            # Repo/Branch
            if env.repo:
                with Horizontal(classes="info-row"):
                    yield Static("Repository:", classes="info-label")
                    yield Static(f"https://github.com/{env.repo}", classes="info-value link")

                with Horizontal(classes="info-row"):
                    yield Static("Branch:", classes="info-label")
                    yield Static(env.branch, classes="info-value")

            # Status
            if env.has_workflows:
                # Show workflow details
                with Vertical(classes="workflow-section"):
                    yield Static("Workflows:", classes="workflow-title")
                    for workflow in env.workflows:
                        yield from self._render_workflow_info(workflow)
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

        if env.duration_seconds:
            with Horizontal(classes="info-row"):
                yield Static("Duration:", classes="info-label")
                duration = humanize.naturaldelta(env.duration_seconds)
                yield Static(duration, classes="info-value")

        # Error logs
        if env.status == Status.FAILURE and env.error_lines:
            yield from self._render_error_section(env.error_lines)

    def _render_workflow_info(self, workflow: Workflow) -> ComposeResult:
        """Render info for a workflow."""
        status_icon = get_status_icon(workflow.status)
        status_class = f"status-{workflow.status.value}"

        with Horizontal(classes="info-row"):
            yield Static(f"  {workflow.icon}", classes="info-label")
            yield Static(f"{workflow.display_name}: {status_icon} {workflow.status.value.upper()}", classes=f"info-value {status_class}")

        if workflow.time:
            time_ago = humanize.naturaltime(workflow.time, when=datetime.now(timezone.utc))
            with Horizontal(classes="info-row"):
                yield Static("", classes="info-label")
                yield Static(f"Last run: {time_ago}", classes="info-value")

        if workflow.status == Status.FAILURE and workflow.error_lines:
            yield from self._render_error_section(workflow.error_lines)

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

    def _render_error_section(self, error_lines: list[str]) -> ComposeResult:
        """Render error log section."""
        with Vertical(classes="error-section"):
            yield Static("Error Log:", classes="error-title")
            # Show last 10 lines
            for line in error_lines[-10:]:
                yield Static(line[:100], classes="error-log")  # Truncate long lines

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press."""
        if event.button.id == "close-btn":
            self.post_message(self.CloseRequested())

    def update_app(self, app: App) -> None:
        """Update with new app data."""
        self.app_data = app
        self.refresh(recompose=True)
