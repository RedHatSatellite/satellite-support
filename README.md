# satellite-support
Tools for use in supporting the operation of Satellite 6

##### Tools
- [check-perf-tuning](#check-perf-tuning)  
- [mongo-benchmark](#mongo-benchmark)  
- [mongo-size-report](#mongo-size-report)  
- [postgres-monitor](#postgres-monitor)  
- [postgres-size-report](#postgres-size-report)  
- [satellite-reset](#satellite-reset)  
- [storage-benchmark](#storage-benchmark)  
- [top-uuid-report](#top-uuid-report)  
- [tuning-profiles](#tuning-profiles)  
- [postgres-activity-report](#postgres-activity-report)
- [production-log-load-stats](#production-log-load-stats)
- [check-pulp-msg](#check-pulp-msg)
- [check-cdn-connection](#check-cdn-connection)


## [check-perf-tuning](check-perf-tuning)

Utility to check performance tuning parameters on your Satellite 6 server.

## [mongo-benchmark](mongo-benchmark)

Utility used for checking IO speed specific to MongoDB. See:
[https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf](https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf)

## [mongo-size-report](mongo-size-report)

Lists the top collection sizes in disk space for Mongo. To use:
```
# ./mongo-size-report | tail -80
```

## [postgres-monitor](postgres-monitor)

Run this in a terminal to capture postgres active queries every 30 seconds.
Output stored in postgres-monitor-output.log.


## [process-monitor.sh](process-monitor.sh)

Run this in a terminal to capture sorted 'ps -aux' command every 10 seconds.
Output stored in process-monitor-output.log.


## [postgres-size-report](postgres-size-report)

Lists the top table sizes in disk space for both Candlepin and Foreman

## [postgres-activity-report](postgres-activity-report)

Lists the long running queries from PostgreSQL.

## [satellite-reset](satellite-reset)

:warning:**WARNING:** This utility should only be used as directed by Red Hat Support.
There is a risk for data loss during these cleanup routines and should only be
used when directly instructed to do so.

## [storage-benchmark](storage-benchmark)

Utility used for checking the disk IO of your Satellite 6 server. See:

[https://access.redhat.com/solutions/3397771](https://access.redhat.com/solutions/3397771)

## [top-uuid-report](top-uuid-report)

List the top subscription-manager calls by uuid/fqdn. Blank fqdn indicates an unregistered host.
```
./top-uuid-report /var/log/httpd/foreman-ssl_access_ssl.log
```

## [capsule_sync_report.rake](capsule_sync_report.rake)

Read only rake utility to generate a report of Capsule sync timings over a passed in set of days.

To deploy, download the capsule_sync_report.rake to your Satellite and copy to the

```
cd `rpm -ql tfm-rubygem-katello | head -n 1`/lib/katello/tasks
cp /root/capsule_sync_report.rake .
```

To run, specify the # of days in an environment variable:

```
# DAYS=30 foreman-rake katello:generate_content_view_capsule_sync_metrics
Task started. This may take a while depending on the amount of tasks.
Task completed. Output stored in /tmp/content_view_sync_metrics.txt
```

you can then view the report in /tmp/content_view_sync_metrics.txt

## [production-log-load-stats](production-log-load-stats)

Analyze `production.log` for load+performance statistics about types of requests to Satellite. See [https://github.com/pmoravec/rails-load-stats](https://github.com/pmoravec/rails-load-stats) for more description. **WARNING:** the script can consume excessive resources (time, memory, CPU) on large log files. Therefore it is recommended to run it outside production system on a copied logfile.

## tuning profiles

Previously this repository contained tuning templates for custom-hiera.yml. In Satellite 6.7 and above, the --tuning option is provided by the satellite-installer, with custom-hiera.yml still available as an additional layer for fine tuning or customization. Additional information on the --tuning option is available in the [Satellite documentation](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.9/html-single/installing_satellite_server_from_a_connected_network/index#tuning-with-predefined-profiles).

## [check-pulp-msg](check-pulp-msg)

This script will check pulp's `resource_manager` and `reserved_resource_worker` qpid queues and print some information to stdout; if the environment variable `CHECK_PULP_MSG_LOG_OUTPUT=Y` is set, the output will also be written to a log at `/var/log/pulp_queue.log`

The output will show the count and total number of bytes for messages currently in the queue, as well as total messages coming into and going out of the queue since the queue came online. The output was also display the number of connections and bindings for each queue.

In order to use, just download the script `check-pulp-msgs.sh` and execute it.
```
# ./check-pulp-msgs.sh
```
You can also check the help
```
# ./check-pulp-msgs.sh --help
You can just run './check-pulp-msgs.sh' to view on your screen or 'LOG_OUTPUT=Y ./check-pulp-msgs.sh' to view on screen + log in the file '/var/log/pulp_queue.log'
```
or
```
# ./check-pulp-msgs.sh -h
You can just run './check-pulp-msgs.sh' to view on your screen or 'LOG_OUTPUT=Y ./check-pulp-msgs.sh' to view on screen + log in the file '/var/log/pulp_queue.log'
```

So, that said, if you would like to see only on your screen you can just execute the command `./check-pulp-msgs.sh`. However, if you would like to see on your screen and also log the information for troubleshooting purposes, you can try `LOG_OUTPUT=Y ./check-pulp-msgs.sh`

Below an example of the output
```
Sat May  1 15:17:05 EDT 2021
  queue                                                                  dur  autoDel  excl  msg   msgIn  msgOut  bytes  bytesIn  bytesOut  cons  bind
  ======================================================================================================================================================
  reserved_resource_worker-0@satellite.example.com.celery.pidbox       Y                 0     0      0       0      0        0         1     2
  reserved_resource_worker-0@satellite.example.com.dq2            Y                      0   228    228       0    320k     320k        1     2
  reserved_resource_worker-1@satellite.example.com.celery.pidbox       Y                 0     0      0       0      0        0         1     2
  reserved_resource_worker-1@satellite.example.com.dq2            Y                      0   208    208       0   5.80m    5.80m        1     2
  resource_manager                                                       Y                      0   218    218       0   5.95m    5.95m        1     2
  resource_manager@satellite.example.com.celery.pidbox                 Y                 0     0      0       0      0        0         1     2
  resource_manager@satellite.example.com.dq2                      Y                      0     0      0       0      0        0         1     2
```


## [check-cdn-connection](check-cdn-connection)

This script can be executed by the customer in a RHEL system registered and with the entitlement/subscription assigned. Based on that, the server will try to reach some CDN links based on the entitlements already assigned to it.

There is a help that will be as below
```
# ./check-cdn-connection.sh -h
./check-cdn-connection.sh to check the first 5 urls of each entitlement
To see in details, execute ./check-cdn-connection.sh --verbose
```

If you just execute the command, the output will be as below
```
# ./check-cdn-connection.sh 
Found some entitlements
Entitlement: 2228110793913314193.pem
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/ppc64le/3scale-amp/2/debug
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/ppc64le/3scale-amp/2/os
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/ppc64le/3scale-amp/2/source/SRPMS
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/3scale-amp/2/debug
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/3scale-amp/2/os
Entitlement: 286675752367182767.pem
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/3scale-amp/2/debug
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/3scale-amp/2/os
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/3scale-amp/2/source/SRPMS
PASS,https://cdn.redhat.com/content/beta/layered/rhel8/x86_64/advanced-virt/debug
PASS,https://cdn.redhat.com/content/beta/layered/rhel8/x86_64/advanced-virt/os
```
Note. Here we are checking for `repodata` dir on some URL and also `repomd.xml` file. The PASS information will be present ONLY if both information are present.

If you would like to see more information about the query, normally, it will be necessary when the connection is failing, we can pass the flag `--verbose`, and the output will be as below
```
# ./check-cdn-connection.sh --verbose
Found some entitlements
Entitlement: 2228110793913314193.pem
PASS,https://cdn.redhat.com/content/dist/layered/rhel8/ppc64le/3scale-amp/2/debug
===
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
 <HEAD>
  <TITLE>Index of /67570/rcm/content/dist/layered/rhel8/ppc64le/3scale-amp/2/debug</TITLE>
 </HEAD>
 <BODY>
<H1>Index of /67570/rcm/content/dist/layered/rhel8/ppc64le/3scale-amp/2/debug</H1>
<PRE>   Name                              Last modified        Size  
<HR>
<IMG SRC="/icons/dir.gif" ALT="[DIR]"> <A HREF="debug/../">Parent Directory</A>                  01-Jan-1970 00:00      -  
<IMG SRC="/icons/dir.gif" ALT="[DIR]"> <A HREF="debug/Packages/">Packages/</A>                         14-Oct-2021 06:00      -  
<IMG SRC="/icons/dir.gif" ALT="[DIR]"> <A HREF="debug/repodata/">repodata/</A>                         14-Oct-2021 06:00      -  
</PRE><HR>
</BODY></HTML>
---
<?xml version="1.0" encoding="UTF-8"?>
<repomd xmlns="http://linux.duke.edu/metadata/repo" xmlns:rpm="http://linux.duke.edu/metadata/rpm">
  <revision>1634191208</revision>
  <data type="primary">
    <checksum type="sha256">e3abf4a576e4d8a4e4b5063695e1875a8b5e6cf54fd59656836bf58893664dd1</checksum>
    <open-checksum type="sha256">f70c5d27a93cd61a6b9c53f8ea211c5cc7297a446002b1dd0a07d83b405a8ef8</open-checksum>
    <location href="repodata/e3abf4a576e4d8a4e4b5063695e1875a8b5e6cf54fd59656836bf58893664dd1-primary.xml.gz"/>
    <timestamp>1634191208</timestamp>
    <size>2739</size>
    <open-size>18819</open-size>
  </data>
  <data type="filelists">
    <checksum type="sha256">7da945a60e61e1eb277d88b63e7b74137659dd4c47c4f73265f79729392a7277</checksum>
    <open-checksum type="sha256">0219049a94863a04767e8f93f7613c41f6d9333b02ba06e2db58e3b9c5da8558</open-checksum>
    <location href="repodata/7da945a60e61e1eb277d88b63e7b74137659dd4c47c4f73265f79729392a7277-filelists.xml.gz"/>
    <timestamp>1634191208</timestamp>
    <size>7745</size>
    <open-size>131735</open-size>
  </data>
  <data type="other">
    <checksum type="sha256">de7ec5f1a2e9f991e68fbb19f9bc0fe9326eb289b83f42b0aefdc730297f3c5e</checksum>
    <open-checksum type="sha256">ca4d94ba9eed892aa0d5eebf8ec11076436f8170cee15683a328f829f4b59727</open-checksum>
    <location href="repodata/de7ec5f1a2e9f991e68fbb19f9bc0fe9326eb289b83f42b0aefdc730297f3c5e-other.xml.gz"/>
    <timestamp>1634191208</timestamp>
    <size>3034</size>
    <open-size>33364</open-size>
  </data>
  <data type="primary_db">
    <checksum type="sha256">94b16fe32eaa308f6ae51313ac3a39401253bf9c09ad894d44dec5670a6a5a9e</checksum>
    <open-checksum type="sha256">8b50f9cfd5b458b92fa7341f252d9539ee7ed33c4b4fee897133e21678861b17</open-checksum>
    <location href="repodata/94b16fe32eaa308f6ae51313ac3a39401253bf9c09ad894d44dec5670a6a5a9e-primary.sqlite.bz2"/>
    <timestamp>1634191208</timestamp>
    <size>5321</size>
    <open-size>47104</open-size>
    <database_version>10</database_version>
  </data>
  <data type="filelists_db">
    <checksum type="sha256">950cd7c2ebecdab6fc025fb038c7f2be6de21eea518e7e270c565c7e3ad61ef6</checksum>
    <open-checksum type="sha256">f5e4e7cee90b5ca482308ba894a4cf3ce54d3c7d7d049b31e09f88ddad1b7b5a</open-checksum>
    <location href="repodata/950cd7c2ebecdab6fc025fb038c7f2be6de21eea518e7e270c565c7e3ad61ef6-filelists.sqlite.bz2"/>
    <timestamp>1634191208</timestamp>
    <size>11775</size>
    <open-size>60416</open-size>
    <database_version>10</database_version>
  </data>
  <data type="other_db">
    <checksum type="sha256">fd1e4c678c7e951d71cdcced245779b42c02bd1451d5f172809694f3e6fbe7c9</checksum>
    <open-checksum type="sha256">69dbd7e0c1059f8197441e2f3f64df0eea8d9e662de88f5866acf4534babe568</open-checksum>
    <location href="repodata/fd1e4c678c7e951d71cdcced245779b42c02bd1451d5f172809694f3e6fbe7c9-other.sqlite.bz2"/>
    <timestamp>1634191208</timestamp>
    <size>6765</size>
    <open-size>30720</open-size>
    <database_version>10</database_version>
  </data>
  <data type="group">
    <checksum type="sha256">a27718cc28ec6d71432e0ef3e6da544b7f9d93f6bb7d0a55aacd592d03144b70</checksum>
    <location href="repodata/a27718cc28ec6d71432e0ef3e6da544b7f9d93f6bb7d0a55aacd592d03144b70-comps.xml"/>
    <timestamp>1634191208</timestamp>
    <size>124</size>
  </data>
  <data type="updateinfo">
    <checksum type="sha256">fc08b27f5bd450523469354967258c278ace0c4d4c93daa8bbcf19dfb556a199</checksum>
    <open-checksum type="sha256">aedbbb19df839fa56baf8e1c16a7081709408068d6bc5fb55b0aebad4f26742a</open-checksum>
    <location href="repodata/fc08b27f5bd450523469354967258c278ace0c4d4c93daa8bbcf19dfb556a199-updateinfo.xml.gz"/>
    <timestamp>1634191208</timestamp>
    <size>1657</size>
    <open-size>5521</open-size>
  </data>
</repomd>
===
...
```

Note. From this check, we are skipping all the repos that have `$releasever`.