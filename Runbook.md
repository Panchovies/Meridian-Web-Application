# Runbook For Meridian Web Application

## If Something Is Down And Needs Immediate Attention, Start Here

If the app is down and you don't have time to read the whole runbook, run these
three commands in order. The first one tells you whether you're looking at a
cluster problem or an application problem — everything after that depends on
which one it is.

**1. `kubectl get nodes`**

This tells you if the cluster itself is healthy.

- If any node is **not** `Ready` → this is a **cluster problem**. Skip the
  app-debugging steps below and go straight to the eksctl section of this
  runbook (node/cluster health, scaling, rebuild).
- If all nodes are `Ready` → the cluster is fine, this is an **application
  problem**. Continue to step 2.

**2. `kubectl get pods -A`**

Now that you know the cluster's healthy, find out what's actually broken. Look
for anything that isn't `Running` or `Completed` — `CrashLoopBackOff`,
`ImagePullBackOff`, `Pending`, or a pod with a high `RESTARTS` count.

**3. `kubectl rollout undo deployment/meridian-web-application`**

If step 2 shows the app pods are the problem (crashing, not starting, failing
readiness), don't debug live at 2am — roll back first, restore service, then
debug the root cause later with a clear head. Confirm it worked with
`kubectl rollout status deployment/meridian-web-application`.

## Runbook Guide

This runbook exists for those who will be in charge of this repository to give
guidance into what the app is, how to run it, how to diagnose issues, and how to
fix any issues that may come up.

This runbook makes some assumptions:

- You are a competent software engineer
- You have little to no experience in the following: Flask, Docker, AWS, ECR,
  EC2, EKS, Kubernetes, and eksctl
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
- eksctl

This runbook follows a certain pattern for each of the chapters (excluding
Working Within This Repo):

- What Is It
- How We Use It
- How To Run It
- How To Diagnose It
- Common Bugs

## Working Within This Repo

### Merge Request Workflow

Anytime a change must be made to the repo, it should always be done on a
separate branch, then once the code has been peer-reviewed by at least two
developers, it can be merged to `main`. `main` should NEVER be pushed to
directly. There are reasons for these checks, abide by them so that mistakes
won't be permanent.

For more information and branch/commit structure, read the Confluence page on
[Merge Request Workflow](https://meridian-capital-markets-delivery-services.atlassian.net/wiki/spaces/DS/pages/2686978/Merge+Request+Workflow)

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

Information on running the application through Python can be found in the
[README](https://gitlab.com/mcm-delivery-service-26-08/francisco_zenklusen_w1/-/blob/main/README.md)

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
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "src.app.app:app"]
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

Information on running the application through Docker can be found in the
[README](https://gitlab.com/mcm-delivery-service-26-08/francisco_zenklusen_w1/-/blob/main/README.md)

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

## ECR

### What Is It

ECR or Elastic Container Registry stores Docker images in a cloud to be pulled
to use remotely.

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

Check that the Docker images are actually stored in ECR, either by viewing the
repository and its images in the AWS Console, or by using the AWS CLI:

```bash
aws ecr list-images --repository-name <repository-name>
```

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
the image itself. It is run through EKS.

### How We Use It

This repository uses 3 different manifests, all located in the `k8s/app`
directory:

- **`deployment.yaml`**: runs 2 replicas. It is set up with a rolling update
  (`maxUnavailable: 0`, `maxSurge: 1`), so a new pod comes up before an old one
  goes away — you should never have zero available replicas during a deploy.
  Both `livenessProbe` and `readinessProbe` hit `/health` on port `5000`. Config
  and secrets get pulled in wholesale via `envFrom`, grabbing every key from the
  `configmap.yaml` ConfigMap and the `meridian-api-keys` Secret as environment
  variables. Resource `requests` are `128Mi`/`250m` CPU; `limits` are
  `256Mi`/`500m` CPU. `imagePullPolicy: Always` on the Deployment means
  Kubernetes tries to pull `meridian-web-application:latest` from the ECR.
- **`service.yaml`**: a `LoadBalancer` Service, exposing the Deployment on port
  `80` internally and targeting container port `5000`. Uses HTTP and adds an
  annotation to allow HTTP metrics to be sent to CloudWatch
- **`configmap.yaml`**: non-secret config — just `PORT` and `ENVIRONMENT`.

### How To Run It

It runs on it's own after being applied through kubectl:

```bash
kubectl apply -f k8s/app/
```

This is handled in the `cluster_runner.sh` script

### How To Diagnose It

To check if the application is running, use:

```bash
kubectl get pods
```

This will display all active pods at the moment of request. Pods will have a
status in the third column. If the status displays "RUNNING", then the
application is running.

To check the last 100 pod logs of a deployment, use

```bash
kubectl logs deployment/meridian-web-application --tail=100
```

This will show what is happening in a pod, what time it occurred, and what
errors that occurred in the pods

Many times something goes wrong before the logs are able to show it. If that is
the case, use

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

### Common Bugs

- **Application returning 500s**: Start with recent logs to see the actual error
  and traceback. Then check `/health` directly to see if the app considers
  itself healthy, versus a downstream dependency being the problem. If it is
  every request, it is likely a specific downstream call or edge case. If there
  are CPU alerts in CloudWatch, then it is resource exhaustion.
- **`ImagePullBackOff`**: Kubernetes is unable to pull the image from the ECR.
  This could be a permissions issue, an AWS credentials issue, or an issue with
  the ECR. Try checking the logs of the GitLab pipeline when the files were
  applied. Look for issues pertaining to the image itself.
- **`CreateContainerConfigError` mentioning `meridian-api-keys`**: the Secret
  was never created, or you deleted it. Re-run the `kubectl create secret`
  command found in the `cluster_runner`.

## eksctl

### What Is It

`eksctl` is a command-line tool for creating and managing Amazon EKS clusters.
It simplifies many of the AWS and Kubernetes configuration steps required to set
up an EKS cluster.

### How We Use It

We use `eksctl` to create our cluster from the command line as well as install
Add-ons for CloudWatch. Once we create the cluster we can keep it running with
all the nodes active, but this spends a lot of money in our AWS account. To
reduce the spending while not actively testing or using, we can scale down the
nodes using

```bash
eksctl scale nodegroup --cluster meridian-cluster --name standard-workers --nodes 0 --nodes-min 0 --nodes-max 0
```

then to scale them back up

```bash
eksctl scale nodegroup --cluster meridian-cluster --name standard-workers --nodes 4 --nodes-min 3 --nodes-max 5
```

We can also delete the cluster to reduce as much spending as possible, however
this gets rid of all our Add-ons, changes the hostname for whenever we decide to
recreate, and when we do recreate the cluster it takes a long time to set
everything up back to its original state.

### How To Run It

All of the setup commands exist within an example shell script called
`cluster_runner_example.sh`. Before running it, you must replace the example API
key with an actual API key from [NewsAPI](https://newsapi.org/) and replace the
placeholder account ID with your AWS account ID

Running this shell script from the root of the repo will:

- Create the cluster with two `t3.small` type managed nodes
- Update `kubectl` to point at the cluster
- Creates the AWS Load Balancer Controller
- Add the API key to `meridian-api-keys`
- Apply the manifests in `k8s/app/`
- Add the necessary Add-ons to use CloudWatch
- Restarts the `High 5XX Rate` alarm in CloudWatch to watch the correct metric

This reduces the amount of work needed to start the cluster significantly.

You can find the hostname for the application by running:

```bash
kubectl get ingress
```

and entering the URL under the `ADDRESS` column.

**Important**: Make sure you start the URL with `http`, not `https`, as this
runs insecurely on port 80.

There is also a shell script called `cluster_stopper.sh` which deletes the
LoadBalancer and then the cluster. Recommended to only delete the cluster if
there will be multiple days when it is not in use.

### How We Diagnose It

#### Check cluster health

There is a shell script `ops/health-check.sh` that checks the health of the full
stack in sequence. It makes sure that kubectl can connect to the EKS cluster,
that all expected pods are in Running state, that the AWS Load Balancer URL
returns 200 from the health check endpoint, and that no CloudWatch alarms are
currently in alarm state.

Run it with `./ops/health-check.sh` and it will notify you if anything is
unhealthy.

Start by confirming the nodes are up and ready:

```bash
kubectl get nodes
```

Look for `STATUS` = `Ready` on every node. If a node is `NotReady`, give it a
couple minutes (it may still be joining), then check
`kubectl describe node <node-name>` for the reason under `Conditions`.

Next, check that all pods across all namespaces are healthy:

```bash
kubectl get pods -A
```

You want everything `Running` or `Completed`. Anything stuck in `Pending`,
`CrashLoopBackOff`, `ImagePullBackOff`, or with high `RESTARTS` needs a closer
look — run `kubectl describe pod <pod-name> -n <namespace>` and check the
`Events` section at the bottom.

#### Delete Non-Running Pods

A script `ops/restart-unhealthy-pods.sh` is available to you and deletes any
pods that are not running. Not recommended to use if you just applied or
restarted your deployment.

#### Roll back a bad deployment

If a new deploy is broken (crashing pods, failing health checks, bad app
behavior), roll back to the previous working revision instead of debugging live:

```bash
kubectl rollout undo deployment/meridian-web-application
```

This reverts to the previous ReplicaSet. Confirm it worked:

```bash
kubectl rollout status deployment/meridian-web-application
```

To roll back further than one revision, check history first with
`kubectl rollout history deployment/meridian-web-application`, then target a
specific revision with
`kubectl rollout undo deployment/meridian-web-application --to-revision=<N>`.

#### Read application logs

For a quick look at the current pod's logs:

```bash
kubectl logs <pod-name>
```

If the pod restarted and you need to see why it crashed, check the previous
container's logs:

```bash
kubectl logs <pod-name> --previous
```

To tail logs live while reproducing an issue:

```bash
kubectl logs -f <pod-name>
```

If you don't know the pod name, list them first with
`kubectl get pods -l app=meridian-web-application`, or stream logs across all
pods for the deployment at once:

```bash
kubectl logs -f -l app=meridian-web-application --all-containers=true
```

For anything beyond a single pod's recent logs (historical logs, log search,
logs after a pod has been deleted), use CloudWatch Container Insights — see the
Observability section of this runbook.

#### CloudWatch

CloudWatch will be set up and ready to use if you ran the `cluster_runner.sh`
script. Navigate to the AWS console and search for "CloudWatch". There will be 3
alarms in place:

- **CPU Utilization**: Alerts when cluster CPU utilization exceeds 80% for 5
  consecutive minutes.
- **High 5XX Rate**: Alerts when 5XX responses exceed 1% of total requests.
- **Over 3 Restarts**: Alerts when total pod restarts across all pods are
  over 3.

### Common Bugs

- **Deploy Stage Fails On Pipeline**: *

Start by reading the job log in GitLab — the deploy stage fails at different
points for different reasons, and the log tells you which:

- **`kubectl` commands fail immediately (`connection refused`,
  `Unable to connect to the server`)** — the runner can't reach the cluster.
  Usually means the kubeconfig step didn't run or the cluster's API
  endpoint/security group doesn't allow the runner's IP. Confirm the
  `aws eks update-kubeconfig` step ran successfully earlier in the job.

- **`kubectl apply` fails on a specific manifest** — read the error, it's almost
  always a YAML syntax issue or an immutable field being changed (e.g.
  `selector` on a Service). Fix the manifest in `k8s/app/` and re-run.

- **`kubectl apply` succeeds but `rollout status` times out** — the new pods
  aren't reaching `Ready`. This is the most common failure and isn't really a
  pipeline problem, it's an app problem surfacing in the pipeline. Check:

```bash
  kubectl get pods -l app=meridian-web-application
  kubectl describe pod <pod-name>
  kubectl logs <pod-name>
```

Common causes: bad image tag (`ImagePullBackOff` — check ECR auth and that the
SHA tag actually got pushed), app crashing on startup (`CrashLoopBackOff` —
check logs for a stack trace), or a failing readiness probe (app is up but
`/health` isn't returning 200 yet).

- **`needs: [push]` related failure on a manifest-only commit** — the `push` job
  is `optional: true` in `needs`, so a deploy triggered by a manifest change
  alone (no image build) should still run. If it's failing here, check that the
  `changes:` filter on the deploy stage still matches `k8s/app/**/*`.

**If the rollout is broken and you need the app back up now**, don't wait on
debugging — roll back:

```bash
kubectl rollout undo deployment/meridian-web-application
```

Then debug the bad manifest/image separately before re-deploying.
