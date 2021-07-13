#!/bin/bash

cur_dir=$(pwd)
echo "Current directory is $cur_dir"

kubeconfig=$KUBECONFIG

while getopts "k:hs?" opt; do
    case "${opt}" in
    k)
        kubeconfig="${OPTARG}"
        ;;
    h | ? | *)
        echo "$(basename $0) nothing to show"
        exit 0
        ;;
    esac
done

KUBECTL_CMD="kubectl --kubeconfig $kubeconfig"

echo
echo "$(basename $0) runs at context: "
echo "$($KUBECTL_CMD config current-context)"
echo

# Uninstall Gogs Git server
# Inject the real Git hostname into the Gogs deployment YAML
OVERRIDE_GOGS="override-gogs.yaml"
INSTALL_NAMESPACE="default"

sed -e "s|INSTALL_NAMESPACE|${INSTALL_NAMESPACE}|" gogs.yaml > $OVERRIDE_GOGS
$KUBECTL_CMD delete -f $OVERRIDE_GOGS

if [ "$INSTALL_NAMESPACE" != "default" ]; then
    $KUBECTL_CMD delete ns $INSTALL_NAMESPACE
fi

exit 0
