# Copyright (c) 2026 Meridian Capital Markets
"""Main application file for the Flask web service.

This file defines a simple health check endpoint that returns:
    the current UTCtimestamp
    a status message
    a status code of 200, indicating the service is healthy
    as well as checking for an API key
"""
import os
from datetime import UTC, datetime

import requests
from flask import Flask, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics

from .constants import (
    DEFAULT_PORT,
    HTTP_STATUS_API_ERROR,
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)
from .platform import platform_bp

app = Flask(__name__)

# Adds metrics endpoint to the application for Prometheus monitoring
metrics = PrometheusMetrics(app)

# Register the platform blueprint
app.register_blueprint(platform_bp)

@app.route("/news")
def get_news() -> tuple:
    """Fetch news articles based on query parameters.

    Query Parameters:
        q: The search query, either a company or ticker symbol.
    Uses API call from https://newsapi.org/
    """
    query = request.args.get("q", "").strip()
    if not query:
        return (jsonify({"Error": "Missing required query parameter 'q'"}),
                HTTP_STATUS_OK)

    api_key = os.environ.get("NEWS_API_KEY")
    if not api_key:
        return (jsonify({"Error":
                         "Missing NEWS_API_KEY in environment variables"}),
                         HTTP_STATUS_INTERNAL_SERVER_ERROR)

    api_request_url = f"https://newsapi.org/v2/top-headlines?apiKey={api_key}&q={query}&country=us&pageSize=5"
    try:
        api_response = requests.get(api_request_url, timeout=5)
        api_response.raise_for_status()
        response = api_response.json()
        if response.get("status") != "ok":
            return (jsonify({"Error": "Failed to fetch news articles"}),
                    HTTP_STATUS_INTERNAL_SERVER_ERROR)
        if response.get("totalResults", 0) == 0:
            return (jsonify({"Error":
                             f"No news articles found for query: {query}"}),
                             HTTP_STATUS_API_ERROR)

    except requests.RequestException:
        return (jsonify({"Error": "Failed to fetch news articles"}),
                HTTP_STATUS_INTERNAL_SERVER_ERROR)

    return (jsonify(response.get("articles", [])), HTTP_STATUS_OK)

@app.route("/health")
def health() -> tuple:
    """Health check endpoint.

    Returns a JSON response with
        the current UTC timestamp
        a status message
        and a status code of 200
    """
    date = datetime.now(UTC).isoformat()
    api_key = os.environ.get("NEWS_API_KEY")
    if not api_key:
        return jsonify({
                "status": "error",
                "timestamp": date,
                "message": "Service is missing api key for NewsAPI",
            }), HTTP_STATUS_INTERNAL_SERVER_ERROR
    return jsonify({
        "status": "ok",
        "timestamp": date,
        "message": "Service is healthy and running!",
    }), HTTP_STATUS_OK

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=DEFAULT_PORT, # noqa: S104
            debug=os.environ.get("ENV") == "dev")
