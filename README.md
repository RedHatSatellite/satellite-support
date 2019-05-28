# satellite-support
Tools for use in supporting the operation of Satellite 6

## satellite-reset

**WARNING:** This utility should only be used as directed by Red Hat Support.
There is a risk for data loss during these cleanup routines and should only be
used when directly instructed to do so.

## storage-benchmark

Utility used for checking the disk IO of your Satellite 6 server. See:

[https://access.redhat.com/solutions/3397771](https://access.redhat.com/solutions/3397771)

## postgres-size-report

Lists the top table sizes in disk space for both Candlepin and Foreman

## mongo-size-report

Lists the top collection sizes in disk space for Mongo. To use:
```
# ./mongo-size-report | tail -80
```
## top-uuid-report

List the top calls by uuid/fqdn

## postgres-monitor

Run this in a terminal to capture postgres active queries every 30 seconds.
Output stored in postgres-monitor-output.log.

## mongo-benchmark

Utility used for checking IO speed specific to MongoDB. See:
[https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf](https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf)

## check-perf-tuning
Utility to check performance tuning parameters on your Satellite 6 server.
