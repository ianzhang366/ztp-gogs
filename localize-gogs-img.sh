#!/bin/bash

SOURCE_GOGS_IMAGE="gogs/gogs:0.12.1"
GOGS_IMAGE="f36-h21-000-r640.rdu2.scalelab.redhat.com:5000/gogs/gogs:0.12.1"
podman pull $SOURCE_GOGS_IMAGE
podman tag $SOURCE_GOGS_IMAGE $GOGS_IMAGE
podman push $GOGS_IMAGE
exit 0
