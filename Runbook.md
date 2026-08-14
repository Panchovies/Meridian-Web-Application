# Runbook For Meridian Web Application

This runbook exists for those who will be in charge of this repository to give
guidance into what the app is, how to run it, how to diagnose issues, and how to
fix any issues that may come up.

This runbook makes some assumptions:

- You are a competent software engineer
- You have little to no experience in the following: Flask, Docker, AWS, ECR,
  EC2, and Kubernetes
- You understand basic linux commands and how to use a terminal, as well as
  knowledge in installing Python and any Python packages
- You have access to my AWS account, in this context that account would be
  Meridian's account

This runbook contains information necessary to run this application split into 4
chapters:

- Working Within This Repo
- Python (Flask)
- Docker
- AWS
- Kubernetes

This runbook follows a certain pattern for each of the chapters (excluding
Working Within This Repo):

- What Is It
- How We Use It
- How To Run It
- How To Diagnose It
- Common Bugs

## Working Within This Repo

### Branching And Commits

Anytime a change must be made to the repo, it should always be done on a
separate branch, then once the code has been peer-reviewed by at least two
developers, it can be merged to `main`. `main` should NEVER be pushed to
directly. There are reasons for these checks, abide by them so that mistakes
won't be permanent.

Branches should be named with this structure: `type/changes`.

Commits should be named with this structure:
`type(optional scope): description`.

Types are as follows:

`feat`: adds a capability the service did not have

`fix`: corrects broken behavior

`docs`: changes documentation only

`test`: adds or corrects tests, with no production-code change

`refactor`: restructures code without changing what it does

`build`: changes packaging, dependencies, or the container

`ci`: changes the pipeline

`chore`: is none of the above and affects no shipped behavior

### Merge Requests

When creating a merge request, follow the template given and fill out the 4
categories:

`Jira`: Link your Jira ticket

`Describe`: Describe changes made; should be in the imperative

`Test`: Explain the testing that was done before merging

`Justify`: Justify any tradeoffs made while making changes

### Pre-commit

Pre-commit is a way of checking linters before committing any code. This allows
you to catch any poor quality code and errors before pushing. `pre-commit` must
be installed via Python, and hooks must be installed locally in the repository
only once:

```bash
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
```

## Python (Flask)

### What Is It

Flask is the main Python package used in this web application. It is the core of
the application, creating endpoints for our websites which can allow use to
gauge health metrics.

### How We Use It

The python code for this application is small but important. All python
application code lives in the src/app/ directory.

There are three endpoints used in this application:

- `/health`: Returns the health of the application, which includes the health of
  the other two endpoints.
- `/metrics`: Gives metrics on network traffic. Uses a python package for most
  of its implementation.
- `/news`: Returns top news articles on the given query parameter `q=` in the
  url. Needs a free API key from [NewsAPI](https://newsapi.org/).

### How To Run It

Clone the repository, then create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install dependencies:

```bash
uv pip install -r requirements.txt
```

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

### How To Diagnose It

Unlikely that many issues would stem from the python code assuming it is not
changed in any way. However, if there are issues with the code, they would come
up within the application, say like the `/news` endpoint returning a failure
status code. Any other issues that would have to do with connecting to the site
or the application itself would more likely have to do with Docker, AWS, or
Kubernetes.

There are also pytests to help diagnose any application issues. If those pass
then the logic of the application itself is not the issue.

### Common Bugs

The most common bug that may occur at the application level is missing an API
key. The application grabs an API key labeled `NEWS_API_KEY` from the
environment using the `os` package. There are different solutions for this
depending on what level you are running the API at. If you are running locally,
then you need to add a `.env` file that includes the API key name. There is an
`example.env` provided in the repository.

You will also need to add that key to CI variable in GitLab and as a secret in
Kubernetes.

## Docker

### What Is It

Docker packages up the application and everything it needs to run into one
image, so it runs the same whether you're on your laptop, in CI, or on EC2. It
acts as a way for the application to remain the same even if used on a different
machine.

### How We Use It

`Dockerfile` at the repo root builds from `python:3.14.3-slim`, installs
`requirements.txt` and the project itself, then drops down to a non-root user
`(appuser, uid 1000)` instead of running as root. The container exposes port
`5000` and runs the app with gunicorn:

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "src.app.app:app"]
```

There is also a `HEALTHCHECK` that curls `/health` internally every 30 seconds,
so you can see `healthy` or `unhealthy` right in `docker ps` without having to
go check yourself. It will only mark `healthy` if there is an API key present in
the environment, another check to ensure proper use.

`compose.yaml` wraps this up for the local developer. It builds the image, maps
your host's port `8080` to the container's `5000`, and passes through two
environment variables from your shell or a `.env` file: `ENV` and
`NEWS_API_KEY`.

### How To Run It

From the repo root, with a `.env` file in place (see `example.env` for what it
needs):

```bash
docker compose up --build
```

Check it came up healthy:

```bash
docker ps
curl http://localhost:8080/health
```

If you want to run it without compose to test the image the same way CI builds
it:

```bash
docker build -t meridian-web-application .
docker run -p 8080:5000 --env-file .env meridian-web-application
```

### How To Diagnose It

```bash
docker ps
```

Check the `STATUS` column. `healthy` means `/health` is responding inside the
container. `unhealthy` means the app came up but `/health` is failing.
`Restarting` or an immediate exit means it never came up at all.

```bash
docker logs <container-id>
```

This should be your first move for anything unhealthy or exited. If there's a
Python traceback, you'll find it here.

```bash
docker inspect --format='{{json .State.Health}}' <container-id>
```

This gives you the last few health check results directly, including the output,
if you want more than just healthy/unhealthy.

### Common Bugs

- **Port already in use**: It is possible that port `8080` is already bound on
  your machine somehow. The simplest fix for this is to change the host-side
  port in `compose.yaml`.

  For reference on the ports: `<host port>:<container port>`

- **Missing environment variables**: if you don't have `NEWS_API_KEY` set, the
  container will still start, but `/news` — and `/health` along with it, since
  it checks dependent endpoints — will fail. Check your `.env` file actually
  exists and is populated.
- **Architecture mismatch**: if you build on Apple Silicon (`arm64`), that image
  won't run on the `amd64` EC2 instance. CI builds on `amd64` runners, so you'll
  only hit this if you build and push manually from a Mac.
- **Permission errors writing files**: the container runs as `appuser`, not
  root. If you ever add code that writes to disk somewhere new, you'll get a
  permissions error in the logs — plan for that ahead of time.

## AWS

### What Is It

AWS is a cloud provider which provides two services that matter for this
project: **ECR** (Elastic Container Registry), which stores Docker images so
they can be pulled from anywhere, and **EC2** (Elastic Compute Cloud), which
provisions virtual machine instances to actually run those images.

### How We Use It

The `push` stage in `.gitlab-ci.yml` only runs on `main`, after `build` has
produced `image.tar`. This is so that the ECR is not flooded with constant
changes but also so that the credentials necessary to push to AWS are protected.
It logs into ECR, tags the image with both the short commit SHA and `latest`,
then pushes both tags:

```bash
aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login \
  --username AWS --password-stdin \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"

docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/meridian-web-application:$CI_COMMIT_SHORT_SHA"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/meridian-web-application:latest"
```

`$AWS_ACCOUNT_ID` and `$AWS_DEFAULT_REGION` are masked GitLab CI variables, so
you won't see the real values sitting in the pipeline logs.

The EC2 instance is set up to pull from ECR using an IAM role attached directly
to it, not a static access key, so you shouldn't need to configure any
credentials on the instance itself.

### How To Run It

This process is handled by the GitLab pipeline automatically whenever a branch
is merged. You will most likely not have to manually push to the ECR. However if
you need to, this is how you would.

SSH into the instance (you should have Meridian's AWS key), then:

```bash
aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login \
  --username AWS --password-stdin \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"

docker pull "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/meridian-web-application:latest"
docker run -d -p 8080:5000 --env-file .env \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/meridian-web-application:latest"
```

### How To Diagnose It

Check the instance is actually running, from the console or CLI:

```bash
aws ec2 describe-instance-status --instance-ids <instance-id>
```

If it's up but you can't reach the app, SSH in and check the container the same
way I covered in the Docker chapter (`docker ps`, `docker logs`). If you can't
reach the instance at all, check the security group allows inbound traffic on
whatever port you're testing.

### Common Bugs

- **`no basic auth credentials` / pull denied from ECR**: the instance's IAM
  role doesn't have ECR read permission, or it's not attached anymore. This
  should already be set up correctly, so if you hit this, something changed — go
  check the instance's attached role in the EC2 console.
- **Architecture mismatch**: same problem as in Docker. If you build locally on
  Apple Silicon and push manually, it'll fail on EC2's `amd64` with an
  `exec format error`. You won't hit this with anything CI pushes.
- **Disk full**: `t3.micro` doesn't have much disk. If you're pulling manually
  and not cleaning up, you'll fill it. `docker system prune` gets the space
  back.
- **Instance stopped**: I sometimes stop the instance to save cost. If you can't
  reach the app and it shows `stopped` instead of `running`, start it before you
  go looking for any other problem.

## Kubernetes
