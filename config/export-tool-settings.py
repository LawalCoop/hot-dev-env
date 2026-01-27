# Hot-dev-env specific settings for OSM Export Tool
# This file overrides core/settings/project.py for Docker environment

import os
import dramatiq
from dramatiq.brokers.redis import RedisBroker

# Import base settings
from core.settings.project import *

# Override Redis broker to use Docker container
REDIS_HOST = os.getenv("REDIS_HOST", "export-tool-redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

dramatiq.set_broker(RedisBroker(host=REDIS_HOST, port=REDIS_PORT))

# Development settings
DEBUG = True
ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "export-tool.hotosm.test,localhost,127.0.0.1,export-tool-app").split(",")
HOSTNAME = os.getenv("HOSTNAME", "export-tool.hotosm.test")

# Ensure proper CSRF settings for HTTPS behind proxy
CSRF_TRUSTED_ORIGINS = [
    "https://export-tool.hotosm.test",
    "https://login.hotosm.test",
]
