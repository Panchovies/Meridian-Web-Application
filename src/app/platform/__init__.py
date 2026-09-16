# Copyright (c) 2026 Meridian Capital Markets
"""Platform API route registration."""
from flask import Blueprint

from . import alerts as alerts

platform_bp = Blueprint("platform", __name__)
