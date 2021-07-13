#!/bin/bash

cur_dir=$(pwd)

cd ${cur_dir}

GIT_HOSTNAME="gogs-svc-default.apps.izhang-hub-47-6np2g.dev10.red-chesterfield.com"
REPO_NAME="ztp-ran-manifests"
TARGET_REPO="${cur_dir}/${REPO_NAME}"

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

git clone https://github.com/TheRealHaoLiu/ztp-ran-manifests.git

cd $TARGET_REPO

git remote rm origin-gogs

git remote add origin-gogs https://${GIT_HOSTNAME}/testadmin/${REPO_NAME}.git
git remote -v

git checkout scale-lab
git -c http.sslVerify=false push -u origin-gogs scale-lab:scale-lab

exit 0
