#!/bin/bash

cur_dir=$(pwd)

cd ${cur_dir}

GIT_HOSTNAME="gogs-svc-default.apps.izhang-hub-47-6np2g.dev10.red-chesterfield.com"
REPO_NAME="ztp-ran-manifests"
TARGET_REPO="${cur_dir}/${REPO_NAME}"
SRC_ZTP_REPO="https://github.com/TheRealHaoLiu/ztp-ran-manifests.git"
SRC_BRANCH="scale-lab"

while getopts "hs?" opt; do
    case "${opt}" in
    s)
        echo "runing on scale-lab env"
        GIT_HOSTNAME="gogs-svc-default.apps.bm.rdu2.scalelab.redhat.com"
        ;;
    h | ? | *)
        echo
        echo "$(basename $0) will push the $SRC_BRANCH branch of $SRC_ZTP_REPO to gogs "
        echo
        echo "-s, flag let the script knows your are running againt scale-lab env"
        exit 0
        ;;
    esac
done

# Create a test Git repository. This creates a repo named testrepo under user testadmin.
RESPONSE=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "ztp-ran-manifests", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)

echo "RESPONSE = ${RESPONSE}"

if [ ${RESPONSE} -eq 500 ] || [ ${RESPONSE} -eq 501 ] || [ ${RESPONSE} -eq 502 ] || [ ${RESPONSE} -eq 503 ] || [ ${RESPONSE} -eq 504 ]; then
    echo "Gog server error ${RESPONSE}"

    DESC_POD=$($KUBECTL_CMD describe pod $GOGS_POD_NAME)
    echo "$DESC_POD"

    $KUBECTL_CMD logs $GOGS_POD_NAME -n default
    echo

    sleep 60

    echo "trying to create testrepo again after 1 minute sleep"
    RESPONSE2=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "ztp-ran-manifests", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)
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

rm -rf $TARGET_REPO

git clone $SRC_ZTP_REPO

cd $TARGET_REPO

git remote rm origin-gogs

git remote add origin-gogs https://${GIT_HOSTNAME}/testadmin/${REPO_NAME}.git
git remote -v

git checkout $SRC_BRANCH
git -c http.sslVerify=false push -u origin-gogs $SRC_BRANCH:$SRC_BRANCH

git checkout -b master
git -c http.sslVerify=false push -u origin-gogs master:master
exit 0
