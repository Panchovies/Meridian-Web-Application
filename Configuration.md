**This is from a legacy runbook. Has information from pervious lifecycles of
development, like when working with `eksctl` or `minikube` Most of this is
outdated for the current repo, and either you must change the repo to test
locally or use an older commit**

## Kubernetes

### What Is It

Kubernetes runs multiple copies of the app, restarts them if they fail, rolls
out new versions without downtime, and keeps config and secrets separate from
the image itself. Locally, I run it on minikube.

### How We Use It

This repository uses 5 different manifests, all located in the `k8s` directory:

- **`k8s/app/deployment.yaml`**: runs 2 replicas. It is set up with a rolling
  update (`maxUnavailable: 0`, `maxSurge: 1`), so a new pod comes up before an
  old one goes away — you should never have zero available replicas during a
  deploy. Both `livenessProbe` and `readinessProbe` hit `/health` on port
  `5000`. Config and secrets get pulled in wholesale via `envFrom`, grabbing
  every key from the `configmap.yaml` ConfigMap and the `meridian-api-keys`
  Secret as environment variables. Resource `requests` are `128Mi`/`250m` CPU;
  `limits` are `256Mi`/`500m` CPU. `imagePullPolicy: Never` on the Deployment
  means Kubernetes won't try to pull `meridian-web-application:local` from
  anywhere, meaning it must be sitting in the node's local image cache. so much.
- **`k8s/app/service.yaml`**: a `NodePort` Service, exposing the Deployment on
  port `80` internally and `30080` on the node itself, forwarding to container
  port `5000`. (Outdated, current version used `LoadBalancer`, must switch back
  to `NodePort` to test locally)
- **`k8s/app/configmap.yaml`**: non-secret config — just `PORT` and
  `ENVIRONMENT`.
- **`k8s/monitoring/meridian_service_monitor.yaml`**: tells Prometheus (via the
  Prometheus Operator) to scrape `/metrics` every 15 seconds. This only works if
  you've already got the Prometheus Operator and a release labeled `monitoring`
  installed in your cluster.
- **`k8s/monitoring`**: sets up the Meridian Custom Dashboard in Grafana when
  applied. Adds panels for CPU utilization, memory utilization, pod restart
  count, and HTTP request rate

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
kubectl apply -f k8s/
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
kubectl apply -f k8s/meridian_dashboard.yaml
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
eksctl scale nodegroup --cluster meridian-cluster --name standard-workers --nodes 0 --nodes-min 0 --nodes-max 5
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

#### Get Deployment Status

A script `ops/deployment-status.py` is available to you and prints a formatted
status report featuring the following:

- Cluster name
- Node count and status
- Deployment name
- Replica count
- Current image tag deployed
- Timestamp of the most recent deployment

Run from root using `./ops/deployment-status.py`

#### Get Pipeline Summary

A script `ops/pipeline-summary.py` is available to you and prints the last five
pipelines, their elapsed times, and the stages they failed at, if any.

Requires a GitLab token with read permissions for Project, Pipeline, and Job

GitLab token must be stored in a `.gitlab-token` file

Run from root using `./ops/deployment-status.py`

#### Delete Non-Running Pods

A script `ops/restart-unhealthy-pods.sh` is available to you and deletes any
pods that are not running. Not recommended to use if you just applied or
restarted your deployment.

Run from root using `./ops/restart-unhealthy-pods.sh`

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
