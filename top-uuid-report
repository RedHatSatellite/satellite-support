#!/bin/bash

if [ "$1" == "" ]; then
  echo "Please use $0 /var/log/httpd/foreman-ssl_access_ssl.log"
  exit
fi

APACHE_UUID_LOG="/tmp/full_uuid_from_apache_list.log"
DB_UUID="/tmp/full_uuid_list.log"
COUNT=100

echo "*** Top $COUNT UUID requests in the access logs ***"
echo ""

cat $1 | awk '{print $7}' | egrep '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}' -o | sort | uniq -c  |  sort -rn | head -n $COUNT >$APACHE_UUID_LOG
su - postgres -c "echo \"select h.name,ksf.uuid from katello_subscription_facets as ksf, hosts as h where h.id=ksf.host_id\" | psql foreman" >$DB_UUID

echo "total_number,uuid,fqdn"
while read line
do
  total_number=$(echo $line | awk '{print $1}')
  uuid=$(echo $line | awk '{print $2}')
  fqdn=$(grep $uuid /tmp/full_uuid_list.log | awk '{print $1}')
  echo "$total_number,$uuid,$fqdn"
done < $APACHE_UUID_LOG
