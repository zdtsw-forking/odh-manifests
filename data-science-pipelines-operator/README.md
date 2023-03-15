# Data Science Pipelines Operator

The Data Science Pipelines Operator (DSPO) is an OpenShift Operator that is used to deploy single namespace scoped 
Data Science Pipeline stacks onto individual OCP namespaces.

# Table of Contents

1. [Quickstart](#quickstart)
   1. [Pre-requisites](#pre-requisites)
   2. [Deploy the Operator via ODH](#deploy-the-operator-via-odh)
4. [Cleanup ODH Installation](#cleanup-odh-installation)

# Quickstart

To get started you will first need to satisfy the following pre-requisites:

## Pre-requisites
1. An OpenShift cluster that is 4.9 or higher.
2. You will need to be logged into this cluster as [cluster admin] via [oc client].
3. The OpenShift Cluster must have OpenShift Pipelines 1.7.2 or higher installed. Instructions [here][OCP Pipelines Operator].
4. The Open Data Hub operator needs to be installed. You can install it via [OperatorHub][installodh].

## Deploy the Operator via ODH

On a cluster with ODH installed, create a namespace where you would like to install DSPO: 

```bash
DSPO_NS=odh-applications
oc new-project ${DSPO_NS}
```

Then deploy the following `KfDef` into the namespace created above:

```bash
cat <<EOF | oc apply -f -
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
   name: data-science-pipelines-operator
   namespace: ${DSPO_NS}
spec:
   applications:
      - kustomizeConfig:
           repoRef:
              name: manifests
              path: data-science-pipelines-operator/
        name: data-science-pipelines-operator
   repos:
      - name: manifests
        uri: "https://github.com/opendatahub-io/odh-manifests/tarball/master"
EOF
```

Confirm the pods are successfully deployed and reach running state:

```bash
oc get pods -n ${DSPO_NS}
```

## Deploy DSP Instance 

Once all pods are ready, we can deploy an ODH Data Science Pipelines stack by deploying a `DSPA` custom resource.

First let's create a namespace where we want to deploy Data Science Pipelines: 

```bash
DSPA_NS=data-science-project
oc new-project ${DSPA_NS}
```

Then deploy a DSPA instance in this namespace:

```bash
cat <<EOF | oc apply -f -
apiVersion: datasciencepipelinesapplications.opendatahub.io/v1alpha1
kind: DataSciencePipelinesApplication
metadata:
  name: sample
  namespace: ${DSPA_NS}
spec:
  objectStorage:
    minio:
      image: 'quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance'
  mlpipelineUI:
    image: 'quay.io/opendatahub/odh-ml-pipelines-frontend-container:beta-ui'
EOF
```

For more detailed instructions on how to interact with this stack, see the docs [here][dspo-repo].

## Cleanup ODH Installation

To uninstall DSPO via ODH run the following:

```bash
KFDEF_NAME=data-science-pipelines-operator
oc delete kfdef ${KFDEF_NAME} -n ${DSPO_NS}
```

[cluster admin]: https://docs.openshift.com/container-platform/4.12/authentication/using-rbac.html#creating-cluster-admin_using-rbac
[oc client]: https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz
[OCP Pipelines Operator]: https://docs.openshift.com/container-platform/4.12/cicd/pipelines/installing-pipelines.html#op-installing-pipelines-operator-in-web-console_installing-pipelines
[installodh]: https://opendatahub.io/docs/getting-started/quick-installation.html
[dspo-repo]: https://github.com/opendatahub-io/data-science-pipelines-operator#using-a-datasciencepipelinesapplication
