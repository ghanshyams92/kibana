#!/bin/bash


set -e
/etc/init.d/node_exporter start &
sleep 10
/filebeat-6.2.1-linux-x86_64/filebeat -e -c /filebeat-6.2.1-linux-x86_64/filebeat.yml &


# Add kibana as command if needed
if [[ "$1" == -* ]]; then
	set -- kibana "$@"
fi

# Run as user "kibana" if the command is "kibana"
if [ "$1" = 'kibana' ]; then
	if [ "$ELASTICSEARCH_URL" ]; then
		sed -ri "s!^(\#\s*)?(elasticsearch\.url:).*!\2 '$ELASTICSEARCH_URL'!" /etc/kibana/kibana.yml
	fi

	set -- gosu kibana tini -- "$@"
fi

exec "$@"


