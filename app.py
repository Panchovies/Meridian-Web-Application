# Copyright (c) 2026 Francisco Zenklusen. All rights reserved.
"""Main application file for the Flask web service.

This file defines a simple health check endpoint that returns:
    the current UTCtimestamp
    a status message
    a status code of 200, indicating the service is healthy
"""
import os
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

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
