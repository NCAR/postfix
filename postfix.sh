#!/bin/bash
PROG="postfix.sh"
DESC="Start, stop, status, or reload postfix container"
USAGE="$PROG [-e|--env tag] start|status|stop|reload|flush"

MAILNET="${MAILNET:-mail}"
MTA_CONTAINER="${MTA_CONTAINER:-mail}"
MTA_IMAGE="${MTA_IMAGE:=cisl-repo/postfix}"

function help() {
    cat <<EOF
NAME
    $PROG - 

SYNOPSIS
    $USAGE

DESCRIPTION
    This script controls the Dockerized Postfix Mail Transfer Agent (MTA)
    service. It is meant to be called by systemd or a similar management
    system.

    The Postfix service uses the "$MAILNET" network and has the name
    "$MTA_CONTAINER".

    To control the service, run "$PROG <cmd>":

        $PROG start     -> Start the master daemon
        $PROG status    -> Retrieve the status of the service
        $PROG stop      -> Stop the service
        $PROG reload    -> Tell the service to reload the configuration
        $PROG flush     -> Force delivery of buffered mail
        $PROG help      -> Display this help text

    There is only one option:

    -e|--env tag
        The script normally looks in the script directory for deployment
        environment and start environment files ("deploy.env" and "start.env"
        respectively) If this option is given with argument <tag>, the script
        will look for files "<tag>/deploy.env" and "<tag>/start.env"
        instead.

FILES
    start.env
        Environment variable definitions used when starting the container.
        See ENVIRONMENT VARIABLES

    deploy.env
        Deployment-specific environment variable definitions used in the
        running container. See ENVIRONMENT VARIABLES

ENVIRONMENT VARIABLES
    MAILNET
        The name of the docker network for the postfix service (default=mail).
        Note that any containers that want to use this container as a mail
        relay must attach to the same network. This should be set in the
        "start.env" file.

    MTA_CONTAINER
        The name of the postfix container (default=mail). Note that any
        containers that want to use this container as a mail relay should
        send mail to this "host". This should be set in the
        "start.env" file.

    TAG_postfix
        The version tag of the specific image to run (default=latest). This
        should be set in the "start.env" file.

    MTA_IMAGE
        The name of the postfix image to run (default=cisl-repo/postfix). This
        should be set in the "start.env" file.

    VOLMAP_DATA
        The name or host path to assign to the "/var/postfix" volume. This
        should be set in the "start.env" file.

    MAIL_FROM_FQDN
        The name that will be used as the host name in email "From" headers.
        This must be defined in the "deploy.env" file so that the
        running container sees it.
EOF
    exit 0
}

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TAG=
case $1 in
    -e?*)      TAG="${arg#-e}"
               shift ;;
    -e|--env)  TAG="$2"
               shift ; shift ;;
    -h|--help) help ;;
esac
if [[ -z "$TAG" ]] ; then
    START_ENV=$SCRIPTDIR/start.env
    DEPLOY_ENV=$SCRIPTDIR/deploy.env
else
    START_ENV=$SCRIPTDIR/$TAG/start.env
    DEPLOY_ENV=$SCRIPTDIR/$TAG/deploy.env
fi
if [[ -r $START_ENV ]] ; then
    . $START_ENV
elif [[ -f $START_ENV ]] ; then
    echo "$PROG: unable to read $START_ENV" >&2
    exit 1
fi
if [[ ! -f $DEPLOY_ENV ]] ; then
    echo "$PROG: $DEPLOY_ENV: no such file" >&2
    exit 1
fi


TAG_postfix="${TAG_postfix:-latest}"
VOLMAP_DATA="${VOLMAP_DATA:data}"

function main() {
    case $1 in 
	start)     start ;;
	status)    status ;;
	stop)      stop ;;
	reload)    reload ;;
        flush)     flush ;;
        *)         echo "$PROG: unknown command" >&2
	           echo "Usage:" >&2
		   echo "    $USAGE" >&2
		   exit 1
    esac
}

function start() {
    ensureNetworkExists

    docker rm ${MTA_CONTAINER} >/dev/null 2>&1

    docker run --env-file $SCRIPTDIR/deploy.env \
               --name ${MTA_CONTAINER} \
               --volume $VOLMAP_DATA:/var/postfix \
               --network ${MAILNET} \
           ${MTA_IMAGE:$TAG_postfix} /bin/run-postfix.sh

}

function status() {
    docker exec ${MTA_CONTAINER} postfix status
}

function stop() {
    docker exec ${MTA_CONTAINER} postfix stop
    exit 0
}

function reload() {
    docker exec ${MTA_CONTAINER} postfix reload
}

function flush() {
    docker exec ${MTA_CONTAINER} postfix flush
}

function ensureNetworkExists() {
    result=$(docker network create --driver=bridge $MAILNET 2>&1)
    rc=$?
    if [[ $rc == 0 ]] ; then
        echo "Created network \"$MAILNET\":"
        echo "$result"
    elif [[ "$result" != *network\ with\ name\ $MAILNET\ already\ exists ]] ; then
        echo "$result" >&2
        exit $rc
    fi
}

main "$@"
