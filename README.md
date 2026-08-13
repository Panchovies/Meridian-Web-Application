# Meridian Capital Markets Python Web Application

## Endpoints

### `/health`

The `/health` endpoint responds to GET requests with a JSON object containing:

- `status` — indicates whether the service is healthy (`"ok"` under normal
  conditions)
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

### `/news`

The `/news` endpoint responds to GET requests with news articles matching a
given company or ticker symbol, sourced from [NewsAPI](https://newsapi.org/).
Needs an API key to function. A free API key can be obtained from
[NewsAPI](https://newsapi.org/).

**Query Parameters:**

- `q` (required) — the search query, either a company name or ticker symbol

**Responses:**

- `200` — returns a JSON array of up to 5 matching articles
- `400` — missing required query parameter `q`
- `404` — no articles found for the given query
- `500` — the upstream news API request failed or returned an unexpected status

Example request:

```bash
curl "http://localhost:5000/news?q=Apple"
```

Example response:

```json
[
  {
    "title": "Apple announces...",
    "description": "...",
    "url": "https://...",
    "publishedAt": "2026-08-03T12:00:00Z"
  }
]
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

The server will start at `http://localhost:5000`. You can check the endpoint
with:

```bash
curl http://localhost:5000/health
```

or by visiting that URL in a browser.

## Running tests

With the virtual environment active:

```bash
pytest -v
```

This runs the test suite, which checks that `/health` returns a 200 status code
and that the response body contains the expected fields.

## Running with Docker

Docker runs the application using gunicorn, opposite to how it is run directly
in Python. Docker also adds a health check that sends signals based on the
health of the application.

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

### Troubleshooting

It is possible that if you are on a Mac, port 5000 will be in use. This will
result in an "address is already in use" error when running the container. In
that case, try using port 8080 or any other free port. Just switch the port
number on the left-side of the colon to any number in the range of (1024-65535).

```bash
docker run -p <Any Free Port>:5000 meridian-application
```

The application can be accessed at `http://localhost:5000`, however if you
choose to change the port, you must change the port number in the URL as well.

## Running with Docker Compose

This application can be run locally using Docker Compose. Docker Compose will
build the Flask application container, configure the required environment
variables, and expose the service on the configured port.

### 1. Create the environment file (Optional: Only for /news and Debug Mode)

Create a `.env` file in the root directory of the project

Add the following environment variables:

```env
ENV=dev
NEWS_API_KEY=your_news_api_key_here
```

- `ENV=dev` enables Flask debug mode for local development.
- `NEWS_API_KEY` should contain your own API key from NewsAPI. Needs an API key
  to function. A free API key can be obtained from
  [NewsAPI](https://newsapi.org/).

There is an example.env file to use which outlines the variables above. Simply
remove the "example" portion and add an API key.

### 2. Build and start the application

To build the Docker image and start the application, run:

```bash
docker compose up --build
```

If the Docker image has already been built and there are no changes to the
Dockerfile, you can start the application with:

```bash
docker compose up
```

### 3. Access the API

Once the container is running, the API will be available at:

```text
http://localhost:8080
```

This Docker Compose uses 8080 as the host port, you can change it in the .yaml
file.

### 4. Stop the application

To stop and remove the running containers, run:

```bash
docker compose down
```

## Deploying With minikube

Repository contains deployment.yaml, service.yaml, and configmap.yaml to use for
deploying with minikube

## CI Pipeline

The CI pipeline runs automatically whenever a **Merge Request (MR)** is opened.
It validates the codebase through four stages to ensure code quality and
deployment readiness.

### Lint

Performs code quality and static analysis checks, including:

- Commit message validation
- Secret detection
- mypy type checking
- ruff linting

### Test

Runs the project's **pytest** suite to verify that existing and newly added
tests pass successfully.

### Build

Builds the Docker image to ensure the application can be packaged without
errors.

### Push (Only on default [main] branch)

Authenticates with **Amazon ECR** and verifies that the Docker image can be
pushed successfully.
