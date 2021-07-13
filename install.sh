#!/bin/bash

kubeconfig=$KUBECONFIG
GOGS_IMAGE="gogs/gogs:0.12.1"
APP_DOMAIN="apps.izhang-hub-47-6np2g.dev10.red-chesterfield.com"

while getopts "k:hs?" opt; do
    case "${opt}" in
    k)
        kubeconfig="${OPTARG}"
        ;;
    s)
        echo "runing on scale-lab env"
        GOGS_IMAGE="f36-h21-000-r640.rdu2.scalelab.redhat.com:5000/gogs/gogs:0.12.1"
        APP_DOMAIN="apps.bm.rdu2.scalelab.redhat.com"
        ;;
    h | ? | *)
        echo
        echo "$(basename $0) will install gogs as a service on your cluster(defined in kubconfig}"
        echo "the gogs will be exposed as a route 'gogs-svc' at default namespace."
        echo
        echo "Please also run the inject-ca.sh to add the sefl-signed cert to your gogs route"
        echo "in order to make sure the ArgoCD can work properly"
        echo
        echo "The route TLS cert need to be put into ArgoCD Repository certificates"
        echo "You can copy the routes' cert from OCP console and paste it via the ArgoCD UI,"
        echo "<argocd_host>/settings/certs"
        echo
        echo "-k <kubeconfig path>, to specify your kubeconfig, default is KUBECONFIG"
        echo "-s, flag let the script knows your are running againt scale-lab env"
        exit 0
        ;;
    esac
done

echo "==== Deploying Gogs Git server with custom certificate ===="
cur_dir=$(pwd)
echo "Current directory is $cur_dir"

KUBECTL_CMD="oc --kubeconfig $kubeconfig --insecure-skip-tls-verify=true"

echo
echo "$(basename $0) runs at context: "
echo "$($KUBECTL_CMD config current-context)"
echo

OVERRIDE_GOGS="override-gogs.yaml"
INSTALL_NAMESPACE="default"

# Get the application domain
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

#DESC_POD=$($KUBECTL_CMD describe pod $GOGS_POD_NAME -n $INSTALL_NAMESPACE)
#echo "$DESC_POD"
#
#sleep 10

echo
echo "Adding testadmin user in Gogs"
# Run script in Gogs container to add Git admin user
$KUBECTL_CMD exec $GOGS_POD_NAME -n $INSTALL_NAMESPACE -- /tmp/adduser.sh
if [ $? -ne 0 ]; then
    echo "failed to add testadmin user"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo
echo "Route is installed: "
$KUBECTL_CMD get route gogs-svc -n $INSTALL_NAMESPACE
