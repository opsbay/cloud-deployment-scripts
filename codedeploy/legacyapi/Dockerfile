# Base image
FROM hobsonspipe/centos6-php53

RUN yum -q -y install \
    git \
    wget \
    unzip \
    mysql \
    python-setuptools \
    python-setuptools-devel \
    python-pip

# Java
RUN yum -q -y install java-1.8.0-openjdk

RUN pip install awscli
RUN curl --silent --location https://rpm.nodesource.com/setup_6.x | bash -
RUN yum install -q -y nodejs
RUN sed -i "s/allow_url_fopen =.*/allow_url_fopen = On/" /etc/php.ini
RUN sed -i "s/short_open_tag =.*/short_open_tag = On/" /etc/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = America\/New_York/" /etc/php.ini
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

