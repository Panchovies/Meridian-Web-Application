# Tuesday, August 4th

## Running in Python vs Docker

The main difference in running an application in Python directly vs using a container is the consistency and scalability. When runnning in Python directly, a changes in between machines and enviornments can change the way an application runs and interacts with the system. When using a container, the enviornment, dependencies, and versions of software all remain the same, alowing for simpler testing and significantly less setup. Containers also allow for scalability as multiple instances of containers can be run simultaniously allowing for stress testing and parralel work. This is perfect for Meridian, who has multiple people testing and deploying, so making sure enviornments stay consistent saves time and resources.

# Wednesday, August 5th

## What Does A Pipeline Do?

This repository has a .gitlab-ci.yml file, which when pushed, runs through three stages:
Lint - Checks for syntax and code quality standards. To ensure all code across an application created by a team looks and operates the same, the linter makes sure that sound code quality practices are used throughout the entire project. If the linter finds any issues with the code, it fails the pipeline and does not move to the next stages.
Test - This runs any pytests made by the developer. These are only run if the lint stage passed, and only passes if every single pytest passes. These are to check whether any changes made in the current commit are now failing.
Build - Attempts to build the Docker image. Making sure the Docker works is veey necessary to the overall project. If the Docker does not work, there is no way to test in identical enviornments across different machines. 
These stages are run in this order because they depend on each other. Running them parallel to each other can result in slower and more expensive checks. If they are run simultaneously and the linter fails, then we are wasting time and resources waiting for the Docker to finish, knowing that if will fail, or at the very least, that the developer will have to push again.

# Thursday, August 6th

## Systems Thinking Questions

### What port is this application listening on? Why?

The application listens on the 5000 port. This is becasue the default/usual port for Flask is 5000. However my dockerfile uses 8080 as the host port, since my Mac uses port 5000 for an Airplay Connection.

### How would you know if the application stopped responding?

If the localhost url was no longer able to connect to the application, say through a URL timeout or a refusal of connection. However, not if the application gave you an error. That would be a code issue.

### What would you check first if the containter was running but the endpoint was returning errors?

The probable cause is something in the application's code. If the container is running but the endpoint is returning errors, that means there is most likely a code issue in the .py files, not an issue with the Dockerfile or compose file.

### What is the difference between the application being down and the container being down?

If the application is down, that means you would not even be able to run it locally using Python, however if the container was down the code could run locally using Python. The application being down is an issue with the .py files, the container being down is some issue with the Docker image or Dockerfile.

### What happens to in-flight requests if the container is restarted

The in-flight requests would be interrupted if the container is restarted, and would require the client to retry them after restarting, since they would not automatically resume after restarting.
