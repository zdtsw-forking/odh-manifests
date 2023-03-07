#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util
RESOURCEDIR="${MY_DIR}/../resources"

MODEL_PROJECT="${ODHPROJECT}-model"
PREDICTOR_NAME="example-onnx-mnist"


os::test::junit::declare_suite_start "$MY_SCRIPT"

function check_resources() {
    header "Testing modelmesh controller installation"
    os::cmd::expect_success "oc project ${ODHPROJECT}"
    os::cmd::try_until_text "oc get deployment modelmesh-controller" "modelmesh-controller" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -l control-plane=modelmesh-controller --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "3" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get service modelmesh-serving" "modelmesh-serving" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get deployment etcd" "etcd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -l component=model-mesh-etcd -o jsonpath='{$.items[*].metadata.name}' | wc -w" "1" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get secret model-serving-etcd" "model-serving-etcd" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get secret etcd-passwords" "etcd-passwords" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pod prometheus-odh-model-monitoring-0" "prometheus-odh-model-monitoring-0" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pod prometheus-odh-model-monitoring-1" "prometheus-odh-model-monitoring-1" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pod prometheus-odh-model-monitoring-2" "prometheus-odh-model-monitoring-2" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get service odh-model-monitoring" "odh-model-monitoring" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get route odh-model-monitoring" "odh-model-monitoring" $odhdefaulttimeout $odhdefaultinterval
}

function setup_test_serving_namespace_ovms() {
    oc new-project ${MODEL_PROJECT}
    oc label namespace ${MODEL_PROJECT} "modelmesh-enabled=true" --overwrite=true || echo "Failed to apply modelmesh-enabled label."
    header "Setting up test modelmesh serving in ${MODEL_PROJECT}"
    SECRETKEY=$(openssl rand -hex 32)
    sed -i "s/<secretkey>/$SECRETKEY/g" ${RESOURCEDIR}/modelmesh/sample-minio.yaml
    os::cmd::expect_success "oc apply -f ${RESOURCEDIR}/modelmesh/sample-minio.yaml -n ${MODEL_PROJECT}"
    os::cmd::expect_success "oc apply -f ${RESOURCEDIR}/modelmesh/service_account.yaml -n ${MODEL_PROJECT}"
    os::cmd::try_until_text "oc get pods -n ${MODEL_PROJECT} -l app=minio --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "1" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::expect_success "oc apply -f ${RESOURCEDIR}/modelmesh/openvino-serving-runtime.yaml -n ${MODEL_PROJECT}"
    os::cmd::expect_success "oc apply -f ${RESOURCEDIR}/modelmesh/openvino-inference-service.yaml -n ${MODEL_PROJECT}"
    os::cmd::try_until_text "oc get pods -n ${ODHPROJECT} -l app=odh-model-controller --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "3" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -n ${MODEL_PROJECT} -l name=modelmesh-serving-ovms-1.x --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "2" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get inferenceservice -n ${MODEL_PROJECT} example-onnx-mnist -o jsonpath='{$.status.modelStatus.states.activeModelState}'" "Loaded" $odhdefaulttimeout $odhdefaultinterval
    oc project ${ODHPROJECT}
}


function teardown_test_serving() {
    header "Tearing down test modelmesh serving"
    oc project ${MODEL_PROJECT}
    os::cmd::expect_success "oc delete -f ${RESOURCEDIR}/modelmesh/sample-minio.yaml"
    os::cmd::try_until_text "oc get pods -l app=minio --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "0" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::expect_success "oc delete -f ${RESOURCEDIR}/modelmesh/openvino-inference-service.yaml"
    os::cmd::expect_success "oc delete -f ${RESOURCEDIR}/modelmesh/openvino-serving-runtime.yaml"
    os::cmd::try_until_text "oc get pods -l name=modelmesh-serving-ovms-1.x --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "0" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::expect_success "oc delete project ${MODEL_PROJECT}"
}

function test_inferences() {
    header "Testing inference from example mnist model"
    oc project ${MODEL_PROJECT}
    route=$(oc get route ${PREDICTOR_NAME} --template={{.spec.host}}{{.spec.path}})
    token=$(oc create token user-one -n ${MODEL_PROJECT})
    os::cmd::expect_success "curl -k https://$route/infer -d @{RESOURCEDIR}/modelmesh/ovms-input.json -H 'Authorization: Bearer $token' -i"  
    oc project ${ODHPROJECT}
}

function setup_monitoring() {
    header "Enabling User Workload Monitoring on the cluster"
    oc apply -f ${RESOURCEDIR}/modelmesh/enable-uwm.yaml
}

function test_metrics() {
    header "Checking metrics for total models loaded, should be 1 since we have 1 models being served"
    openshift_monitoring_token=$(oc create token prometheus-k8s -n openshift-monitoring)
    os::cmd::try_until_text "oc -n openshift-monitoring exec -c prometheus prometheus-k8s-0 -- curl -k -H \"Authorization: Bearer $openshift_monitoring_token\" 'https://thanos-querier.openshift-monitoring.svc:9091/api/v1/query?query=modelmesh_models_loaded_total' | jq '.data.result[0].value[1]'" "1" $odhdefaulttimeout $odhdefaultinterval
    
    model_monitoring_route=$(oc get route -n ${ODHPROJECT} odh-model-monitoring --template={{.spec.host}})
    model_monitoring_token=$(oc create token prometheus-custom -n ${ODHPROJECT})
    os::cmd::try_until_text "curl -k --location -g --request GET 'https://$model_monitoring_route//api/v1/query?query=sum(haproxy_backend_http_responses_total{exported_namespace=${MODEL_PROJECT},route=${PREDICTOR_NAME}})' -H 'Authorization: Bearer $model_monitoring_token' | jq '.data.result[0].value[1]'" "1" $odhdefaulttimeout $odhdefaultinterval 
}

setup_monitoring
check_resources
setup_test_serving_namespace_ovms
test_inferences
test_metrics
teardown_test_serving


os::test::junit::declare_suite_end
