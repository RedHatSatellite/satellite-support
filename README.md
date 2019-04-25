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

## mongo-benchmark

Utility used for checking IO speed specific to MongoDB. See:
[https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf](https://www.mongodb.com/blog/post/checking-disk-performance-with-the-mongoperf)

## check-perf-tuning
Utility to check performance tuning parameters on your Satellite 6 server.

## cv_sync_metrics
This rake task creates a report on the performance of different Content view Capsule sync tasks in your Satellite6 environment.  For usage instructions, read the [docs](docs/cv_sync_metrics.md).
