FROM inmbzp5170.in.dst.ibm.com:5000/ubuntu:69
MAINTAINER "Ghanshyam <gsaini05@in.ibm.com>"
USER root

# add our user and group first to make sure their IDs get assigned consistently
#ARG user=kibana
#ARG group=kibana
#ARG uid=1000
#ARG gid=1000
#RUN groupadd -g ${gid} ${group} \
#&& useradd -d "/home/kibana" -u ${uid} -g ${gid} -m -s /bin/bash ${user}
#RUN groupadd -r kibana && useradd -r -m -g kibana kibana

ENV KIBANA_VERSION 6.1.2

RUN set -x \ 
 && apt-get update && apt-get clean all && apt-get install -y \
		apt-transport-https \
		ca-certificates \
		wget \
# generating PDFs requires libfontconfig and libfreetype6
		libfontconfig \
		libfreetype6 \
	--no-install-recommends \ 
 && echo 'deb https://artifacts.elastic.co/packages/6.x/apt stable main' > /etc/apt/sources.list.d/kibana.list \
 && apt-get update \
        && apt-get install -y --allow-unauthenticated kibana=$KIBANA_VERSION \
        && apt-get clean all \
        && rm -rf /var/lib/apt/lists/* 

# grab gosu for easy step-down from root
#ENV GOSU_VERSION 1.10
RUN set -x \
  #	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
  #	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \

        && wget -O /usr/local/bin/gosu http://inmbzp7148.in.dst.ibm.com:8081/repository/installables/gosu-amd64 \
        && wget -O /usr/local/bin/gosu.asc http://inmbzp7148.in.dst.ibm.com:8081/repository/installables/gosu-amd64.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

# grab tini for signal processing and zombie killing
#ENV TINI_VERSION v0.9.0
RUN set -x \
  #	&& wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" \
  #	&& wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini.asc" \
        
        && wget -O /usr/local/bin/tini http://inmbzp7148.in.dst.ibm.com:8081/repository/installables/tini \
        && wget -O /tmp/tini.asc.tar.gz http://inmbzp7148.in.dst.ibm.com:8081/repository/installables/tini.asc.tar.gz \
        && tar -zxvf /tmp/tini.asc.tar.gz -C /usr/local/bin/ \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 6380DC428747F6C393FEACA59A84159D7001A4E5 \
	&& gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini \
	&& rm -rf "$GNUPGHOME" /usr/local/bin/tini.asc \
	&& chmod +x /usr/local/bin/tini \
	&& tini -h

RUN set -ex; \
# https://artifacts.elastic.co/GPG-KEY-elasticsearch
	key='46095ACC8548582C1A2699A9D27D666CD88E42B4'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	gpg --export "$key" > /etc/apt/trusted.gpg.d/elastic.gpg; \
	rm -rf "$GNUPGHOME"; \
	apt-key list

# https://www.elastic.co/guide/en/kibana/6.0/deb.html

RUN set -x \
# the default "server.host" is "localhost" in 5+
	&& sed -ri "s!^(\#\s*)?(server\.host:).*!\2 '0.0.0.0'!" /etc/kibana/kibana.yml \
	&& grep -q "^server\.host: '0.0.0.0'\$" /etc/kibana/kibana.yml \
# ensure the default configuration is useful when using --link
	&& sed -ri "s!^(\#\s*)?(elasticsearch\.url:).*!\2 'http://elasticsearch:9200'!" /etc/kibana/kibana.yml \
	&& grep -q "^elasticsearch\.url: 'http://elasticsearch:9200'\$" /etc/kibana/kibana.yml

ENV PATH /usr/share/kibana/bin:$PATH

ADD filebeat-6.2.1-linux-x86_64 /filebeat-6.2.1-linux-x86_64
ADD node_exporter-0.15.2.linux-amd64 /opt/node_exporter-0.15.2.linux-amd64
RUN mv /opt/node_exporter-0.15.2.linux-amd64 /opt/node_exporter/
ADD node_exporter.sh /opt/node_exporter/node_exporter.sh
ADD node_exporter /etc/init.d/node_exporter
ADD docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
#USER kibana
EXPOSE 5601 9100 5044
ENTRYPOINT ["/docker-entrypoint.sh"]
RUN chmod +x /docker-entrypoint.sh
CMD ["kibana"]
