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

`Dockerfile` at the repo root builds from `python:3.13-slim`, installs
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

## `Terraform`

### What Is It

`Terraform` is a service that allows us to create the entire cluster as well as
other AWS services in one command. It simplifies the automation portion of
application creation and allows us to manage and control everything with simple
commands.

### How We Use It

We use it to create everything our application needs to run, whether that be the
cluster, cluster add-ons, buckets for storage, or roles and policies. We also
use it as a way to keep the state of our applications more remote and sharable.
The `terraform` state resides in a persistent bucket in AWS, this means that
`terraform` will not destroy or create that bucket, but only hold the state in
there, which allows terraform to know what is already created and destroyed
across many machines.

### How To Run It

Some things must be configured before using `terraform`.

#### State Bucket

You need to have an S3 bucket set up in AWS ready to hold the state. Use these
commands to create that bucket.

```bash
aws s3api create-bucket \
  --bucket meridian-terraform-state-163558211438 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket meridian-terraform-state-163558211438 \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket meridian-terraform-state-163558211438 \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

These commands are made specifically for the `terraform` files in this
repository, you may need to change the name to use your own AWS id number, since
bucket names are static across AWS, so two buckets of the same name cannot
exist, even on separate AWS accounts.

#### `terraform apply/destroy` Permissions

Your AWS user that `terraform` invokes must also have the correct permissions
attached to create and destroy what it needs. You can find an example of these
permissions in `terraform/policies/TerraformPolicy.json`.

**Note:** The current example policy uses my personal AWS id and region, as well
as the ECR, bucket, and cluster names outlined in the `Terraform` files. If you
change the variables that establish those names or have a different id or
region, you must change the policy to reflect that.

#### GitLab CI Permissions

You must create a separate user for your GitLab pipeline to use, this was the
pipeline is not invoking your user which most likely has broader permissions for
administrative use.

Create this user by hand in the AWS console, IAM->Users->CreateUser

Select 'Attach Policies Directly', and attach the policies that the pipeline
needs to run. You can find an example of the permissions that the pipeline
currently needs to run in `terraform/policies/GitLabPolicy.json`.

**Note:** The current example policy uses my personal AWS id and region, as well
as the ECR and cluster names outlined in the `Terraform` files. If you change
the variables that establish those names or have a different id or region, you
must change the policy to reflect that.

Name it `GitLab-CI`.

Create an access key for the user by selecting the user and clicking
`Create Access Key`. This is what we will be inserting into the CI variables to
give GitLab those permissions for access. Click on `AWS CLI` for reason and
accept the terms for creation. When you create it, make sure to download the
`.csv` file to always have the keys for retrieval later.

Navigate to CI/CD in your repository settings and scroll down to Variables. Add
two new variables, and make sure both are protected and masked:
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The `AWS_ACCESS_KEY_ID` will
start with `AKIA`. If you already have an `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`, then edit them and replace their values with the keys
you created.

Your GitLab pipeline will now use the `GitLab-CI` user permissions instead of
your admin permissions.

#### Creating With Terraform

We create everything using `terraform apply` in the `terraform/` directory. Type
in `yes` to proceed with the creation. You'll see multiple lines of different
resources being created with time elapsed stamps. To destroy everything, run
`terraform destroy` and type in `yes` to proceed. If you want to use `terraform`
from the root directory, you can add the `-chdir=terraform/` flag. An example of
this would be `terraform -chdir=terraform/ apply`.

### How To Diagnose It

This is for specifically diagnosing `Terraform` errors. If something is
happening after `Terreform` had either destroyed or created, then it is more
likely an issue with Kubernetes, which can be diagnosed via the Kubernetes
section or the `eksctl` section in `Configuration.md`, however some parts may be
outdated.

`Terraform` will often tell you exactly what failed when creating or destroying.
Running `terraform plan` is a great way to see any possible issues before
applying anything. Many times dependency loops or missing permissions can be
found from the planning stage.

### Common Bugs

- **Permission Issues:** Many times when running `terraform apply` an error can
  pop up that says something about a user not having the correct permissions.
  This should not happen for any roles because this repository's `Terraform`
  creates the policies for those roles itself, so it could only have that error
  if you changed something about the roles. However, if it happens, it is most
  likely due to the user attached to `Terraform` not having the right
  permissions. It can be easily fixed by editing the policy `JSON` and adding
  whichever policy it says it needs for the resources it mentions.

- **Dependency Loops:** There should be no dependency errors with `Terraform`
  unless something about the current architecture is changed. `terraform plan`
  cannot usually catch dependency errors, only dependency loops. That is when a
  resource depends on a resource that is also depending on it; creating a loop
  of dependency. However it is possible for `Terraform` to make a mistake when
  creating resources and create something that should rely on another resource
  before that resource is created. To avoid this, make sure you know what each
  resource needs before being able to be created, and you can check the
  dependency chain before applying in `terraform plan`.
