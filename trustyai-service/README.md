# TrustyAI Service

TrustyAI is a service to provide fairness metrics to ModelMesh served models.


### Installation process

Following are the steps to install Model Mesh as a part of OpenDataHub install:

1. Install the OpenDataHub operator
2. Create a KfDef that includes the model-mesh component with the odh-model-controller overlay.
3. Set the `payloadProcessor` value within `model-serving-config-defaults` ConfigMap
to `http://trustyai-service/consumer/kserve/v2`
4. Create a TrustyAI KfDef:
```
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  name: odh-trustyai
spec:
  applications:
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: odh-common
      name: odh-common
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: trustyai-service
      name: trustyai
  repos:
    - name: manifests
      uri: https://api.github.com/repos/opendatahub-io/odh-manifests/tarball/master
  version: master

```

