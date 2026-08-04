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
- Docker Desktop

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

The server will start at `http://localhost:5000`. You can check the endpoint with:

```bash
curl http://localhost:5000/health
```

or by visiting that URL in a browser.

## Running on Docker

With Docker Desktop running in the background:

Build the image:

```bash
docker build -t meridian-application .
```

Run the container:

```bash
docker run -p 5000:5000 meridian-application
```

For debug mode, add this flag:

```bash
-e ENV=dev
```

### Troubleshooting:

It is possible that if you are on a Mac, port 5000 will be in use. In that case, try using port 8080 or any other free port.

## Running tests

With the virtual environment active:

```bash
pytest -v
```

This runs the test suite, which checks that `/health` returns a 200 status
code and that the response body contains the expected fields.