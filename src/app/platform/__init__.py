# Copyright (c) 2026 Meridian Capital Markets
"""Platform API route registration."""
from flask import Blueprint

platform_bp = Blueprint("platform", __name__)

# Blueprint must occur before the import, therefore E402 is ignored
from . import alerts as alerts  # noqa: E402
