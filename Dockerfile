FROM centos:7

ENV REFRESHED_AT 2017-04-05
LABEL repo=cisl-repo \
      name=postfix \
      version=1.0

RUN yum -y update && yum -y install \
    postfix \
    mailx

RUN rm /etc/localtime
RUN ln -s /usr/share/zoneinfo/America/Denver /etc/localtime

COPY run-postfix.sh /bin/

EXPOSE 25 465 587

VOLUME /var/postfix

CMD [ "/bin/run-postfix.sh" ]

