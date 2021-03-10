#!/bin/python

import socket
import argparse
import sys
import re
try:
    import requests
except ImportError:
    print('Please install the python-requests module.')
    sys.exit(-1)

output = ([],[])

def get_json(url):
    # Performs a GET using the passed URL location
  try:
    r = requests.get(url, timeout=15, verify=args.verify)
    r = r.json()
    ip_list = []
    for x in r['cidr_list']:
        ip = re.search('\d+.\d+.\d+.\d+', x['ip_prefix'])
        ip_list.append(ip.group())
  except ValueError:
    print  ("Json was not returned. Not Good!")
    sys.exit()
  return ip_list

def target_path(path):
    print(path)
    ip_list = []
    ip = open(path)
    try:
        for x in ip:
            x = re.search('\d+.\d+.\d+.\d+', x)
            ip_list.append(x.group())
    finally:
        ip.close()
    return ip_list

def scan(target):
    print('\n' + ' Starting Scan For ' + str(target))
    scan_ip(target, args.port, args.timeout)

def scan_ip(ipaddress, port, timeout):
    socket.setdefaulttimeout(timeout)
    try:
        sock = socket.socket()
        sock.connect((ipaddress, port))
        print("[ + ] Access " + str(ipaddress))
        output[0].append(str(ipaddress))
        sock.close()
    except:
        print("[ - ] Denied " + str(ipaddress))
        output[1].append(str(ipaddress))
        pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='PROG')
    parser.add_argument("--verify", default=False, help="Ignore untrusted CA")
    parser.add_argument("--timeout", type=int, default=1, help="Port timeout")
    parser.add_argument("--port", type=int, default=443, help="What port to scan against")
    parser.add_argument("--api", default="https://access.redhat.com/sites/default/files/cdn_redhat_com_cac.json", help="URL for API Call. Default is https://access.redhat.com/sites/default/files/cdn_redhat_com_cac.json")
    parser.add_argument("--path", default=None, help="Use file, if API is blocked. Use full path to file.")
    args = parser.parse_args()
 
    if args.path is not None:
        targets = target_path(args.path)
        for x in targets:
            if x != '':
                scan(x)
        print ('----------Access----------')
        print (output[0])
        print ('----------Denied----------')
        print (output[1])
    else:
        print (args.api)
        targets = get_json(args.api)
        for x in targets:
            if x != '':
                scan(x)
        print ('----------Access----------')
        print (output[0])
        print ('----------Denied----------')
        print (output[1])
