GIT_HOST=${GIT_HOST:-[fc00:1001::1]}
GIT_PORT=${GIT_PORT:-10880}
DEFULAT_GOGS_USERNAME=${DEFULAT_GOGS_USERNAME:-testadmin}
DEFULAT_GOGS_PASSWORD=${DEFULAT_GOGS_PASSWORD:-testadmin}

echo "host: $GIT_HOST:$GIT_PORT"
while read -r REPO_NAME REPO_URL; do
    RESPONSE=$(curl -v -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "'${REPO_NAME}'", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null http://${GIT_HOST}:${GIT_PORT}/api/v1/admin/users/testadmin/repos )
    if [ ${RESPONSE} -eq 500 ] || [ ${RESPONSE} -eq 501 ] || [ ${RESPONSE} -eq 502 ] || [ ${RESPONSE} -eq 503 ] || [ ${RESPONSE} -eq 504 ]; then
        echo "Gog server error ${RESPONSE}"
    else
        echo "succeed: $RESPONSE"
        rm -rf $REPO_NAME
        git clone $REPO_URL
        pushd $REPO_NAME
        git remote rm origin-gogs
        git remote add origin-gogs http://${DEFULAT_GOGS_USERNAME}:${DEFULAT_GOGS_PASSWORD}@${GIT_HOST}:${GIT_PORT}/testadmin/${REPO_NAME}.git
        git remote -v
        git push -u origin-gogs  --all
        popd
    fi
done < repo.txt

