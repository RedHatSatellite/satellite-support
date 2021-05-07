#!/bin/bash

#
# Developer ..........: Waldirio M Pinheiro <waldirio@redhat.com>
# Created at .........: 05/01/2021 
# Tested Sat Version .: 6.6, 6.7, 6.8, 6.9
# Purpose ............: Check the qpid messages coming from/to Pulp.
#                       There is a BZ that is causing an weird behavior
#                       and this script help to identify it. Also there
#                       is a KCS, both below
# 
#                       https://access.redhat.com/solutions/5911931 
#                       https://bugzilla.redhat.com/show_bug.cgi?id=1945534
# 

SRV_FQDN=$(hostname -f)
CERT="/etc/pki/pulp/qpid/client.crt"
LOG="/var/log/pulp_queue.log"

qpid_stat()
{
  qpid-stat --ssl-certificate=$CERT -b amqps://localhost:5671 -q | grep -E "(resource_manager.*$SRV_FQDN.*|^  queu|^  =|resource_worker.*$SRV_FQDN.*|resource_manager )"
}

write_log() 
{
  if [[ $CHECK_PULP_MSG_LOG_OUTPUT == "Y" ]] ; then
    tee -a $LOG
  else
    cat
  fi
}

check()
{
while :
do
  date | write_log
  qpid_stat | write_log
  sleep 3
done
}

# Main
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "You can just run '$0' to view on your screen or 'CHECK_PULP_MSG_LOG_OUTPUT=Y $0' to view on screen + log in the file '$LOG'"
  exit
fi

check
