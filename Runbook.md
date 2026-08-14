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

## AWS

## Kubernetes
