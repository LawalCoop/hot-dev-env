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
    url: str = ""  # Deployment URL for this workflow
    status: Status = Status.LOADING
    run_id: Optional[int] = None
    job_id: Optional[int] = None  # Failed job ID for direct link
    time: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    error_lines: list[str] = field(default_factory=list)
    repo: str = ""
    branch: str = ""
    actor: Optional[str] = None  # User who triggered the build
    # Health check fields
    health_ok: Optional[bool] = None
    health_code: Optional[int] = None
    health_latency_ms: Optional[int] = None
    health_error: Optional[str] = None

    def __post_init__(self):
        if not self.display_name:
            self.display_name = self.name


@dataclass
class Commit:
    """A git commit."""
    sha: str
    message: str
    author: str
    date: Optional[datetime] = None


@dataclass
class BranchComparison:
    """Comparison between two branches."""
    base: str
    head: str
    ahead_by: int = 0
    behind_by: int = 0
    commits: list[Commit] = field(default_factory=list)


@dataclass
class Environment:
    """A deployment environment (dev/prod)."""
    name: str
    url: str
    repo: str = ""
    branch: str = ""
    status: Status = Status.LOADING
    run_id: Optional[int] = None
    job_id: Optional[int] = None  # Failed job ID for direct link
    time: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    error_lines: list[str] = field(default_factory=list)
    workflows: list[Workflow] = field(default_factory=list)
    last_commit: Optional[Commit] = None
    actor: Optional[str] = None  # User who triggered the build
    # Health check fields
    health_ok: Optional[bool] = None
    health_code: Optional[int] = None
    health_latency_ms: Optional[int] = None
    health_error: Optional[str] = None

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
class BranchCompareConfig:
    """Configuration for branch comparison."""
    base: str
    head: str
    label: str  # Display label like "develop → main"


@dataclass
class Release:
    """A GitHub release."""
    tag: str
    name: str
    author: str
    published: Optional[datetime] = None
    build_status: Status = Status.LOADING
    build_run_id: Optional[int] = None


@dataclass
class App:
    """An application in the dashboard."""
    name: str
    icon: str
    dev: Environment
    prod: Environment
    loading: bool = True
    compare_configs: list[BranchCompareConfig] = field(default_factory=list)
    comparisons: list[BranchComparison] = field(default_factory=list)
    latest_release: Optional[Release] = None
    track_releases: bool = False  # Whether to fetch release info

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
            compare_configs=[
                BranchCompareConfig(base="main", head="develop", label="develop → main"),
            ],
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
            compare_configs=[
                BranchCompareConfig(base="main", head="develop", label="develop → main"),
            ],
            track_releases=True,
        ),
        App(
            name="Drone-TM",
            icon="🚁",
            dev=Environment(
                name="DEV",
                url="dronetm.testlogin.hotosm.org",
                repo="hotosm/drone-tm",
                branch="login-hanko",
            ),
            prod=Environment(
                name="PROD",
                url="dronetm.hotosm.org",
                repo="hotosm/drone-tm",
                branch="main",
            ),
            compare_configs=[
                BranchCompareConfig(base="dev", head="login-hanko", label="login-hanko → dev"),
            ],
        ),
        App(
            name="fAIr",
            icon="🤖",
            dev=Environment(
                name="DEV",
                url="fair.testlogin.hotosm.org",
                repo="hotosm/fAIr",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="fair.hotosm.org",
                repo="hotosm/fAIr",
                branch="main",
            ),
            compare_configs=[
                BranchCompareConfig(base="develop", head="login_hanko", label="login_hanko → develop"),
            ],
        ),
        App(
            name="uMap",
            icon="📍",
            dev=Environment(
                name="DEV",
                url="umap-dev.hotosm.org",
                repo="hotosm/umap",
                branch="develop",
                workflows=[
                    Workflow(name="Deploy login-hanko to umap.testlogin.hotosm.org", display_name="testlogin", icon="🔐", url="umap.testlogin.hotosm.org", repo="hotosm/umap", branch="login_hanko"),
                    Workflow(name="Build & deploy develop to umap-dev.hotosm.org", display_name="umap-dev", icon="🌐", url="umap-dev.hotosm.org", repo="hotosm/umap", branch="develop"),
                ],
            ),
            prod=Environment(
                name="PROD",
                url="umap.hotosm.org",
                repo="hotosm/umap",
                branch="master",
            ),
            compare_configs=[
                BranchCompareConfig(base="master", head="develop", label="develop → master"),
            ],
        ),
        App(
            name="Export Tool",
            icon="📦",
            dev=Environment(
                name="DEV",
                url="export.testlogin.hotosm.org",
                repo="hotosm/osm-export-tool",
                branch="login_hanko",
            ),
            prod=Environment(
                name="PROD",
                url="",
                status=Status.NONE,
            ),
            compare_configs=[
                BranchCompareConfig(base="master", head="login_hanko", label="login_hanko → master"),
            ],
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
            # No comparison for TM since we don't have a feature branch
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
            compare_configs=[
                BranchCompareConfig(base="main", head="login_hanko", label="login_hanko → main"),
            ],
        ),
    ]
