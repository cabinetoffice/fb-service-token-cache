# Deploying fb-service-token-cache to the MoJ Cloud Platform

## The app

The User Datastore application is deployed via [Kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) as a single pod - `fb-service-token-cache` - to the `formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV` namespace where:

- `PLATFORM_ENV` is one of:
  - test
  - integration
  - live
- `DEPLOYMENT_ENV` is one of
  - dev
  - staging
  - production

The User Datastore application can receive requests only from services within the equivalent `formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV` namespace.

## Scripts

To use the following scripts, first run `npm install`

- `scripts/build_platform_images.sh`

  Script to build images for a platform environment

- `scripts/deploy_platform.sh`

  Script to initialise/update Kubernetes deployments for a platform environment

- `scripts/restart_platform_pods.sh`

  Script to explicitly restart pods in a platform environment

All these scripts print out their usage instructions by being run with the `-h` flag

## Configuration files

- `deploy/fb-service-token-cache-chart`

  Chart templates creating the necessary Kubernetes configuration used by `scripts/deploy_platform.sh`

- [fb-service-token-cache-deploy repo](https://github.com/ministryofjustice/fb-service-token-cache-deploy)

  Shared secrets and environment-specific values and secrets used to substitute values in in chart templates

  For each environment (`$PLATFORM_ENV-$DEPLOYMENT_ENV`), the helm chart in deploy is evaluated using values from the following files:

  - `secrets/shared-secrets-values.yaml`
  - `secrets/$PLATFORM_ENV-$DEPLOYMENT_ENV-secrets-values.yaml`

  As the deploy repo is encrypted using `git-crypt`, example files can be found in `deploy/fb-service-token-cache-chart/example`

## Further details

### 1. Creating images for the platform

`scripts/build_platform_images.sh` is a convenience wrapper around the application's `Makefile` which takes care of acquiring and setting the necessary ENV variables. It is equivalent to running

```bash
make $PLATFORM_ENV build_and_push
```

having set the following ENV variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

(These values are the base64-decrypted values of the corresponding secrets in the `formbuilder-repos` namespace, where

eg. `AWS_ACCESS_KEY_ID` is the `access_key_id` value and `AWS_SECRET_ACCESS_KEY` the `secret_access_key` value of the `ecr-repo-fb-service-token-cache` secret

This creates an image for the `fb-service-token-cache` tagged `latest:$PLATFORM_ENV`.

This image is then pushed to Cloud Platform's ECR.

See the `Makefile` for more info.

### 2. Provisioning namespaces/infrastructure

- Update [Cloud Platforms Environments](https://github.com/ministryofjustice/cloud-platform-environments/) config as necessary (NB. these files are generated via the Helm charts in [fb-cloud-platform-environments](https://github.com/ministryofjustice/cloud-platform-environments/))
- Submit a pull request to Cloud Platforms

### 3. Creating/updating the infrastructure

- Update [fb-service-token-cache-deploy](https://github.com/ministryofjustice/fb-service-token-cache-deploy)

  - `secrets/$PLATFORM_ENV-$DEPLOYMENT_ENV-secrets-values.yaml`
    - `KUBECTL_BEARER_TOKEN`
      Can be determined from the secret called `formbuilder-service-token-cache-$PLATFORM_ENV-$DEPLOYMENT_ENV-token-` created in the `formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV` namespace
    - `secret_key_base`
      Rails secret

- Run the `scripts/deploy_platform.sh` script which 

  - generates the necessary kubernetees configuration to deploy the application
  - applies the configuration

The generated config for each platform/deployment environment combination is written to `/tmp/fb-service-token-cache-$PLATFORM_ENV-$DEPLOYMENT_ENV.yaml`

### 4. Running the Rails setup scripts

The first time the infrastructure is created, the Rails setup scripts need to be run. This needs to be run on one of the pods that has been created 

```bash
kubectl exec -ti $PODNAME --namespace=formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV  -- bundle exec rails db:setup db:migrate
```

**TODO: Make rails setup run automatically without failure preventing further scripts running**

### 5. Deploying an updated docker image to existing infrastructure

Deleting the currently running pods will trigger the kubernetes Deployment to recreate pods until it has its specified minimum number running - as the Deployment has `imagePullPolicy: Always`, it will pull the latest docker image from Cloud Platform's ECR.

`scripts/restart_platform_pods.sh` is a convenience script that deletes all pods in all deployment environments accross a platform environment.

Running

```bash
scripts/restart_platform_pods.sh -p $PLATFORM_ENV
```

is equivalent to

```bash
kubectl delete pods -l appGroup=fb-service-token-cache --namespace=formbuilder-platform-$PLATFORM_ENV-dev &\
kubectl delete pods -l appGroup=fb-service-token-cache --namespace=formbuilder-platform-$PLATFORM_ENV-staging &\
kubectl delete pods -l appGroup=fb-service-token-cache --namespace=formbuilder-platform-$PLATFORM_ENV-production &
```
