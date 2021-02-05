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
