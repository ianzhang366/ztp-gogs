# Gogs with podman

Setup gogs with podman, and use ipv6 as default.

## Set Env vars
All optional:
```
# the server host's ip address, as it's an ipv6 ip address, requires []
GIT_HOST=${GIT_HOST:-[fc00:1001::1]}
# the port of ipv6 (podman will use)
GIT_PORT=${GIT_PORT:-10880}
# the port of ipv4 (haproxy will use)
GIT_PORT_IPV4=${GIT_PORT_IPV4:-10881}

DEFULAT_GOGS_USERNAME=${DEFULAT_GOGS_USERNAME:-testadmin}
DEFULAT_GOGS_PASSWORD=${DEFULAT_GOGS_PASSWORD:-testadmin}
```

## Start gogs

```
./init.sh
```

This command will have podman to expose 10880 as an ipv6 port, and also will use haproxy to expose ipv4 ports (require haproxy to be installed).

## Sync repos
Update repo.txt with this format: `repo-name repo-url`
Run the following command:
```
./pull-repo.sh
```
