# Health Check Service

A minimal Flask web application that exposes a single `/health` endpoint,
used to verify the service is running and responsive.

## What it does

The `/health` endpoint responds to GET requests with a JSON object containing:

- `status` — indicates whether the service is healthy (`"ok"` under normal conditions)
- `timestamp` — the current UTC time the request was handled, in ISO 8601 format
- `message` — a short human-readable description of the service state

Example response:

```json
{
  "status": "ok",
  "timestamp": "2026-08-03T14:32:10.123456+00:00",
  "message": "Service is healthy"
}
```

## Requirements

- Python 3.14 (or any Python 3.x)
- pip

## Setup

Clone the repository, then create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install dependencies:

```bash
uv pip install -r requirements.txt
```

## Running locally

Start the application:

```bash
python app.py
```

The server will start at `http://127.0.0.1:5000`. You can check the endpoint with:

```bash
curl http://127.0.0.1:5000/health
```

or by visiting that URL in a browser.

## Running tests

With the virtual environment active:

```bash
pytest -v
```

This runs the test suite, which checks that `/health` returns a 200 status
code and that the response body contains the expected fields.