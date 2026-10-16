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
- [satellite-storage-benchmark.sh](#satellite-storage-benchmarksh)  
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

> **Deprecated — superseded by [satellite-storage-benchmark.sh](#satellite-storage-benchmarksh).** This original script runs buffered sequential-only `fio` tests (no `O_DIRECT`, no `fsync`), which measure the page cache more than the backend disk and don't reflect the PostgreSQL/Pulp I/O profiles. Prefer the successor for new work.

## [satellite-storage-benchmark.sh](satellite-storage-benchmark.sh)

Successor to `storage-benchmark` that measures the **backend** disk under the two
I/O profiles that actually drive Satellite: **PostgreSQL** (small 8k random I/O
plus commit/`fdatasync` latency) and **Pulp** (large 1M sequential transfer). It
uses `fio` with `O_DIRECT` (to bypass the page cache and measure the real device)
and the synchronous **`psync`** engine at `iodepth=1` — mirroring how PostgreSQL
backends and pulpcore workers actually issue I/O (blocking `pread`/`pwrite` +
`fdatasync`), with concurrency modelled by the number of processes (`numjobs`). It
reports IOPS, latency percentiles and bandwidth for the real device, and finishes
in minutes (no 2×RAM file).

### Usage

```
# ./satellite-storage-benchmark.sh          # tests both /var/lib/pgsql and /var/lib/pulp
# ./satellite-storage-benchmark.sh pgsql     # just the PostgreSQL data directory
# ./satellite-storage-benchmark.sh pulp      # just the Pulp data directory
```

With no argument it benchmarks both Satellite data directories (`/var/lib/pgsql`
and `/var/lib/pulp`) — hardcoded, not inferred from a path — running each one's
role-appropriate tests. For a containerized (foremanctl) Satellite, run it **on
the container host** (not inside a container); those host directories are the
volumes that back the PostgreSQL and pulpcore containers, which is the storage
whose performance matters.

### Output

Prints a **PASS/WARN/FAIL verdict per profile** and writes a machine-readable JSON
report (`/tmp/satellite-storage-benchmark-<timestamp>.json`) for comparing runs.
The PostgreSQL commit (`fdatasync`) p99 latency is the single most important
number — a FAIL there means the database will stall under load.

### Tunables

Command-line options (also shown by `--help`):

- `--filegb N` (default `10`) — test file size, GiB.
- `--runtime N` (default `180`) — seconds per profile (`3000` with `--sustained`).
- `--pgsql-jobs N` (default `8`) — concurrent PostgreSQL backends modelled.
- `--pulp-jobs N` (default `min(8, nproc)`) — parallel Pulp workers modelled (pulpcore's default worker count).
- `--sustained` — raise runtime to 3000s/profile so cloud burst credits deplete (a full run then takes hours; override with `--runtime` if you need less).

### Virtualized / cloud guests

Inside a VM, throughput and IOPS can be served from the hypervisor's page cache
and cannot be trusted from inside the guest — there is no guest-side signal that
distinguishes "fast media" from "warm host cache". The script detects a VM host
(`systemd-detect-virt --vm`) and then shows bandwidth/IOPS/random-latency as
**`[INFO]` (measured but not graded)**, grading **only `fdatasync`** — the one
metric that survives caching, because durability forces a real flush. It cannot
detect a hypervisor configured to ignore flushes (`cache=unsafe`), so a passing
`fdatasync` is not an absolute durability guarantee. To grade throughput/IOPS
from a guest, ask your virtualization/cloud admin whether this disk's virtual
storage can be set to bypass host-side caching (often called a "direct" or
"no-cache" mode — naming and location vary by platform), then re-run.

Some cloud/virtual block storage uses a **burst-credit** model: a short test rides
the burst and over-reports, then performance falls to a lower provisioned baseline
once credits are spent. Pass **`--sustained`** to run long enough to exhaust the
credits and measure that baseline. How long that takes depends on the volume (and
large or high-tier volumes often don't burst at all), so treat your provider's own
volume/burst metrics as the authoritative view — the guest can't see them.
`--sustained` does *not* defeat hypervisor page cache; raising `--filegb` above
host RAM only *reduces* (never eliminates) cache inflation, and the guest cannot
see host RAM, so it is a best-effort lever, not a fix.

On HDD-backed volumes, multiple concurrent sequential streams make the heads
thrash, so the Pulp profiles' `--pulp-jobs` parallelism (which models real
pulpcore workers) reports lower sequential throughput than a single stream would —
that low number is workload-representative, not an artifact. To measure the drive's
peak single-stream sequential capability instead, use `--pulp-jobs 1`.

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
