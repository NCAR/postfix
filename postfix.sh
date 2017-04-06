#!/bin/bash
PROG="postfix.sh"
DESC="Start, stop, status, or reload postfix container"
USAGE="$PROG start|status|stop|reload|flush"

MAILNET="${MAILNET:-mail}"
MTA_CONTAINER="${MTA_CONTAINER:-mail}"
MTA_IMAGE="${MTA_IMAGE:=cisl-repo/$MTA_CONTAINER:$TAG_postfix}"

NOTES="
    This is meant to be called by systemd or a similar management system to
    control the Dockerized Postfix Mail Transfer Agent (MTA) service.

    The Postfix service uses the \"$MAILNET\" network and has the name
    \"$MTA_CONTAINER\".

    To control the service, run \"$PROG <cmd>\":

        $PROG start     -> Start the master daemon
        $PROG status    -> Retrieve the status of the service
        $PROG stop      -> Stop the service
        $PROG reload    -> Tell the service to reload the configuration
        $PROG flush     -> Force delivery of buffered mail
        $PROG help      -> Display this help text

"
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENVVARS="MAILNET MTA_CONTAINER MTA_IMAGE TAG_postfix VOLMAP_DATA"

if [[ -r $SCRIPTDIR/.env ]] ; then
    . $SCRIPTDIR/.env
elif [[ -r $SCRIPTDIR/env ]] ; then
    . $SCRIPTDIR/env
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
        -h|--help) help ;;
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
               --network ${MAILNET} \
               --volume $VOLMAP_DATA:/var/postfix \
           ${MTA_IMAGE} /bin/run-postfix.sh
}

function status() {
    docker exec ${MTA_CONTAINER} postfix status
}

function stop() {
    docker exec ${MTA_CONTAINER} postfix stop
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

function help() {
    cat <<EOF
NAME
    $PROG - 

SYNOPSIS
    $USAGE

DESCRIPTION
$NOTES
EOF
    exit 0
}

main "$@"
