FROM centos:7

WORKDIR /opt/app

RUN yum -y update && \
    yum -y clean all && \
    yum -y install wget zip unzip epel-release rsync java-1.8.0-openjdk && \
    mkdir -p /opt/app && \
    wget -O /tmp/remi-release-7.rpm http://rpms.famillecollet.com/enterprise/remi-release-7.rpm && \
    yum -y install /tmp/remi-release-7.rpm && \
    yum clean all && \
    yum -y --enablerepo remi,remi-php56 install php56 php56-php-pdo php56-php-mbstring php56-php-xml php56-php-ZendFramework-Db-Adapter-Pdo-Mysql && \
    ln -s /usr/bin/php56 /usr/bin/php

ENV JAVA_HOME=/usr/lib/jvm/jre-openjdk/
