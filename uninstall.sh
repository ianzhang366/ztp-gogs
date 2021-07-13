#!/bin/bash

cur_dir=$(pwd)
echo "Current directory is $cur_dir"

kubeconfig="/root/bm/kubeconfig"
kubeconfig=$HUB_CONFIG

KUBECTL_CMD="kubectl --kubeconfig $kubeconfig"

# Uninstall Gogs Git server
# Inject the real Git hostname into the Gogs deployment YAML
OVERRIDE_GOGS="override-gogs.yaml"
INSTALL_NAMESPACE="default"

sed -e "s|INSTALL_NAMESPACE|${INSTALL_NAMESPACE}|" gogs.yaml > $OVERRIDE_GOGS
$KUBECTL_CMD delete -f $OVERRIDE_GOGS

if [ "$INSTALL_NAMESPACE" != "default" ]; then
    $KUBECTL_CMD delete ns $INSTALL_NAMESPACE
fi

echo "E2E CANARY TEST - DONE"
exit 0
