#!/bin/bash
PROG=run-postfix.sh
DESC="Modify Postfix configuration and start Postfix master daemon"
if [[ ":$1" == ":-h" || ":$1" == ":--help" ]] ; then
    cat >&2 <<EOF
$PROG - $DESC

This is meant to be used as a "Docker run" command. See postfix.sh also.
EOF
    exit 0
fi
POSTFIX_CFDIR=/etc/postfix
POSTFIX_MAIN_CONF=$POSTFIX_CFDIR/main.cf
QUEUE_DIR=/var/postfix/spool
DATA_DIR=/var/postfix/run
MAIL_DIR=/var/postfix/mail

if [[ -z "$MAIL_FROM_FQDN" ]] ; then
    echo "$PROG: environment variable MAIL_FROM_FQDN is not set" >&2
    exit 1
fi

function main() {
    configurePostfix
    ensureDirectoriesExist
    startPostfix
    waitForPostfix
}

function configurePostfix() {
    tmp="$POSTFIX_MAIN_CONF.tmp"
    writeNewMainCF "$tmp"
    appendNewMainConfigs "$tmp"
    cat $tmp >$POSTFIX_MAIN_CONF
    addNewConfigFiles
}

function writeNewMainCF() {
    tmp="$1"
    while IFS= read -r line ; do
	emitLine "$line"
    done <$POSTFIX_MAIN_CONF >$tmp
    cat $tmp >$POSTFIX_MAIN_CONF
}

function appendNewMainConfigs() {
    tmp="$1"
    cat <<EOF >>$tmp
sender_canonical_classes = envelope_sender, header_sender
sender_canonical_maps =  regexp:$POSTFIX_CFDIR/sender_canonical_maps
smtp_header_checks = regexp:$POSTFIX_CFDIR/header_check
EOF
}

function emitLine() {
    line="$1"
    if [[ $line =~ ^#myhostname.*=.*host.domain.tld ]] ; then
	echo "myhostname = $MAIL_FROM_FQDN"
    elif [[ $line =~ ^#myorigin.*=.*$myhostname ]] ; then
	echo "myorigin = $MAIL_FROM_FQDN"
    elif [[ $line =~ ^inet_interfaces[[:space:]]*=[[:space:]]*.* ]] ; then
	echo "$line, $HOSTNAME"
    elif [[ $line =~ ^queue_directory[[:space:]]*= ]] ; then
	echo "queue_directory = $QUEUE_DIR"
    elif [[ $line =~ ^data_directory[[:space:]]*= ]] ; then
	echo "data_directory = $DATA_DIR"
    elif [[ $line =~ ^#mail_spool_directory[[:space:]]*=[[:space:]]*/var/mail ]] ; then
	echo "mail_spool_directory = $MAIL_DIR"
    else
	echo "$line"
    fi
}

function addNewConfigFiles() {
    cat >$POSTFIX_CFDIR/sender_canonical_maps <<EOF
/([^@]+)(@.+)?/    \$1@${MAIL_FROM_FQDN}
EOF
    cat >$POSTFIX_CFDIR/header_check <<EOF
/From:([^@]+)(@.*)?/ REPLACE From: \$1@${MAIL_FROM_FQDN}
/From:[^@]+/ REPLACE From: ${MAIL_FROM_FQDN}
EOF
}

function ensureDirectoriesExist() {
    for dir in $QUEUE_DIR $DATA_DIR $MAIL_DIR ; do
	mkdir -p "$dir"
	chown postfix "$dir"
    done
}

function startPostfix() {
    trap "postfix abort ; exit 1" 0

    postfix start
    if [[ $? != 0 ]] ; then
        exit $rc
    fi
    postfix status
}

function waitForPostfix() {
    while postfix status >/dev/null 2>&1 ; do
        sleep 5
    done
    trap - 0
    postfix status
}

main


