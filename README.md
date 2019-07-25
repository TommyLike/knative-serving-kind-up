# knative-serving-kind-up
Setting up knative serving kind environment for development

# Requirements:
1. go: The language Knative Serving is built in (**1.12rc1 or later**)
2. git: For source control
3. dep: For managing external Go dependencies. **Ensure all **
4. ko: For development.
5. kubectl: For managing development environments.

# Other requirements:
1. Please ensure all knative serving related dependencies have been synced with `dep ensure` before.
2. Please update the variable `KO_DOCKER_REPO` as your own docker repo in `hack/setup-environment.sh`
3. Please ensure docker has been successfully login.

# Command
```
make run
```
