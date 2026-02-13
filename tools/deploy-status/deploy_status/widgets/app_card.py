"""App card widget for the deploy status dashboard."""

from datetime import datetime, timezone

import humanize
from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Static, LoadingIndicator
from textual.reactive import reactive
from textual.message import Message

from ..models import App, Environment, Status, get_status_icon


class AppCard(Static):
    """A card displaying an app's deploy status."""

    DEFAULT_CSS = """
    AppCard {
        width: 100%;
        height: 5;
        min-width: 18;
        margin: 0;
        padding: 0 1;
        border: solid $surface-lighten-2;
        background: $surface;
    }

    AppCard:hover {
        border: solid $primary;
    }

    AppCard:focus {
        border: double $primary;
        background: $surface-lighten-1;
    }

    AppCard.success {
        border: solid $success;
    }

    AppCard.failure {
        border: solid $error;
    }

    AppCard.running {
        border: solid $warning;
    }

    AppCard .app-header {
        height: 1;
        width: 100%;
    }

    AppCard .app-name {
        width: 1fr;
        text-style: bold;
        overflow: hidden;
    }

    AppCard .app-icon {
        width: 3;
        min-width: 3;
    }

    AppCard .status-row {
        height: 1;
        width: 100%;
    }

    AppCard .env-label {
        width: 5;
        color: $text-muted;
    }

    AppCard .env-status {
        width: 2;
    }

    AppCard .env-time {
        width: 4;
        color: $text-muted;
        text-align: right;
    }

    AppCard .status-success {
        color: $success;
    }

    AppCard .status-failure {
        color: $error;
    }

    AppCard .status-running {
        color: $warning;
    }

    AppCard .status-loading {
        color: $text-muted;
    }

    AppCard .status-none {
        color: $text-disabled;
    }

    AppCard .card-loading {
        height: 1;
        width: 100%;
    }

    AppCard LoadingIndicator {
        height: 1;
        width: 100%;
        color: $primary;
    }

    AppCard .hidden {
        display: none;
    }
    """

    can_focus = True

    class Selected(Message):
        """Message sent when an app card is selected."""
        def __init__(self, app: App) -> None:
            self.app_data = app
            super().__init__()

    def __init__(self, app: App, **kwargs) -> None:
        super().__init__(**kwargs)
        self.app_data = app

    def _get_env_time(self, env: Environment) -> str:
        """Get short time string for environment."""
        # For environments with workflows, get the most recent time
        if env.has_workflows:
            times = [w.time for w in env.workflows if w.time]
            if times:
                latest = max(times)
                return self._format_short_time(latest)
        elif env.time:
            return self._format_short_time(env.time)
        return ""

    def _format_short_time(self, dt: datetime) -> str:
        """Format time as short string like '2h', '3d', '1w'."""
        now = datetime.now(timezone.utc)
        # Ensure dt has timezone info
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        delta = now - dt
        seconds = delta.total_seconds()
        if seconds < 60:
            return "now"
        elif seconds < 3600:
            return f"{int(seconds // 60)}m"
        elif seconds < 86400:
            return f"{int(seconds // 3600)}h"
        elif seconds < 604800:
            return f"{int(seconds // 86400)}d"
        else:
            return f"{int(seconds // 604800)}w"

    def compose(self) -> ComposeResult:
        """Compose the card layout."""
        # Header with icon and name
        with Horizontal(classes="app-header"):
            yield Static(self.app_data.icon, classes="app-icon")
            yield Static(self.app_data.name, classes="app-name")

        # Loading indicator (shown when loading)
        is_loading = self.app_data.loading
        loading_class = "" if is_loading else "hidden"
        status_class = "hidden" if is_loading else ""

        yield LoadingIndicator(id="card-loader", classes=loading_class)

        # Status rows with time (hidden when loading)
        dev_icon = get_status_icon(self.app_data.dev.overall_status)
        dev_status_class = f"status-{self.app_data.dev.overall_status.value}"
        dev_time = self._get_env_time(self.app_data.dev)

        prod_icon = get_status_icon(self.app_data.prod.overall_status)
        prod_status_class = f"status-{self.app_data.prod.overall_status.value}"
        prod_time = self._get_env_time(self.app_data.prod)

        with Horizontal(id="dev-row", classes=f"status-row {status_class}"):
            yield Static("DEV", classes="env-label")
            yield Static(dev_icon, id="dev-status", classes=f"env-status {dev_status_class}")
            yield Static(dev_time, id="dev-time", classes="env-time")

        with Horizontal(id="prod-row", classes=f"status-row {status_class}"):
            yield Static("PROD", classes="env-label")
            yield Static(prod_icon, id="prod-status", classes=f"env-status {prod_status_class}")
            yield Static(prod_time, id="prod-time", classes="env-time")

    def update_app(self, app: App) -> None:
        """Update the card with new app data."""
        self.app_data = app
        self._update_status_class()

        # Update individual elements instead of full recompose
        try:
            # Toggle loading indicator visibility
            loader = self.query_one("#card-loader", LoadingIndicator)
            dev_row = self.query_one("#dev-row")
            prod_row = self.query_one("#prod-row")

            if self.app_data.loading:
                loader.remove_class("hidden")
                dev_row.add_class("hidden")
                prod_row.add_class("hidden")
            else:
                loader.add_class("hidden")
                dev_row.remove_class("hidden")
                prod_row.remove_class("hidden")

            dev_icon = get_status_icon(self.app_data.dev.overall_status)
            prod_icon = get_status_icon(self.app_data.prod.overall_status)
            dev_time = self._get_env_time(self.app_data.dev)
            prod_time = self._get_env_time(self.app_data.prod)

            dev_status = self.query_one("#dev-status", Static)
            prod_status = self.query_one("#prod-status", Static)

            # Update status icons
            dev_status.update(dev_icon)
            prod_status.update(prod_icon)

            # Update status classes
            for cls in list(dev_status.classes):
                if cls.startswith("status-"):
                    dev_status.remove_class(cls)
            dev_status.add_class(f"status-{self.app_data.dev.overall_status.value}")

            for cls in list(prod_status.classes):
                if cls.startswith("status-"):
                    prod_status.remove_class(cls)
            prod_status.add_class(f"status-{self.app_data.prod.overall_status.value}")

            # Update times
            self.query_one("#dev-time", Static).update(dev_time)
            self.query_one("#prod-time", Static).update(prod_time)
        except Exception:
            # Fallback to recompose if elements not found
            self.refresh(recompose=True)

    def _update_status_class(self) -> None:
        """Update the card's status class based on app status."""
        # Remove old status classes
        self.remove_class("success", "failure", "running", "loading")

        # Add new status class
        status = self.app_data.overall_status
        if status == Status.SUCCESS:
            self.add_class("success")
        elif status == Status.FAILURE:
            self.add_class("failure")
        elif status == Status.RUNNING:
            self.add_class("running")

    def on_mount(self) -> None:
        """Handle mount event."""
        self._update_status_class()

    def on_click(self) -> None:
        """Handle click event."""
        self.post_message(self.Selected(self.app_data))

    def action_select(self) -> None:
        """Handle enter key."""
        self.post_message(self.Selected(self.app_data))
