#!/bin/bash

# 
# Delevoper .....: Waldirio M Pinheiro <waldirio@redhat.com> | <waldirio@gmail.com>
# Date ..........: 12/24/2021 (Merry Xmas)
# Purpose .......: To check the connectivity with CDN using the local/installed 
# 		   entitlements.
# License .......: GPL
# 


CA_CERT="/etc/rhsm/ca/redhat-uep.pem"
ENTITLEMENT_DIR="/etc/pki/entitlement"
RCT="/usr/bin/rct"
CURL="/usr/bin/curl -s"
PRE="https://cdn.redhat.com"
NUM_OF_URL_TO_CHECK=5


if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "$0 to check the first $NUM_OF_URL_TO_CHECK urls of each entitlement"
  echo "To see in details, execute $0 --verbose"
  exit
fi

if [ "$1" == "--verbose" ]; then
  VERBOSE=1
else
  VERBOSE=0
fi

pem_files_count=$(ls $ENTITLEMENT_DIR | wc -l)

if [ $pem_files_count -eq 0 ]; then
  echo "Please, assing some subscription"
  echo "exiting ...."
  exit
else
  echo "Found some entitlements"

  pem_files=$(ls $ENTITLEMENT_DIR | grep -v "\-key")
  for b in $pem_files
  do
    key_cert=$(echo $b | sed "s/.pem/-key.pem/g")
    url_list=$($RCT cat-cert $ENTITLEMENT_DIR/$b | grep URL: | awk '{print $2}' | grep -v "\$release" | head -n $NUM_OF_URL_TO_CHECK)

    echo "Entitlement: $b"
    for url in $url_list
    do
      #echo "$b,$url_list"
      #echo "$CURL --cacert $CA_CERT --cert $ENTITLEMENT_DIR/$b --key $ENTITLEMENT_DIR/$key_cert $PRE$url_list"
      curl_command=$($CURL --cacert $CA_CERT --cert $ENTITLEMENT_DIR/$b --key $ENTITLEMENT_DIR/$key_cert $PRE$url)
      curl_cmd_repomd=$($CURL --cacert $CA_CERT --cert $ENTITLEMENT_DIR/$b --key $ENTITLEMENT_DIR/$key_cert $PRE$url/repodata/repomd.xml)
  
      check_repodata=$(echo "$curl_command" | grep repodata | wc -l)
      check_repomd=$(echo "$curl_cmd_repomd" | wc -l)
  
      if [ $check_repodata -eq 1 ] && [ $check_repomd -ne 1 ]; then
        echo "PASS,$PRE$url"
        if [ $VERBOSE -eq 1 ]; then
          echo "==="
          echo "$curl_command"
          echo "---"
          echo "$curl_cmd_repomd"
          echo "==="
        fi
      else
        echo "FAIL,$PRE$url"
        if [ $VERBOSE -eq 1 ]; then
          echo "==="
          echo "$curl_command"
          echo "---"
          echo "$curl_cmd_repomd"
          echo "==="
        fi
      fi
    done
  done
fi
