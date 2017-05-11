#!/bin/bash

<%
  elasticsearch_addrs = nil
  respond_to?(:if_link) && if_link("elasticsearch") do |elasticsearch|
    elasticsearch_addrs = link('elasticsearch').instances.first.address
  end.else do
    elasticsearch_addrs = p("smoke_tests.elasticsearch_master.host")
  end
  syslog_ingestor = nil
  respond_to?(:if_link) && if_link("ls-router") do |syslog_ingestor|
    syslog_ingestor = link('ls-router').instances.first.address
  end.else do
    syslog_ingestor = p("smoke_tests.syslog_ingestor.host")
  end
%>

MASTER_URL="http://<%= elasticsearch_addrs %>:<%= p('smoke_tests.elasticsearch_master.port')%>"
INGESTOR_HOST="<%= syslog_ingestor %>"
INGESTOR_PORT="<%= p('smoke_tests.syslog_ingestor.port')%>"

SMOKE_ID=$(LC_ALL=C; cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
LOG="<13>$(date -u +"%Y-%m-%dT%H:%M:%SZ") 0.0.0.0 smoke-test-errand [job=smoke_tests index=0]  {\"smoke-id\":\"$SMOKE_ID\"}"

<% if p('smoke_tests.use_tls') %>
INGEST="openssl s_client -connect $INGESTOR_HOST:$INGESTOR_PORT"
<% else %>
INGEST="nc $INGESTOR_HOST $INGESTOR_PORT"
<% end %>

echo "SENDING $LOG"
echo "$LOG" | $INGEST > /dev/null

TRIES=${1:-600}
SLEEP=5

echo -n "Polling for $TRIES seconds"
while [ $TRIES -gt 0 ]; do
  result=$(curl -s $MASTER_URL/_search?q=$SMOKE_ID)
  if [[ $result == *"$SMOKE_ID"* ]]; then
    echo -e "\nSUCCESS: Found log containing $SMOKE_ID"
    echo $result
    exit 0
  else
    sleep $SLEEP
    echo -n "."
    TRIES=$((TRIES-SLEEP))
  fi
done

echo -e "\nERROR:  Couldn't find log containing: $SMOKE_ID"
echo "Last search result: $result"
exit 1
