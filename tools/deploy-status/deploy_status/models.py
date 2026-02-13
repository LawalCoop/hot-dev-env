"""Data models for deploy status."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class Status(Enum):
    NONE = "none"
    SUCCESS = "success"
    FAILURE = "failure"
    RUNNING = "running"
    LOADING = "loading"


@dataclass
class Workflow:
    """A GitHub Actions workflow (for apps with multiple workflows like login)."""
    name: str  # GitHub workflow name (for API)
    display_name: str = ""  # Short name for UI
    icon: str = "⚙️"
    status: Status = Status.LOADING
    run_id: Optional[int] = None
    time: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    error_lines: list[str] = field(default_factory=list)
    repo: str = ""
    branch: str = ""

    def __post_init__(self):
        if not self.display_name:
            self.display_name = self.name


@dataclass
class Environment:
    """A deployment environment (dev/prod)."""
    name: str
    url: str
    repo: str = ""
    branch: str = ""
    status: Status = Status.LOADING
    run_id: Optional[int] = None
    time: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    error_lines: list[str] = field(default_factory=list)
    workflows: list[Workflow] = field(default_factory=list)

    @property
    def has_workflows(self) -> bool:
        return len(self.workflows) > 0

    @property
    def overall_status(self) -> Status:
        """Get overall status considering workflows."""
        if not self.has_workflows:
            return self.status

        statuses = [w.status for w in self.workflows]
        if Status.FAILURE in statuses:
            return Status.FAILURE
        if Status.RUNNING in statuses:
            return Status.RUNNING
        if Status.LOADING in statuses:
            return Status.LOADING
        if all(s == Status.SUCCESS for s in statuses):
            return Status.SUCCESS
        return Status.NONE


@dataclass
class App:
    """An application in the dashboard."""
    name: str
    icon: str
    dev: Environment
    prod: Environment
    loading: bool = True

    @property
    def overall_status(self) -> Status:
        """Get overall status of the app."""
        dev_status = self.dev.overall_status
        prod_status = self.prod.overall_status

        if dev_status == Status.FAILURE or prod_status == Status.FAILURE:
            return Status.FAILURE
        if dev_status == Status.RUNNING or prod_status == Status.RUNNING:
            return Status.RUNNING
        if dev_status == Status.LOADING or prod_status == Status.LOADING:
            return Status.LOADING
        if dev_status == Status.SUCCESS or prod_status == Status.SUCCESS:
            return Status.SUCCESS
        return Status.NONE

    @property
    def status_icon(self) -> str:
        """Get status icon for the app."""
        status = self.overall_status
        return {
            Status.SUCCESS: "✅",
            Status.FAILURE: "❌",
            Status.RUNNING: "🔄",
            Status.LOADING: "⏳",
            Status.NONE: "⚪",
        }.get(status, "⚪")


def get_status_icon(status: Status) -> str:
    """Get icon for a status."""
    return {
        Status.SUCCESS: "✓",
        Status.FAILURE: "✗",
        Status.RUNNING: "◐",
        Status.LOADING: "⋯",
        Status.NONE: "○",
    }.get(status, "○")


def get_apps() -> list[App]:
    """Get the list of apps to monitor."""
    return [
        App(
            name="Portal",
            icon="🌐",
            dev=Environment(
                name="DEV",
                url="dev.portal.hotosm.org",
                repo="hotosm/portal",
                branch="develop",
            ),
            prod=Environment(
                name="PROD",
                url="portal.hotosm.org",
                repo="hotosm/portal",
                branch="main",
            ),
        ),
        App(
            name="Login",
            icon="🔐",
            dev=Environment(
                name="DEV",
                url="dev.login.hotosm.org",
                repo="hotosm/login",
                branch="develop",
            ),
            prod=Environment(
                name="PROD",
                url="login.hotosm.org",
                repo="hotosm/login",
                branch="main",
                workflows=[
                    Workflow(name="Build Production Images", display_name="Image", icon="🐳", repo="hotosm/login", branch="main"),
                    Workflow(name="Release Helm Chart", display_name="Helm", icon="⎈", repo="hotosm/login", branch="main"),
                ],
            ),
        ),
        App(
            name="Drone-TM",
            icon="🚁",
            dev=Environment(
                name="DEV",
                url="testlogin.dronetm.hotosm.org",
                repo="hotosm/drone-tm",
                branch="develop",
            ),
            prod=Environment(
                name="PROD",
                url="dronetm.hotosm.org",
                repo="hotosm/drone-tm",
                branch="main",
            ),
        ),
        App(
            name="fAIr",
            icon="🤖",
            dev=Environment(
                name="DEV",
                url="testlogin.fair.hotosm.org",
                repo="hotosm/fAIr",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="fair.hotosm.org",
                repo="hotosm/fAIr",
                branch="main",
            ),
        ),
        App(
            name="uMap",
            icon="📍",
            dev=Environment(
                name="DEV",
                url="testlogin.umap.hotosm.org",
                repo="hotosm/umap",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="",
                status=Status.NONE,
            ),
        ),
        App(
            name="Export Tool",
            icon="📦",
            dev=Environment(
                name="DEV",
                url="testlogin.export.hotosm.org",
                repo="hotosm/osm-export-tool",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="",
                status=Status.NONE,
            ),
        ),
        App(
            name="Tasking Manager",
            icon="📋",
            dev=Environment(
                name="DEV",
                url="",
                status=Status.NONE,
            ),
            prod=Environment(
                name="PROD",
                url="tasks.hotosm.org",
                repo="hotosm/tasking-manager",
                branch="main",
            ),
        ),
        App(
            name="Raw Data API",
            icon="💾",
            dev=Environment(
                name="DEV",
                url="dev.raw-data.hotosm.org",
                repo="hotosm/raw-data-api",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="api-prod.raw-data.hotosm.org",
                repo="hotosm/raw-data-api",
                branch="main",
            ),
        ),
    ]
