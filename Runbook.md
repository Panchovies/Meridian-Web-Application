# Runbook For Meridian Web Application

This runbook exists for those who will be in charge of this repository to give
guidance into what the app is, how to run it, how to diagnose issues, and how to
fix any issues that may come up.

This runbook makes some assumptions:

- You are a competent software engineer
- You have little to no experience in the following: Flask, Docker, AWS, ECR,
  EC2, Kubernetes, minikube, and Grafana
- You understand basic linux commands and how to use a terminal, as well as
  knowledge in installing Python and any Python packages
- You have access to my AWS account, in this context that account would be
  Meridian's account

This runbook contains information necessary to run this application split into 6
chapters:

- Working Within This Repo
- Python (Flask)
- Docker
- AWS
- Kubernetes
- Grafana

With an additional chapter at the end covering basic Kubernetes "How To"

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

### What Is It

Kubernetes runs multiple copies of the app, restarts them if they fail, rolls
out new versions without downtime, and keeps config and secrets separate from
the image itself. Locally, I run it on minikube.

### How We Use It

This repository uses 4 different manifests:

- **`deployment.yaml`**: runs 2 replicas. It is set up with a rolling update
  (`maxUnavailable: 0`, `maxSurge: 1`), so a new pod comes up before an old one
  goes away — you should never have zero available replicas during a deploy.
  Both `livenessProbe` and `readinessProbe` hit `/health` on port `5000`. Config
  and secrets get pulled in wholesale via `envFrom`, grabbing every key from the
  `meridian-web-application-config` ConfigMap and the `meridian-api-keys` Secret
  as environment variables. Resource `requests` are `128Mi`/`250m` CPU; `limits`
  are `256Mi`/`500m` CPU. `imagePullPolicy: Never` on the Deployment means
  Kubernetes won't try to pull `meridian-web-application:local` from anywhere,
  meaning it must be sitting in the node's local image cache. so much.
- **`service.yaml`**: a `NodePort` Service, exposing the Deployment on port `80`
  internally and `30080` on the node itself, forwarding to container port
  `5000`.
- **`configmap.yaml`**: non-secret config — just `PORT` and `ENVIRONMENT`.
- **`meridian_service_monitor.yaml`**: tells Prometheus (via the Prometheus
  Operator) to scrape `/metrics` every 15 seconds. This only works if you've
  already got the Prometheus Operator and a release labeled `monitoring`
  installed in your cluster.

### How To Run It

Start minikube and point your shell's Docker client at minikube's own Docker
daemon, so the image you build ends up somewhere the cluster can actually see
it, then build:

```bash
minikube start
eval $(minikube docker-env) # This must be run once per terminal session if you want to build a new image
docker build -t meridian-web-application:local .
```

I never committed the secret to the repo, so you'll need to create it by hand
once before the Deployment will come up healthy:

```bash
kubectl create secret generic meridian-api-keys \
  --from-literal=NEWS_API_KEY='your-key-here'
```

Apply the manifests:

```bash
kubectl apply -f configmap.yaml -f deployment.yaml -f service.yaml
```

Check it's up and reach it:

```bash
kubectl get pods
minikube service meridian-web-application --url
```

### How To Diagnose It

```bash
kubectl get pods
```

`Running` with `2/2` (or however many containers) ready is what you want.
Anything else — `CrashLoopBackOff`, `ImagePullBackOff`, `0/1` ready — send you
to one of the next two commands.

```bash
kubectl describe pod <pod-name>
```

Check the events at the bottom, look for errors like probe failures, image pull
errors, scheduling failures. I usually reach for this before logs, since it
tells you _why_ a pod isn't ready rather than just what the app printed.

```bash
kubectl logs <pod-name>
```

Same idea as `docker logs`, just for a pod. Add `--previous` if the container
already restarted and you need to see why it crashed last time, not what it's
printing now.

### Common Bugs

- **`ImagePullBackOff` right after `minikube start`**: you built the image with
  your regular Docker daemon instead of minikube's. Run
  `eval $(minikube docker-env)` in the same shell you're building in, then
  rebuild. You'll have to do this every time you open a new terminal — it
  doesn't stick around.
- **`CreateContainerConfigError` mentioning `meridian-api-keys`**: the Secret
  was never created, or you deleted it. Re-run the `kubectl create secret`
  command above.
- **Readiness flapping / pod bouncing between ready and not ready**: I set the
  readiness probe to `initialDelaySeconds: 0` and `failureThreshold: 1` — it
  starts checking right away and only tolerates one failure. If the app is slow
  to bind on startup, you'll see it get marked not-ready before it's had a real
  chance. Compare that against the liveness probe's more forgiving
  `initialDelaySeconds: 10` if you think this is what's happening.
- **`/metrics` not showing up in Prometheus**: the `ServiceMonitor`'s
  `namespaceSelector` is hardcoded to `default`, and its `release: monitoring`
  label has to match however you installed the Prometheus Operator. If either
  one is off for your cluster, Prometheus just won't scrape it — no error,
  you'll just notice the data's missing.

## Grafana

### What Is It

Grafana is the dashboard on top of Prometheus's data. Prometheus scrapes and
stores the metrics; Grafana is where you actually look at them. I installed it
as part of the `kube-prometheus-stack` Helm chart in the `monitoring` namespace,
alongside Prometheus itself, Alertmanager, and the exporters that feed them.

### How We Use It

To begin, apply the `meridian_dashboard.yaml` file:

```bash
kubectl apply -f meridian_dashboard.yaml
```

Grafana isn't exposed outside the cluster, so you reach it by port-forwarding:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Helm generates a random admin password rather than defaulting to something
guessable. Get it with:

```bash
kubectl get secret -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

Username is `admin`. Open `http://localhost:3000` and log in.

The chart ships a curated set of dashboards from the `kubernetes-mixin` project
(per-pod resources, namespace-wide resources, networking, node-level stats),
plus one I built myself specifically for Meridian, with 4 panels:

#### Panel 1 — CPU Utilization

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="default", pod=~"meridian.*"}[5m])) by (pod)
```

CPU usage per pod, in cores. The underlying metric is a cumulative counter, so
this uses `rate()` over a 5-minute window to turn it into a per-second average —
a raw counter just climbs forever and isn't useful to graph directly. Check this
first if a pod feels slow and you suspect it's CPU-bound.

#### Panel 2 — Memory Utilization

```promql
sum(container_memory_working_set_bytes{namespace="default", pod=~"meridian.*"}) by (pod)
```

Memory usage per pod. Uses `working_set_bytes` rather than `usage_bytes`
specifically because working set is what the OOM killer actually evaluates — it
excludes reclaimable page cache, so it's the more honest number for "how close
is this pod to getting OOMKilled." Compare against the `256Mi` limit set in
`deployment.yaml`.

#### Panel 3 — Pod Restart Count

```promql
kube_pod_container_status_restarts_total{namespace="default", pod=~"meridian.*"}
```

Cumulative restarts per pod over time. Deliberately not rated — for restarts you
want the raw step pattern (a line that jumps means "this pod restarted around
this time"), since a rate of restarts is noisier and harder to read at a glance.
If you're chasing a crash loop, this tells you when it started and whether it's
ongoing.

#### Panel 4 — HTTP Request Rate

```promql
sum(rate(flask_http_request_total{app="meridian"}[5m])) by (method, status)
```

Request rate broken down by HTTP method and status code. This comes from
`prometheus-flask-exporter`, which I added to the app to expose a `/metrics`
endpoint — without it, Prometheus only sees infrastructure-level metrics (CPU,
memory, restarts) and has no idea what `/news` or `/health` are doing. This is
the panel to check for a 500s incident: a spike in the `5xx` status series here
confirms it's happening and roughly how often.

### How To Diagnose It

If a panel is empty or flat when it shouldn't be, first confirm Prometheus is
actually scraping Meridian. Port-forward into Prometheus itself:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Then check **Status → Targets** at `http://localhost:9090` and look for
`meridian-monitor`. It should show as `UP`. If it's missing entirely or shows
`DOWN`, the problem is upstream of Grafana — see the Common Bugs below.

### Common Bugs

- **Dashboard panels are empty, but Prometheus itself is running**: almost
  always the `release: monitoring` label on `meridian_service_monitor.yaml`. The
  Prometheus Operator only watches `ServiceMonitor` objects carrying the label
  matching its own Helm release name (`monitoring`, in our case). Get this wrong
  and the `ServiceMonitor` is silently ignored — no error anywhere, the data
  just never shows up.
- **Panel 4 specifically is empty, but 1–3 are fine**: Panels 1–3 come from
  infrastructure-level metrics (cAdvisor, kube-state-metrics), which exist
  regardless of what Meridian's code does. Panel 4 depends on Meridian itself
  exposing `/metrics` via `prometheus-flask-exporter`. If that's missing from
  the running image, Panel 4 will be empty while the rest work fine.
- **Can't log in / forgot the password**: don't try to reset it manually — just
  re-run the `kubectl get secret` command above. Helm doesn't rotate it, so the
  same command works every time.
- **`kubectl port-forward` connection drops**: this is a live connection tied to
  your terminal session: closing the terminal, sleeping your laptop, or the pod
  restarting will kill it. Just re-run the port-forward command.

## Kubernetes How To

### How to check whether the application is running

To check if the application is running, use:

```bash
kubectl get pods
```

This will display all active pods at the moment of request. Pods will have a
status in the third column. If the status displays "RUNNING", then the
application is running.

### How to read recent pod logs

To check the last 100 pod logs of a deployment, use

```bash
kubectl logs deployment/meridian-web-application --tail=100
```

This will show what is happening in a pod as well as what time it occurred

This will also show you errors that occurred in the pods

### How to check resource utilization

Grafana will visualize all the resource utilization you need to be monitoring
(CPU, Memory)

### What to do when all pods are in a crash loop

Check the logs as referred to above. However, many times something goes wrong
before the logs are able to show it. If that is the case, use

```bash
kubectl describe pod <pod-name>
```

and scroll down to the `Events` section. This will show you specific errors that
occurred. Looks for things like:

- App crashes on startup: missing or malformed environment variable, bad config,
  unhandled exception at import time. Logs from --previous will usually show a
  stack trace.
- Failing liveness probe: the app starts but the health check endpoint isn't
  responding in time, so Kubernetes kills and restarts it repeatedly.
  `describe pod` will show liveness probe failed events.
- Missing Secret or ConfigMap: if the pod can't mount a referenced
  Secret/ConfigMap, it may crash before your app code even runs.
- Resource limits too low: if the container is OOMKilled, describe pod will show
  Reason: OOMKilled instead of a normal exit.

Fix the underlying cause, then let Kubernetes retry, or force a fresh rollout:

```bash
kubectl rollout restart deployment/meridian-web-application
```

### What to do when the application returns 500s

Start with recent logs to see the actual error and traceback:

```bash
kubectl logs deployment/meridian-web-application --tail=100
```

If the errors are intermittent, tail logs live while reproducing:

```bash
kubectl logs deployment/meridian-web-application -f
```

Then check `/health` directly to see if the app considers itself healthy, versus
a downstream dependency being the problem:

```bash
kubectl exec -it <pod-name> -- curl localhost:<port>/health
```

Open the Grafana dashboard and check the error rate and latency panels — a spike
aligned with a specific timestamp usually points to a bad deploy, a downstream
dependency (e.g. NewsAPI) going down, or a resource crunch (CPU/memory maxing
out and slowing request handling).

Questions to narrow it down:

- Did this start right after a deploy? If so, its likely a code or config
  regression, consider rolling back.
- Is it every request or only some? If some, then its likely a specific
  downstream call or edge case failing.
- Are CPU/memory graphs pegged in Grafana? If so, then its resource exhaustion,
  not a code bug.

### How to roll back to a previous version

Kubernetes has a built in rollback function for deployments with distinct,
immutable tags (which if you're pulling from the ECR, they do):

```bash
kubectl rollout undo deployment/meridian-web-application
```

Then watch the rollout to confirm it completes:

```bash
kubectl rollout status deployment/meridian-web-application
```

Then verify by checking the pods and the `/health` endpoint.
