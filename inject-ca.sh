#!/bin/bash

kubeconfig=$KUBECONFIG
APP_DOMAIN="apps.izhang-hub-47-6np2g.dev10.red-chesterfield.com"

while getopts "k:hs?" opt; do
    case "${opt}" in
    k)
        kubeconfig="${OPTARG}"
        ;;
    s)
        echo "runing on scale-lab env"
        APP_DOMAIN="apps.bm.rdu2.scalelab.redhat.com"
        ;;
    h | ? | *)
        echo
        echo "$(basename $0) will recreate the gogs-svc route with the generated cret"
        echo "--cert=server.crt --key=server.key, these files are generate with configuration"
        echo "from ca.conf and san.ext"
        echo "-k <kubeconfig path>, to specify your kubeconfig, default is KUBECONFIG"
        echo "-s, flag will decide if we are running againt basion env or your local env"
        exit 0
        ;;
    esac
done

KUBECTL_CMD="oc --kubeconfig $kubeconfig --insecure-skip-tls-verify=true"
INSTALL_NAMESPACE="default"

echo
echo "$(basename $0) runs at context: "
echo "$($KUBECTL_CMD config current-context)"

GIT_HOSTNAME="gogs-svc-default.${APP_DOMAIN}"
COMMON_NAME="*.${APP_DOMAIN}"

# Inject the real Git hostname into certificate config files
sed -e "s|__HOSTNAME__|$GIT_HOSTNAME|" ca.conf | sed -e "s|COMMON_NAME|${COMMON_NAME}|" > ca-override.conf
sed -e "s|__HOSTNAME__|$GIT_HOSTNAME|" san.ext > san-override.ext

# Generate certificates
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt -config ca-override.conf
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -config ca-override.conf
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile san-override.ext
if [ $? -ne 0 ]; then
    echo "failed to create a self-signed certificate"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Recreate Gogs route with the generated self-signed certificates
$KUBECTL_CMD delete route gogs-svc -n $INSTALL_NAMESPACE
if [ $? -ne 0 ]; then
    echo "failed to delete Gogs route"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD create route edge --service=gogs-svc --cert=server.crt --key=server.key --path=/ -n $INSTALL_NAMESPACE
if [ $? -ne 0 ]; then
    echo "failed to create Gogs route with the self-signed certificate"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo
echo "Route is installed: "
$KUBECTL_CMD get route gogs-svc -n $INSTALL_NAMESPACE
