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

## [tuning profiles](tuning-profiles)

Some tuning template settings (custom-hiera.yml) for Satellite 6 with [32](tuning-profiles/custom-hiera-medium-32G.yaml), [64](tuning-profiles/custom-hiera-large-64G.yaml), [128](tuning-profiles/custom-hiera-ex-large-128G.yaml) or [256GB](tuning-profiles/custom-hiera-2ex-large-256G.yaml) of RAM. If you have less than 32GB RAM the default settings for Satellite 6 are appropriate.


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
