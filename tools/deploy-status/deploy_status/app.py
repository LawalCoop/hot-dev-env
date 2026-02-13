"""Main Textual application for deploy status dashboard."""

import asyncio
from typing import Optional

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.widgets import Static, Footer, Header
from textual.css.query import NoMatches

from .models import App as AppModel, get_apps, Status
import webbrowser
from .github import fetch_app_status, open_github_run
from .widgets import AppCard, DetailView


class DeployStatusApp(App):
    """HOTOSM Deploy Status Dashboard."""

    TITLE = "HOTOSM Deploy Status"
    CSS_PATH = "styles.tcss"

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "close_detail", "Close", show=False),
        Binding("o", "open_github", "GitHub"),
        Binding("u", "open_url", "Open URL"),
        Binding("enter", "select_card", "Details", show=False),
        Binding("j", "focus_next", "Next", show=False),
        Binding("k", "focus_previous", "Previous", show=False),
    ]

    def __init__(self):
        super().__init__()
        self.apps: list[AppModel] = []
        self.selected_app: Optional[AppModel] = None
        self._refresh_task: Optional[asyncio.Task] = None

    def compose(self) -> ComposeResult:
        """Compose the app layout."""
        yield Header()

        with Container(id="main-container"):
            with Horizontal(id="content"):
                with Vertical(id="apps-panel"):
                    with ScrollableContainer(id="apps-scroll"):
                        with Container(id="apps-grid"):
                            # Cards will be added dynamically
                            pass

                with Vertical(id="detail-panel"):
                    # Detail view will be added when an app is selected
                    pass

        yield Footer()

    async def on_mount(self) -> None:
        """Handle app mount - start loading data."""
        self.apps = get_apps()
        await self._create_cards()
        self._update_grid_columns()
        self._refresh_task = asyncio.create_task(self._load_all_status())

    def on_resize(self) -> None:
        """Handle terminal resize."""
        self._update_grid_columns()

    def _update_grid_columns(self) -> None:
        """Update grid columns based on terminal width."""
        try:
            grid = self.query_one("#apps-grid")
            apps_panel = self.query_one("#apps-panel")

            # Get available width (accounting for padding/borders)
            available_width = self.size.width - 4

            # If detail panel is open, use less width
            if "with-detail" in apps_panel.classes:
                available_width = int(available_width * 0.35)

            # Each card needs ~22 chars minimum (including borders/gaps)
            card_width = 24
            columns = max(1, available_width // card_width)

            # Cap at reasonable max
            columns = min(columns, 6)

            grid.styles.grid_size_columns = columns
        except Exception:
            pass

    async def _create_cards(self) -> None:
        """Create app cards."""
        grid = self.query_one("#apps-grid")
        for app in self.apps:
            card = AppCard(app, id=f"card-{app.name.lower().replace(' ', '-')}")
            await grid.mount(card)

    async def _load_all_status(self) -> None:
        """Load status for all apps progressively."""
        tasks = []
        for app in self.apps:
            task = asyncio.create_task(self._load_app_status(app))
            tasks.append(task)
            # Small delay between starting fetches to avoid rate limiting
            await asyncio.sleep(0.2)

        await asyncio.gather(*tasks, return_exceptions=True)

    async def _load_app_status(self, app: AppModel) -> None:
        """Load status for a single app and update its card."""
        try:
            await fetch_app_status(app)
        except Exception:
            app.loading = False

        # Update the card
        card_id = f"card-{app.name.lower().replace(' ', '-')}"
        try:
            card = self.query_one(f"#{card_id}", AppCard)
            card.update_app(app)

            # If this app is selected, update detail view too
            if self.selected_app and self.selected_app.name == app.name:
                self.selected_app = app
                self._update_detail_view()
        except NoMatches:
            pass

    def _update_detail_view(self) -> None:
        """Update the detail view with current selected app."""
        if not self.selected_app:
            return

        detail_panel = self.query_one("#detail-panel")

        # Remove old detail view if exists
        for child in detail_panel.children:
            child.remove()

        # Add new detail view
        detail_view = DetailView(self.selected_app)
        detail_panel.mount(detail_view)

    def on_app_card_selected(self, message: AppCard.Selected) -> None:
        """Handle app card selection."""
        self.selected_app = message.app_data
        self._show_detail_panel()
        self._update_detail_view()

    def _show_detail_panel(self) -> None:
        """Show the detail panel."""
        detail_panel = self.query_one("#detail-panel")
        detail_panel.add_class("visible")
        apps_panel = self.query_one("#apps-panel")
        apps_panel.add_class("with-detail")
        self._update_grid_columns()

    def _hide_detail_panel(self) -> None:
        """Hide the detail panel."""
        detail_panel = self.query_one("#detail-panel")
        detail_panel.remove_class("visible")
        apps_panel = self.query_one("#apps-panel")
        apps_panel.remove_class("with-detail")
        self.selected_app = None

        # Remove detail view content
        for child in detail_panel.children:
            child.remove()

        self._update_grid_columns()

    def on_detail_view_close_requested(self, message: DetailView.CloseRequested) -> None:
        """Handle detail view close request."""
        self._hide_detail_panel()

    def action_close_detail(self) -> None:
        """Close the detail panel."""
        if self.selected_app:
            self._hide_detail_panel()

    def action_refresh(self) -> None:
        """Refresh all app statuses."""
        # Reset all apps to loading state
        for app in self.apps:
            app.loading = True
            app.dev.status = Status.LOADING
            app.prod.status = Status.LOADING
            for workflow in app.dev.workflows:
                workflow.status = Status.LOADING
            for workflow in app.prod.workflows:
                workflow.status = Status.LOADING

        # Update cards to show loading state
        for app in self.apps:
            card_id = f"card-{app.name.lower().replace(' ', '-')}"
            try:
                card = self.query_one(f"#{card_id}", AppCard)
                card.update_app(app)
            except NoMatches:
                pass

        # Update detail view to show loading if open
        if self.selected_app:
            # Find the updated app object
            for app in self.apps:
                if app.name == self.selected_app.name:
                    self.selected_app = app
                    break
            self._update_detail_view()

        # Cancel existing refresh if running
        if self._refresh_task and not self._refresh_task.done():
            self._refresh_task.cancel()

        # Start new refresh
        self._refresh_task = asyncio.create_task(self._load_all_status())

    def action_open_github(self) -> None:
        """Open the selected app's GitHub Actions in browser."""
        if not self.selected_app:
            return

        # Find a run_id to open
        for env in [self.selected_app.prod, self.selected_app.dev]:
            if env.has_workflows:
                for workflow in env.workflows:
                    if workflow.run_id and workflow.repo:
                        open_github_run(workflow.repo, workflow.run_id)
                        return
            elif env.run_id and env.repo:
                open_github_run(env.repo, env.run_id)
                return

    def action_open_url(self) -> None:
        """Open the selected app's URL in browser."""
        if not self.selected_app:
            return

        # Try prod URL first, then dev
        for env in [self.selected_app.prod, self.selected_app.dev]:
            if env.url:
                webbrowser.open(f"https://{env.url}")
                return

    def action_select_card(self) -> None:
        """Select the currently focused card."""
        focused = self.focused
        if isinstance(focused, AppCard):
            focused.post_message(AppCard.Selected(focused.app_data))


def main():
    """Run the deploy status dashboard."""
    app = DeployStatusApp()
    app.run()


if __name__ == "__main__":
    main()
