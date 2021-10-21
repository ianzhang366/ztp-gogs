# apply config files


GIT_HOST=${GIT_HOST:-[fc00:1001::1]}
GIT_PORT=${GIT_PORT:-10880}
GIT_PORT_IPV4=${GIT_PORT_IPV4:-10881}

IP_NETWORK_PODMAN=${IP_NETWORK_PODMAN:-podman6}

DEFULAT_GOGS_USERNAME=${DEFULAT_GOGS_USERNAME:-testadmin}
DEFULAT_GOGS_PASSWORD=${DEFULAT_GOGS_PASSWORD:-testadmin}

if [ ! -f /var/gogs/gogs/conf/app.ini  ]; then
    mkdir -p /var/gogs/gogs/conf/
    secret_key_generated=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    sed -e s/PLACE_HOLDER_SECRET_KEY/"$secret_key_generated"/g app.ini > /var/gogs/gogs/conf/app.ini
fi 

if [ ! -f /etc/cni/net.d/88-podman6-bridge.conflist ]; then
    cp 88-podman6-bridge.conflist /etc/cni/net.d/
fi


if ! grep "gogs-ipv6" /etc/haproxy/haproxy.cfg ; then
echo "adding gogs"
cat<<EOF >> /etc/haproxy/haproxy.cfg
frontend gogs-ipv4-${GIT_PORT_IPV4}
    bind :::${GIT_PORT_IPV4} v4v6
    mode tcp
    default_backend gogs-ipv6-${GIT_PORT}

backend gogs-ipv6-${GIT_PORT}
    mode tcp
    balance source
    server ingress ${GIT_HOST}:${GIT_PORT} check inter 1s
EOF

echo "restart haproxy"
systemctl restart haproxy

fi

# create gogs server
podman run -d --name=gogs --network=${IP_NETWORK_PODMAN} -p 10022:22 -p ${GIT_PORT}:3000 -v /var/gogs:/data gogs/gogs


# create fist user
podman exec gogs su git -c "/app/gogs/gogs admin create-user --name ${DEFULAT_GOGS_USERNAME} --password ${DEFULAT_GOGS_PASSWORD} --email ${DEFULAT_GOGS_USERNAME}@redhat.com --admin"
