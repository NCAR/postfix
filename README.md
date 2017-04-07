# postfix
## Postfix Mail Transfer Agent (MTA) Container

This container runs the Postfix MTA in its own Docker container.

For details on running the container, see the postfix.sh script. The script can
and should be used to stop, status, start, or reload the containerized service.

The container includes the *mailx* mail client, so if you "exec"
into the running container, you can send email from it. However, its main
purpose to the allow other containers to send mail easily by acting as a
mail relay.

The easiest way to support sending email from another container is to do the
following in the other container's Dockerfile:

1. Install *ssmtp*. (For CentOS/RedHat, this requires *epel-release*.)
2. If necessary, change the value of the "mailhub" parameter in
/etc/ssmtp/ssmtp.conf to be "mail". (Most ssmtp packages set this parameter
to "mail" for you.)
3. If necessary, make /usr/sbin/sendmail a symbolic link to the ssmtp binary.
(The apt ssmtp package does this for you. On CentOS, /usr/bin/sendmail is a
link to /etc/alternatives/mta - you can change the /etc/alternatives/mta link
to point to /usr/bin/ssmtp instead.)

The environment variable MAIL_FROM_FQDN should be set to the name of the
host that email should appear to come from; this environment variable must be
passed to the Postfix container when it is run. The Postfix container is
configured to rewrite the sender's email address so that all emails from
containers that are relayed through the Postfix container will use the
value of this variable in their From header field. Without this feature, mail
sent from containers would use the unqualified container name as the host name
(e.g. "root@6ba2d5764050").

Note that the Postfix master daemon does not support running in the foreground.
The postfix.sh script "simulates" foreground execution by monitoring the
daemon in a loop and exiting when the daemon goes down. This is admittedly a
hokey kludge, but Postfix is so easy to configure and so widely used that
hokey kludginess is a small price to pay.


