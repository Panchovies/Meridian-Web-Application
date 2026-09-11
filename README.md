# Meridian Capital Markets Python Web Application

## Runbook

A runbook for this project exists in the root directory at
[Runbook.md](https://gitlab.com/mcm-delivery-service-26-08/francisco_zenklusen_w1/-/blob/main/Runbook.md)

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

**Depending on how you plan to run it:**

- Docker Desktop
- minikube
- Terraform


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

Install developer dependencies (only necessary for development):

```bash
uv pip install -r requirements-dev.txt
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

## Running with Dockerfile

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

### Troubleshooting

It is possible that if you are on a Mac, port 5000 will be in use. This will
result in an "address is already in use" error when running the container. In
that case, try using port 8080 or any other free port. Just switch the port
number on the left-side of the colon to any number in the range of (1024-65535)
in the `compose.yaml`

### 4. Stop the application

To stop and remove the running containers, run:

```bash
docker compose down
```

## Deploying With minikube

Repository contains deployment.yaml, service.yaml, and configmap.yaml to use for
deploying with minikube

## Deploying With `Terraform`

Repository contains a `terraform/` directory where `terraform apply` can be run to bring up the entire cluster along with any add-ons from nothing. `terraform destroy` can be run to destroy everything created by `terraform apply` to make sure nothing is being charged overnight when not in use.

## CI Pipeline

The CI pipeline runs automatically whenever a **Merge Request (MR)** is opened.
It validates the codebase through 1-6 stages (depending on file changes and protected branches) to ensure code quality and
deployment readiness.

For clarification: **Always** means that the stage runs during a merge request event and on the default branch no matter what.

### Checks

**When:** Always

Performs code quality and static analysis checks, including:

- Commit message validation
- Secret detection
- mypy type checking
- ruff linting
- prettier spell checking
- markdown linting
- yaml linting
- vale linting

### `Terraform`

This stage is split into two parts: one that does not need AWS credentials and one that does.

#### `Terraform-fmt-validate`

**When:** Always

Makes sure `Terraform` files are validated and correctly formatted. Fails if they are not, however will not make the formatting changes in the pipeline.

#### `Terraform-plan`

**When:** On the default branch or automatically on merge request events on a protected branch.

Makes sure `terraform plan` runs without failure. Needs AWS credentials therefore only runs when protected. Does not run `terraform apply`, so it will not create anything.

### Build

**When:** On the default branch and when dockerfile, application code, or manifests are changed, or automatically on merge request events.

Builds the Docker image to ensure the application can be packaged without
errors. Artifacts that image to be used later by the push stage. Image is tagged with the SHA of the commit it is being ran on.

### `Trivy`

**When:** On the default branch and when dockerfile, application code, or manifests are changed, or automatically on merge request events.

Scans the Docker image for any vulnerabilities. Fails and reports any vulnerabilities that are of critical or high status. Uses the artifact created in the `build` stage.

### Push

**When:** On the default branch and when dockerfile, application code, or manifests are changed, or manually on merge request events on protected branches. That manual action will also allow the `deploy` and `smoke` stages to run automatically.

Authenticates with an **Amazon ECR** created by `Terraform` and verifies that the Docker image can be
pushed successfully. Uses the artifact created in the `build` stage.

### Deploy

**When:** On the default branch and when dockerfile, application code, or manifests are changed, or automatically on merge request events on protected branches. Only runs automatically if `push` was run manually.

Deploy applies the deployment manifests, inserting the correct ECR image using the SHA of the current commit. Waits for deployment to succeed.

### Smoke

**When:** On the default branch and when dockerfile, application code, or manifests are changed, or automatically on merge request events on protected branches. Only runs automatically if `push` was run manually.

Runs a smoke test targeting the `/news` endpoint, checking if it returns a `200` status code without relying on the external API.

