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

It is possible that if you are on a Mac, port 5000 will be in use. This will result in an "address is already in use" error when running the container. In that case, try using port 8080 or any other free port. Just switch the port number on the left-side of the colon to any number in the range of (1024-65535).

```bash
docker run -p <Any Free Port>:5000 meridian-application
```

The application can be accessed at `http://localhost:5000`, however if you choose to change the port, you must change the port number in the URL as well.

## Running tests

With the virtual environment active:

```bash
pytest -v
```

This runs the test suite, which checks that `/health` returns a 200 status
code and that the response body contains the expected fields.

## Running in Python vs Docker

The main difference in running an application in Python directly vs using a container is the consistency and scalability. When runnning in Python directly, a changes in between machines and enviornments can change the way an application runs and interacts with the system. When using a container, the enviornment, dependencies, and versions of software all remain the same, alowing for simpler testing and significantly less setup. Containers also allow for scalability as multiple instances of containers can be run simultaniously allowing for stress testing and parralel work. This is perfect for Meridian, who has multiple people testing and deploying, so making sure enviornments stay consistent saves time and resources.
