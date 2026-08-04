# Copyright (c) 2026 Francisco Zenklusen. All rights reserved.
"""Main application file for the Flask web service.

This file defines a simple health check endpoint that returns:
    the current UTCtimestamp
    a status message
    a status code of 200, indicating the service is healthy
"""
import os
from datetime import datetime, timezone

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route("/news")
def get_news() -> tuple:
    """Fetch news articles based on query parameters.

    Query Parameters:
        q: The search query, either a company or ticker symbol.
    Uses api call from https://newsapi.org/
    """
    query = request.args.get("q", "").strip()
    if not query:
        return jsonify({"Error": "Missing required query parameter 'q'"}), 400

    api_request_url = f"https://newsapi.org/v2/top-headlines?apiKey=a0b43419dc1c49a8978b805be0c52953&q={query}&country=us&pageSize=5"
    try:
        response = requests.get(api_request_url, timeout=5)
        response.raise_for_status()

    except requests.RequestException as e:
        return jsonify({"Error": f"Failed to fetch news articles: {e!s}"}), 500

    return jsonify(response.json()), 200

@app.route("/health")
def health() -> tuple:
    """Health check endpoint.

    Returns a JSON response with
        the current UTC timestamp
        a status message
        and a status code of 200
    """
    date = datetime.now(timezone.utc).isoformat()
    return jsonify({
        "status": "ok",
        "timestamp": date,
        "message": "Service is healthy and running.",
    }), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=os.environ.get("ENV") == "dev")  # noqa: S104
