# Systems Questions

## Tuesday, August 4th

### Running in Python vs Docker

The main difference in running an application in Python directly vs using a
container is the consistency and scalability. When running in Python directly, a
changes in between machines and environments can change the way an application
runs and interacts with the system. When using a container, the environment,
dependencies, and versions of software all remain the same, allowing for simpler
testing and significantly less setup. Containers also allow for scalability as
multiple instances of containers can be run simultaneously allowing for stress
testing and parallel work. This is perfect for Meridian, who has multiple people
testing and deploying, so making sure environments stay consistent saves time
and resources.

## Wednesday, August 5th

### What Does A Pipeline Do?

This repository has a .GitLab-ci.yml file, which when pushed, runs through three
stages: Lint - Checks for syntax and code quality standards. To ensure all code
across an application created by a team looks and operates the same, the linter
makes sure that sound code quality practices are used throughout the entire
project. If the linter finds any issues with the code, it fails the pipeline and
does not move to the next stages. Test - This runs any pytest made by the
developer. These are only run if the lint stage passed, and only passes if every
single pytest passes. These are to check whether any changes made in the current
commit are now failing. Build - Attempts to build the Docker image. Making sure
the Docker works is very necessary to the overall project. If the Docker does
not work, there is no way to test in identical environments across different
machines. These stages are run in this order because they depend on each other.
Running them parallel to each other can result in slower and more expensive
checks. If they are run simultaneously and the linter fails, then we are wasting
time and resources waiting for the Docker to finish, knowing that if will fail,
or at the very least, that the developer will have to push again.

## Thursday, August 6th

### Systems Thinking Questions

#### What port is this application listening on? Why?

The application listens on the 5000 port. This is because the default/usual port
for Flask is 5000. However my Dockerfile uses 8080 as the host port, since my
Mac uses port 5000 for an Airplay Connection.

#### How would you know if the application stopped responding?

If the localhost URL was no longer able to connect to the application, say
through a URL timeout or a refusal of connection. However, not if the
application gave you an error. That would be a code issue.

#### What would you check first if the container was running but the endpoint was returning errors?

The probable cause is something in the application's code. If the container is
running but the endpoint is returning errors, that means there is most likely a
code issue in the .py files, not an issue with the Dockerfile or compose file.

#### What is the difference between the application being down and the container being down?

If the application is down, that means you would not even be able to run it
locally using Python, however if the container was down the code could run
locally using Python. The application being down is an issue with the .py files,
the container being down is some issue with the Docker image or Dockerfile.

#### What happens to in-flight requests if the container is restarted

The in-flight requests would be interrupted if the container is restarted, and
would require the client to retry them after restarting, since they would not
automatically resume after restarting.

## Monday, August 10th

### Why Use Kubernetes? Why Not Use A Manual Script?

#### IP changes

Unless you are using an Elastic IP, which costs money, every time you restart
the EC2 instance, you have to copy the new IP over to the deploy script. This
adds a task that Kubernetes skips.

#### Multiple Instances

With a script, you must manually decide specifics when it comes to creating
multiple instances. It also requires running the script multiple times depending
on how it is set up. Kubernetes handles all of this internally and allows for
the simple distribution of multiple instances.

#### Health Checks

A script must be created with exact health checks and if statements in mind, and
even then a script will only be executed once and cannot remain in a constant
state of checking. Kubernetes allows for a live health check as well as
continuously watching over the instances.

#### Updating

If updating, a script must usually tear down the old process or change something
before the new process can begin. Kubernetes allows for rolling updates which
deploys new versions side-by-side with old ones until all traffic is on the new
one.

#### Secret Management

For the script, secrets like IP, account ID, etc... must be stored in some local
file, while Kubernetes encrypts secrets natively.

## Tuesday, August 11th

### How Does Kubernetes Self-Heal?

When deleting a pod with kubectl, we can examine multiple changes with the pods.
First, termination begins with the selected pod. Before the pod is even
terminated, Kubernetes begins creating a new container to replace the previously
deleted pod. Once the pod is completely terminated the new pod takes over. One
thing of notice is that during this termination, the endpoint did not once fail,
even when refreshing. This is most likely due to Kubernetes shifting traffic
over to the only available pod at the time until the new pod was up and running.

## Wednesday, August 12th

### How Probes React To A Broken Health Check

Before introducing the new bug, two pods were running correctly. I changed the
/health code such that the endpoint would return 500 instead of 200. I built a
new image with the "broken" tag attached, then changed the deployment.yaml file
to reflect this image change. After applying, Kubernetes began the process of
creating a new pod featuring this new image's container. It began running, but
since the /health endpoint was destined to fail, it would fail, then restart.
However, the 2 old pods from the previous replica set were not terminated. They
stayed running, taking up all traffic as they waited for the new pod to be
approved. The pods would not be replaced unless Kubernetes knew that they were
healthy. This behavior is the rolling updates; pods were not deleted even when
new images were given in case the images did not run correctly.

### Rolling Update vs Full Pod Deletion

If we were to fully delete all pods then implant new pods with new images, then
if there was a bug in the new image, then all traffic to those nodes would halt,
there would be no where to send additional traffic, and we would have to delete
those new nodes and reinstate the original image, which could be difficult if we
are replacing the old images with the new ones. With rolling updates, pods are
only removed when the pods have been probed properly and are running as they
should. This gives a fallback where if new buggy images are used, the old pods
will be active and funnel traffic through them until those new buggy images are
fixed and reapplied. Meridian cares about this because they receive high volumes
of traffic daily. If they have to shut down pods for even a brief moment because
of a poor decision to delete them instead of performing a rolling update, they
can lose a lot of money due to the high volume of traffic which would have
nowhere to go.

## Thursday, August 13th

### Load Test

Sent in 1000 requests in rapid succession to the site. Grafana reflected this
"attack" in about 5 seconds, which to me feels a bit slow, however it is
possible that the amount of requests was too low for Grafana to immediately
signal anything. Every dashboard besides pod resets spiked; however something
interesting I noticed was that while CPU and HTTP request rate went back to
their original values, memory stayed at the same position after peaking, long
after there were no more get requests.

## Monday, August 17th

### What does eksctl create?

eksctl creates the control plane as well as the EKS cluster in the repository's
region with managed clusters. It also creates 2 separate cloud formation stacks
for the cluster and the managed nodegroup. The node group is comprised of 2
`t3.small` EC2 instances. It also adds 4 addons: `vpc-cni`, `kube-proxy`,
`coredns`, and `metrics-server` after the nodegroup was created. It also updated
my `kubeconfig`, so kubectl points at the cluster.

### Control plane vs worker nodes

The control plane is the brain of Kubernetes, fully managed by AWS so we never
have to do anything with it. The worker nodes, however, are the EC2 instances
that run the container/application. We are in charge of what goes on in them,
however, since they are managed, they still are capable of self-healing.

## Tuesday, August 18th

### What happens when you change from nodeport to loadbalencer?

NodePort opens a static port on every worker's own IP. This means that the
person attempting to access the node must know the IP as well as the port
assigned to it. This does not function as well when using EKS due to the fact
that there are multiple worker nods and their IP are not stable. Usually they
are not even reachable publicly by design, so while a NodePort could work, it
would be realistically impossible to reach it.

LoadBalancer, on the other hand, tells Kubernetes to provision an AWS Elastic
LoadBalancer. This manages all the traffic and IP tracking, giving you a real
DNS hostname to use rather than tracking the IP manually. LoadBalancer itself
actually uses NodePort mechanics but publicly users and clients interact with
the LoadBalancer.

### From internet request to Flask process

From hop to hop:

The client looks up the URL, which resolves to public IP addresses owned by the
LoadBalancer.

The client hops to the LoadBalancer, and the security group must allow it to
pass or the connection gets dropped.

LoadBalancer hops to the node, where the LoadBalancer opens a new TCP connection
to an EC2 worker node. The worker node is connected to a NodePort that
Kubernetes auto-allocated when creating everything.

Node hops to pod, this comes from the receiving node to the pod's IP.

Pod hops to container, specifically the container port of 5000, established in
the manifests.

Container hops to `gunicorn`, which is the server running the application.

`guinicorn` hops to the Flask app and flask matches the endpoint to the ones
already built.

## Wednesday, August 19th

### Tracing a code change from your local machine to the running application

- Code changes in the application code.
- Code is saved and added to be committed
- Code is committed and pushed
- Once that code is merged into the default branch, the pipeline runs
- First the `checks` stage
- If that passes, the `build` stage starts since application code was changed
- `build` creates a new image, then artifacts it for `push`
- If `build` stage passes, `push` starts
- `push` grabs that artifact and authenticates using the keys in GitLab (this is
  why the branch must be a protected branch)
- `push` tags the image with the SHA commit code and sends to the ECR
- If push passes, then the `deploy` stage runs
- `deploy` installs `aws-cli` and `kubectl` in a different manner from `push`
  because it is not using a Docker image
- `deploy` checks to see if the cluster is up and fails if it isn't
- `deploy` applies the manifests but since there is no change in those nothing
  happens
- That is where the `rollout restart` command comes in to force a rolling update
  and force Kubernetes to find the latest image
- That image is used in the pods which try to start one at a time, only
  replacing the old pods if the pods are healthy and running
- The pods are replaced and the web application updates

## Monday, August 31st

### What is Terraform State?

### What happens when terraform apply is ran against the same infrastructure
