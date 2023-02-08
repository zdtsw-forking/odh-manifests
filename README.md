# Open Data Hub Manifests
A repository for [Open Data Hub](https://opendatahub.io) components Kustomize manifests.

## Community

* Website: https://opendatahub.io
* Documentation: https://opendatahub.io/docs.html
* Mailing lists: https://opendatahub.io/community.html
* Community meetings: https://gitlab.com/opendatahub/opendatahub-community

## ODH Core Components

Open Data Hub is an end-to-end AI/ML platform on top of OpenShift Container Platform that provides a core set of integrated components to support end end-to-end MLOps workflow for Data Scientists and Engineers. The components currently available as part of the ODH Core deployment are:

* [ODH Dashboard](odh-dashboard/README.md)
* [ODH Notebook Controller](odh-notebook-controller/README.md)
* [Data Science Pipelines](data-science-pipelines/README.md)
* [ModelMesh](model-mesh/README.md)


Previous versions of ODH relied on [JupyterHub](jupyterhub/README.md) for managing the lifecycle of [Jupyter](https://jupyter.org) notebook pods. Starting with Open Data Hub v1.4, we will be relying on [ODH Notebook Controller](odh-notebook-controller/README.md) for controlling the lifecycle of user Juptyer notebook pods with [ODH Dashboard](odh-dashboard/README.md) as the frontend UI.  When ODH v1.5 is released, we will be moving [jupyterhub-odh](https://github.com/opendatahub-io/jupyterhub-odh) to our [ODH Contrib](https://github.com/opendatahub-io-contrib) organization and officially ending long term support.

Any components that were removed with the update to ODH 1.4 have been relocated to the [ODH Contrib](https://github.com/opendatahub-io-contrib) organization under the [odh-contrib-manifests](https://github.com/opendatahub-io-contrib/odh-contrib-manifests) repo.  You can reference the [odh-contrib kfdef](kfdef/odh-contrib.yaml) as a reference on how to deploy any of the odh-contrib-manifests components

### Component Versions

| Manifest Version | ODH Dashboard | ODH Notebook Controller | ODH Notebook Images | Data Science Pipelines | ModelMesh |
| ---------------- | ------------- | ----------------------- | ------------------- |----------------------- | --------- |
| master | v2.5.2 | v1.6 | v1.3.1 | v1.2.1 | v0.9.0 |
| v1.4.1 | v2.5.2 | v1.6 | v1.3.1 | v1.2.1 | v0.9.0 |
| v1.4.0 | v2.2.1 | v1.6 | N/A | v1.2.1 | v0.9.0 |

## Deploy

We are relying on [Kustomize v3](https://github.com/kubernetes-sigs/kustomize), [kfctl](https://github.com/kubeflow/kfctl) and [Open Data Hub Operator](https://github.com/opendatahub-io/opendatahub-operator/blob/master/operator.md) for deployment.

The two ways to deploy are:

1. Following [Getting Started](http://opendatahub.io/docs/getting-started/quick-installation.html) guide using a KFDef from this repository as the custom resource.
1. Using `kfctl` and follow the documentation at [Kubeflow.org](https://www.kubeflow.org/docs/openshift/). The only change is to use this repository instead of Kubeflow manifests.

## Issues
To submit issues please file a GitHub issue in [odh-manifests](https://github.com/opendatahub-io/odh-manifests/issues)
