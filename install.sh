#!/bin/bash

echo "==== Deploying Gogs Git server with custom certificate ===="

cur_dir=$(pwd)
echo "Current directory is $cur_dir"

kubeconfig=$HUB_CONFIG

KUBECTL_CMD="oc --kubeconfig $kubeconfig --insecure-skip-tls-verify=true"

GOGS_IMAGE="gogs/gogs:0.12.1"
OVERRIDE_GOGS="override-gogs.yaml"
INSTALL_NAMESPACE="default"

# Get the application domain
APP_DOMAIN=$($KUBECTL_CMD -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')
if [ $? -ne 0 ]; then
    echo "failed to get the application domain"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "Application domain is $APP_DOMAIN"

GIT_HOSTNAME=gogs-svc-default.$APP_DOMAIN
echo "Git hostname is $GIT_HOSTNAME"

# Inject the real Git hostname into the Gogs deployment YAML
sed -e "s|__HOSTNAME__|$GIT_HOSTNAME|" gogs.yaml | sed -e "s|GOGS_IMAGE|${GOGS_IMAGE}|" | sed -e "s|INSTALL_NAMESPACE|${INSTALL_NAMESPACE}|" > $OVERRIDE_GOGS

if [ $? -ne 0 ]; then
    echo "failed to substitue strings in gogs.yaml"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD create ns $INSTALL_NAMESPACE

echo "Switching to $INSTALL_NAMESPACE namespace"
$KUBECTL_CMD project $INSTALL_NAMESPACE

# want to run the gogs container as root
$KUBECTL_CMD adm policy add-scc-to-user anyuid -z $INSTALL_NAMESPACE
if [ $? -ne 0 ]; then
    echo "failed to update security policy"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Deploy Gogs Git server
$KUBECTL_CMD apply -f $OVERRIDE_GOGS
if [ $? -ne 0 ]; then
    echo "failed to deploy Gogs server"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

sleep 5

# Get Gogs pod name
GOGS_POD_NAME=$($KUBECTL_CMD get pods -n $INSTALL_NAMESPACE -o=custom-columns='DATA:metadata.name' | grep gogs-)
if [ $? -ne 0 ]; then
    echo "failed to get the pod name"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "Gogs pod name is $GOGS_POD_NAME"

# Wait for Gogs to be running
FOUND=1
MINUTE=0
running="\([0-9]\+\)\/\1"
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for Gogs pod ${GOGS_POD_NAME}."
        echo "List of current pods:"
        $KUBECTL_CMD -n $INSTALL_NAMESPACE get pods
        echo
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    pod=$($KUBECTL_CMD -n $INSTALL_NAMESPACE get pod $GOGS_POD_NAME)

    if [[ $(echo $pod | grep "${running}") ]]; then
        echo "${GOGS_POD_NAME} is running"
        break
    fi
    sleep 3
    ((MINUTE = MINUTE + 3))
done

OC_VERSION=$($KUBECTL_CMD version)
echo "$OC_VERSION"

echo "$pod"

DESC_POD=$($KUBECTL_CMD describe pod $GOGS_POD_NAME -n $INSTALL_NAMESPACE)
echo "$DESC_POD"

sleep 10

echo "Adding testadmin user in Gogs"
# Run script in Gogs container to add Git admin user
$KUBECTL_CMD exec $GOGS_POD_NAME -n $INSTALL_NAMESPACE -- /tmp/adduser.sh
if [ $? -ne 0 ]; then
    echo "failed to add testadmin user"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD get route gogs-svc -n $INSTALL_NAMESPACE -o yaml

# Populate the repo with test data

GIT_HOSTNAME="gogs-svc-default.apps.izhang-hub-47-6np2g.dev10.red-chesterfield.com"
curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "ztp-ran-manifests", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure

# Create a test Git repository. This creates a repo named testrepo under user testadmin.
RESPONSE=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": $REPO_NAME, "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)
if [ $? -ne 0 ]; then
    echo "failed to create testrepo"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "RESPONSE = ${RESPONSE}"

if [ ${RESPONSE} -eq 500 ] || [ ${RESPONSE} -eq 501 ] || [ ${RESPONSE} -eq 502 ] || [ ${RESPONSE} -eq 503 ] || [ ${RESPONSE} -eq 504 ]; then
    echo "Gog server error ${RESPONSE}"

    DESC_POD=$($KUBECTL_CMD describe pod $GOGS_POD_NAME)
    echo "$DESC_POD"

    $KUBECTL_CMD logs $GOGS_POD_NAME -n default
    echo

    sleep 60

    echo "trying to create testrepo again after 1 minute sleep"
    RESPONSE2=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "testrepo", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)
    if [ $? -ne 0 ]; then
        echo "failed to create testrepo"
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    if [ ${RESPONSE2} -eq 500 ] || [ ${RESPONSE2} -eq 501 ] || [ ${RESPONSE2} -eq 502 ] || [ ${RESPONSE2} -eq 503 ] || [ ${RESPONSE2} -eq 504 ]; then
        echo "failed to create testrepo again"

        DESC_POD=$($KUBECTL_CMD describe pod $GOGS_POD_NAME)
        echo "$DESC_POD"

        $KUBECTL_CMD logs $GOGS_POD_NAME -n default
        echo

        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi
fi

REPO_NAME="ztp-ran-manifests"
TARGET_REPO="${cur_dir}/${REPO_NAME}"
cd ${cur_dir}

git clone https://github.com/TheRealHaoLiu/ztp-ran-manifests.git

cd $TARGET_REPO

git remote add origin-gogs https://${GIT_HOSTNAME}/testadmin/${REPO_NAME}.git
git remote -v

git checkout main
git push -u origin-gogs main

exit 0
