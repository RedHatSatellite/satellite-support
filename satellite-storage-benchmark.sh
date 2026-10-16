#!/bin/bash
#
# satellite-storage-benchmark.sh -- benchmark backend storage with fio+O_DIRECT
# for Satellite's two I/O profiles: PostgreSQL (8k random + fdatasync latency)
# and Pulp (1M sequential). Prints a PASS/WARN/FAIL verdict + JSON report; usable
# pre-install. In a VM only fdatasync is graded (cache hides the rest). See KCS
# solutions/3397771.
#
#   # ./satellite-storage-benchmark.sh          # pgsql + pulp (+ containers if present)
#   # ./satellite-storage-benchmark.sh pulp      # just the Pulp data directory
#
# Targets are the real Satellite data directories (hardcoded); an optional
# 'pgsql'/'pulp'/'containers' argument limits the run to one. Run with --help.

set -euo pipefail

usage(){
  cat <<'EOF'
Usage: ./satellite-storage-benchmark.sh [options] [pgsql|pulp|containers]
  No argument -> tests /var/lib/pgsql and /var/lib/pulp, plus /var/lib/containers
                 if present (containerized installs).
  pgsql|pulp|containers -> tests only that Satellite data directory.

Options:
  --filegb N      test file size in GiB (default 10)
  --runtime N     seconds per profile (default 180; 3000 with --sustained)
  --pgsql-jobs N  concurrent PostgreSQL backends to model (default 8)
  --pulp-jobs N   parallel Pulp workers to model (default min(8, nproc))
  --sustained     set runtime to 3000s/profile to deplete cloud burst credits
  -h, --help      show this help
EOF
}

need_int(){  # need_int <flag> <value>
  [[ "$2" =~ ^[1-9][0-9]*$ ]] || { echo "** $1 requires a positive integer"; exit 1; }
}

FILEGB=10
RUNTIME=""
PGSQL_JOBS=8
PULP_JOBS=""
SUSTAINED=false
RAMP=5
SELECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filegb)     need_int "$1" "${2:-}"; FILEGB="$2";     shift 2 ;;
    --runtime)    need_int "$1" "${2:-}"; RUNTIME="$2";    shift 2 ;;
    --pgsql-jobs) need_int "$1" "${2:-}"; PGSQL_JOBS="$2"; shift 2 ;;
    --pulp-jobs)  need_int "$1" "${2:-}"; PULP_JOBS="$2";  shift 2 ;;
    --sustained)  SUSTAINED=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "** unknown option: $1"; usage; exit 1 ;;
    *)            SELECT="$1"; shift ;;
  esac
done

# --sustained drains cloud burst credits (explicit --runtime wins); not host cache.
if [[ -z "$RUNTIME" ]]; then
  if $SUSTAINED; then RUNTIME=3000; else RUNTIME=180; fi
fi

# Pulp concurrency defaults to pulpcore's default worker count, min(8, nproc).
if [[ -z "$PULP_JOBS" ]]; then
  cpus="$(nproc 2>/dev/null || echo 1)"
  PULP_JOBS=$(( cpus < 8 ? cpus : 8 ))
fi

# Targets are the real Satellite data directories (hardcoded), as "path|role".
# PG lives in /var/lib/pgsql on both traditional and containerized (foremanctl)
# 6.x, incl. 6.16; Pulp in /var/lib/pulp. An optional pgsql/pulp arg limits to one.
declare -a TARGETS=()
want_pgsql=false; want_pulp=false; want_containers=false
case "$SELECT" in
  "")         want_pgsql=true; want_pulp=true; want_containers=true ;;
  pgsql)      want_pgsql=true ;;
  pulp)       want_pulp=true ;;
  containers) want_containers=true ;;
  *)          echo "** unknown target '$SELECT' -- use pgsql, pulp, or containers (or no argument for all)."; exit 1 ;;
esac
if $want_pgsql && [[ -d /var/lib/pgsql ]]; then TARGETS+=("/var/lib/pgsql|pgsql"); fi
if $want_pulp  && [[ -d /var/lib/pulp  ]]; then TARGETS+=("/var/lib/pulp|pulp");  fi
# Container-image storage only exists on containerized installs; include it if present.
if $want_containers && [[ -d /var/lib/containers ]]; then TARGETS+=("/var/lib/containers|containers"); fi
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "** None of the requested Satellite data directories exist here"
  echo "   (/var/lib/pgsql, /var/lib/pulp, /var/lib/containers) -- nothing to benchmark."
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
JOBFILE="$(mktemp /tmp/satellite-storage-benchmark.XXXXXX.fio)"
LOGFILE="/tmp/satellite-storage-benchmark-${STAMP}.log"
# Satellite's PostgreSQL backends and pulpcore workers do synchronous, blocking
# I/O (pread/pwrite + fdatasync) -- fio's psync engine -- so use it to represent
# real behavior. Concurrency comes from numjobs (processes), not queue depth.
IOENGINE=psync
STOPPED=false
declare -a CREATED=()
declare -A DEV_OF=()   # path -> physical backing device(s), to flag shared-disk runs

# Buffers so every target's rows land in one grouped RESULTS block at the end,
# instead of printing inline between each target's run chatter.
declare -a RESULT_ROWS=() BAND_LINES=() FOOT_LINES=()

# Mirror everything (prompts, per-target headers, results, legend, notes) to the
# log so the saved file is a complete, shareable transcript -- not just the rows.
exec > >(tee "$LOGFILE") 2>&1

# Satellite services: a foremanctl (containerized) install uses systemd; a
# traditional install uses foreman-maintain.
if command -v foremanctl >/dev/null 2>&1; then
  SVC_MGR=foremanctl
elif command -v foreman-maintain >/dev/null 2>&1; then
  SVC_MGR=foreman-maintain
else
  SVC_MGR=none
fi
services_stop(){ case "$SVC_MGR" in
  foremanctl)       systemctl stop foreman.target ;;
  foreman-maintain) foreman-maintain service stop ;;
esac; }

services_start(){ case "$SVC_MGR" in
  foremanctl)       systemctl start foreman.target || true ;;
  foreman-maintain) foreman-maintain service start || true ;;
esac; }

cleanup(){
  rm -f "$JOBFILE" 2>/dev/null || true
  local dir
  for dir in ${CREATED[@]+"${CREATED[@]}"}; do
    rm -f "$dir/satellite-benchmark.dat" 2>/dev/null || true
    rmdir "$dir" 2>/dev/null || true
  done
  if $STOPPED; then
    echo; echo "Starting Satellite services ($SVC_MGR)."
    services_start
  fi
}
trap cleanup EXIT INT TERM

# Detect only the hypervisor layer (--vm): bare-metal/container host graded; VM demoted.
# (The VM caveat is printed once at the end, not here, to avoid duplication.)
VIRT="$(systemd-detect-virt --vm 2>/dev/null || true)"
[[ -z "$VIRT" ]] && VIRT=none

# ---- helpers: role -> profiles, and the fio job section per profile ----------
role_desc(){ case "$1" in
  pgsql)      echo "PostgreSQL tests" ;;
  pulp)       echo "Pulp tests" ;;
  containers) echo "container-image storage tests" ;;
esac; }

profiles_for(){ case "$1" in
  pgsql)      echo pgsql-random-rw pgsql-commit-fsync ;;
  pulp)       echo pulp-seq-read pulp-seq-write ;;
  containers) echo containers-seq-read ;;
esac; }

emit_profile(){ case "$1" in
  # PG random = PGSQL_JOBS synchronous backends (iodepth=1), not a deep queue.
  pgsql-random-rw)
    printf '[pgsql-random-rw]\nrw=randrw\nrwmixread=70\nbs=8k\niodepth=1\nnumjobs=%s\n' "$PGSQL_JOBS" ;;

  pgsql-commit-fsync)
    printf '[pgsql-commit-fsync]\nrw=write\nbs=8k\niodepth=1\nfdatasync=1\n' ;;

  # Pulp = PULP_JOBS synchronous workers (iodepth=1), not a deep queue.
  pulp-seq-read)
    printf '[pulp-seq-read]\nrw=read\nbs=1M\niodepth=1\nnumjobs=%s\n' "$PULP_JOBS" ;;

  pulp-seq-write)
    printf '[pulp-seq-write]\nrw=write\nbs=1M\niodepth=1\nnumjobs=%s\n' "$PULP_JOBS" ;;

  # Container-image storage: large sequential read (image layer load at start).
  containers-seq-read)
    printf '[containers-seq-read]\nrw=read\nbs=1M\niodepth=1\nnumjobs=%s\n' "$PULP_JOBS" ;;
esac; }

# The fio [global] options shared by every test -- single source for both the job
# file (newline-separated) and the one-time display (space-separated).
global_opts(){
  printf 'size=%sG direct=1 ioengine=%s time_based=1 runtime=%s ramp_time=%s group_reporting=1 stonewall unlink=1' \
    "$FILEGB" "$IOENGINE" "$RUNTIME" "$RAMP"
}

echo
echo "About to benchmark storage for Satellite on:"
for target in "${TARGETS[@]}"; do
  IFS='|' read -r path role <<<"$target"
  printf '  - %-19s (%s)\n' "$path" "$(role_desc "$role")"
done
echo "Each writes a ${FILEGB} GiB test file, runs ${RUNTIME}s per test (+${RAMP}s warm-up), then removes it."
echo "Proceed? (Y/N) "
read -r PROCEED
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
  echo "** cancelled **"
  exit 1
fi

if ! command -v fio >/dev/null 2>&1; then
  echo "** Installing fio **"
  if command -v foreman-maintain >/dev/null 2>&1; then
    foreman-maintain packages install -y fio
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y fio
  else
    yum install -y fio
  fi
fi

echo "Stop Satellite services during the test? [y/N] "
read -r STOPSERVICES
if [[ "$STOPSERVICES" =~ ^[Yy]$ ]]; then
  if [[ "$SVC_MGR" == none ]]; then
    echo "Neither foremanctl nor foreman-maintain found. Continuing without stopping services."
  else
    echo; echo "Stopping Satellite services ($SVC_MGR)."
    services_stop
    STOPPED=true
  fi
fi

# ---- parsing + reporting ----------------------------------------------------
declare -A BW IOPS P50 P90 P95 P99

# Parse the fio JSON (pretty-printed, one key per line) in pure bash into BW/IOPS and
# the latency percentiles (p50/p90/p95/p99) of the clat (read/write) and sync blocks.
parse_json(){
  BW=(); IOPS=(); P50=(); P90=(); P95=(); P99=()
  local line job="" section="" cap=0 val
  while IFS= read -r line; do
    case "$line" in
      *'"jobname"'*)     job="${line#*: \"}"; job="${job%%\"*}"; section=""; cap=0 ;;
      *'"read" : {'*)    section="read";  cap=0 ;;
      *'"write" : {'*)   section="write"; cap=0 ;;
      *'"trim" : {'*)    section="trim";  cap=0 ;;
      *'"sync" : {'*)    section="sync";  cap=0 ;;
      *'"slat_ns"'*)     cap=0 ;;
      *'"clat_ns"'*)     [[ "$section" == read || "$section" == write ]] && cap=1 || cap=0 ;;
      *'"lat_ns"'*)      [[ "$section" == sync ]] && cap=1 || cap=0 ;;
      *'"bw" : '*)       val="${line#*: }"; BW["$job:$section"]="${val%,}" ;;
      *'"iops" : '*)     val="${line#*: }"; IOPS["$job:$section"]="${val%,}" ;;
      *'"50.000000"'*)   if (( cap )); then val="${line#*: }"; P50["$job:$section"]="${val%,}"; fi ;;
      *'"90.000000"'*)   if (( cap )); then val="${line#*: }"; P90["$job:$section"]="${val%,}"; fi ;;
      *'"95.000000"'*)   if (( cap )); then val="${line#*: }"; P95["$job:$section"]="${val%,}"; fi ;;
      *'"99.000000"'*)   if (( cap )); then val="${line#*: }"; P99["$job:$section"]="${val%,}"; fi ;;
    esac
  done < "$1"
}

grade_high(){ local v=$1 g=$2 w=$3; (( v >= g )) && echo PASS || { (( v >= w )) && echo WARN || echo FAIL; }; }
grade_low(){  local v=$1 g=$2 w=$3; (( v <= g )) && echo PASS || { (( v <= w )) && echo WARN || echo FAIL; }; }

# Classify a non-PASS verdict by its distribution's body: if p95 is within the healthy
# band, the slowness is a thin tail (rare outliers); if not, it's broadly elevated.
latency_shape(){ local p95=$1 healthy=$2; (( p95 <= healthy )) && echo thin || echo broad; }

fmt_ms(){ printf '%d.%02d ms' $(( $1 / 1000000 )) $(( ($1 % 1000000) / 10000 )); }
fmt_mb(){ printf '%d.%01d MB/s' $(( $1 / 1024 )) $(( ($1 % 1024) * 10 / 1024 )); }

# Plain-language label + "why this matters" line per test, keyed by its fio jobname.
declare -A LABEL=(
  [pgsql-random-rw]="PostgreSQL running queries"
  [pgsql-commit-fsync]="PostgreSQL committing writes"
  [pulp-seq-read]="Pulp reading content"
  [pulp-seq-write]="Pulp writing content"
  [containers-seq-read]="Container image reads"
)
declare -A MEANING=(
  [pgsql-random-rw]="how snappy typical database queries will feel under load"
  [pgsql-commit-fsync]="how long each database write waits to be made durable -- the one that matters most"
  [pulp-seq-read]="how fast Satellite can serve/sync large content, start to finish"
  [pulp-seq-write]="how fast Satellite can pull in/store large content, start to finish"
  [containers-seq-read]="how fast container images load at service start"
)

# Print one result row (the metric meanings are collected into a legend at the end).
row(){ printf '  [%-4s] %-28s %s\n' "$1" "$2" "$3"; }

print_bars(){ case "$1" in
  pgsql)
    echo "  Bands (ms) -- query p99:  PASS <=5, WARN 5-20, FAIL >20"
    echo "                commit p99: PASS <=3, WARN 3-10, FAIL >10" ;;
  pulp)
    echo "  Bands (MB/s) -- reads:  PASS >=300, WARN 100-300, FAIL <100"
    echo "                  writes: PASS >=200, WARN 75-200,  FAIL <75" ;;
  containers)
    echo "  Bands (MB/s; PASS or WARN only, not a hot path) -- reads: PASS >=100, WARN <100" ;;
esac; }

# Buffer this role's rows (and any bars/commit footnote) for the grouped RESULTS
# block printed once at the end. Reads global BW/IOPS and the latency percentiles.
collect_results(){
  local role=$1
  local graded=true; [[ "$VIRT" != none ]] && graded=false
  local name good warn r w bw v ir iw pr pw p99 ps cps
  local p50s p90s p95s
  local commit_verdict="" has_commit=false
  for name in $(profiles_for "$role"); do
    case "$name" in
      pgsql-random-rw)
        ir="${IOPS[pgsql-random-rw:read]:-0}"; ir="${ir%.*}"
        iw="${IOPS[pgsql-random-rw:write]:-0}"; iw="${iw%.*}"
        pr="${P99[pgsql-random-rw:read]:-0}"; pw="${P99[pgsql-random-rw:write]:-0}"; p99=$(( pr > pw ? pr : pw ))
        v="$(grade_low "$p99" 5000000 20000000)"; $graded || v=INFO
        RESULT_ROWS+=("$(row "$v" "${LABEL[pgsql-random-rw]}" "$(( ir + iw )) IOPS; p99 latency reads $(fmt_ms "$pr"), writes $(fmt_ms "$pw")")") ;;

      pgsql-commit-fsync)
        ps="${P99[pgsql-commit-fsync:sync]:-0}"; commit_verdict="$(grade_low "$ps" 3000000 10000000)"; has_commit=true
        p50s="${P50[pgsql-commit-fsync:sync]:-0}"; p90s="${P90[pgsql-commit-fsync:sync]:-0}"; p95s="${P95[pgsql-commit-fsync:sync]:-0}"
        cps="${IOPS[pgsql-commit-fsync:write]:-0}"; cps="${cps%.*}"
        RESULT_ROWS+=("$(row "$commit_verdict" "${LABEL[pgsql-commit-fsync]}" "${cps} durable commits/s; p99 latency $(fmt_ms "$ps")")") ;;

      pulp-seq-read|pulp-seq-write|containers-seq-read)
        case "$name" in                                  # KiB/s
          pulp-seq-read)       good=307200; warn=102400 ;;
          pulp-seq-write)      good=204800; warn=76800  ;;
          containers-seq-read) good=102400; warn=0 ;;    # warn floor 0 -> PASS or WARN, never FAIL
        esac
        r="${BW[$name:read]:-0}"; w="${BW[$name:write]:-0}"; bw=$(( r > w ? r : w ))
        v="$(grade_high "$bw" "$good" "$warn")"; $graded || v=INFO
        RESULT_ROWS+=("$(row "$v" "${LABEL[$name]}" "$(fmt_mb "$bw")")") ;;
    esac
  done

  # Bare metal: buffer the role's pass bands. (In a guest the rows are [INFO] and
  # the caching caveat is printed once at the end, not per filesystem.)
  $graded && BAND_LINES+=("$(print_bars "$role")")

  if $has_commit && [[ "$commit_verdict" != PASS ]]; then
    # Body healthy (p95 <= 2ms, the "good cloud SSD" bar) means the WARN/FAIL is a
    # thin tail of rare stalls; otherwise the whole commit path is slow.
    FOOT_LINES+=("$(
      echo "  Commit latency spread:  p50 $(fmt_ms "$p50s")  p90 $(fmt_ms "$p90s")  p95 $(fmt_ms "$p95s")  p99 $(fmt_ms "$ps")"
      if [[ "$(latency_shape "$p95s" 2000000)" == thin ]]; then
        echo "  Thin tail -- 95% of commits land in the good range (<=2.00 ms); only the slowest"
        echo "  ~1% reach $commit_verdict. Typical of occasional storage/replication jitter, not a"
        echo "  slow commit path. Unlikely to hurt steady state; consider a lower-tail-latency"
        echo "  storage tier only if those commit spikes prove to matter."
      else
        echo "  Broad elevation -- even the p95 commit exceeds the 2.00 ms good range, so the"
        echo "  whole commit path is slow ($commit_verdict), not just rare outliers. Every write"
        echo "  waits on it. To fix: put the PostgreSQL WAL on low-latency NVMe, enable the RAID"
        echo "  controller's battery/flash-backed write cache, and avoid NFS or volatile caches."
      fi
    )")
  fi
}

# ---- per-target benchmark ---------------------------------------------------
run_target(){
  local path=$1 role=$2
  local dir="$path/satellite-storage-benchmark"
  local testfile="$dir/satellite-benchmark.dat"
  local json="/tmp/satellite-storage-benchmark-${STAMP}-$(basename "$path").json"
  echo
  echo "========== $path  ($(role_desc "$role")) =========="
  if [[ ! -d "$path" ]]; then echo "** skip: $path does not exist."; return; fi

  # Show the backing device, and warn on NFS (unsupported for PostgreSQL).
  if command -v findmnt >/dev/null 2>&1; then
    local mnt fstype
    mnt="$(findmnt -no SOURCE,FSTYPE,TARGET -T "$path" 2>/dev/null || true)"
    [[ -n "$mnt" ]] && echo "Backing store (device  fstype  mountpoint): $mnt"
    fstype="$(findmnt -no FSTYPE -T "$path" 2>/dev/null || true)"
    [[ "$fstype" == nfs* ]] && echo "** WARNING: NFS path -- PostgreSQL unsupported on NFS; fsync latency too high."
  fi

  # Preflight: enough free space, and the filesystem actually supports O_DIRECT.
  mkdir -p "$dir"; CREATED+=("$dir")
  local availgb; availgb="$(df -Pk "$dir" | awk 'NR==2 {printf "%d", $4/1024/1024}')"
  if (( availgb < FILEGB )); then echo "** skip: only ${availgb} GiB free, need ${FILEGB} GiB."; return; fi

  local direct_ok=true
  dd if=/dev/zero of="$dir/.directprobe" bs=4096 count=1 oflag=direct status=none 2>/dev/null || direct_ok=false
  rm -f "$dir/.directprobe" 2>/dev/null || true
  if ! $direct_ok; then echo "** skip: $path does not support O_DIRECT (use xfs/ext4, not tmpfs/overlay)."; return; fi

  # Build the role-specific fio job, run it, and parse the JSON. The [global]
  # options come from global_opts (shared, shown once up top); only the per-profile
  # sections differ per target.
  {
    printf '[global]\nfilename=%s\n%s\n' "$testfile" "$(global_opts | tr ' ' '\n')"
    local profile
    for profile in $(profiles_for "$role"); do
      printf '\n'
      emit_profile "$profile"
    done
  } > "$JOBFILE"

  echo "Running fio (JSON: $json)..."

  # Show only the per-profile params here (the shared globals are printed once, before
  # the first test); derived from emit_profile so they can't drift from what runs.
  local prof
  for prof in $(profiles_for "$role"); do
    printf '    %-19s %s\n' "$prof" "$(emit_profile "$prof" | grep -v '^\[' | paste -sd' ' -)"
  done

  fio "$JOBFILE" --output-format=json --output="$json"
  parse_json "$json"

  # Record the physical backing device(s) fio saw (disk_util[].name), minus the
  # dm-* mapper layer, so we can flag when two paths are really the same disk.
  DEV_OF["$path"]="$(grep -oE '"name" : "[^"]+"' "$json" 2>/dev/null \
    | sed -E 's/.*"([^"]+)"$/\1/' | grep -vE '^dm-' | sort -u | tr '\n' ' ')"

  collect_results "$role"
  rm -f "$testfile" 2>/dev/null || true; rmdir "$dir" 2>/dev/null || true
}

echo
echo "fio options common to all tests: $(global_opts)"
for target in "${TARGETS[@]}"; do
  IFS='|' read -r path role <<<"$target"
  run_target "$path" "$role"
done

# All targets done: print every result row together in one grouped block, then the
# bare-metal bands and the commit footnote (each present only when it applies).
echo
echo "==================== RESULTS ===================="
echo
(( ${#RESULT_ROWS[@]} )) && printf '%s\n' "${RESULT_ROWS[@]}"
(( ${#BAND_LINES[@]} )) && { echo; printf '%s\n' "${BAND_LINES[@]}"; }
(( ${#FOOT_LINES[@]} )) && { echo; printf '%s\n' "${FOOT_LINES[@]}"; }

# Legend: explain what each row measures, once, for the tests that actually ran.
declare -A ran=()
for target in "${TARGETS[@]}"; do
  IFS='|' read -r path role <<<"$target"
  for profile in $(profiles_for "$role"); do ran[$profile]=1; done
done
echo
echo "Legend (what each row measures):"
for profile in pgsql-random-rw pgsql-commit-fsync pulp-seq-read pulp-seq-write \
               containers-seq-read; do
  [[ -n "${ran[$profile]:-}" ]] && printf '  %-28s %s\n' "${LABEL[$profile]}" "${MEANING[$profile]}"
done
echo "  Latency is shown as p99 (the slowest 1% of operations); the commit row adds its"
echo "  p50/p90/p95 spread when it needs attention."

# In a guest the per-filesystem explanation is identical, so say it once here.
if [[ "$VIRT" != none ]]; then
  echo
  echo "Note: virtualized guest -- only the commit-latency grade is trustworthy; [INFO]"
  echo "throughput/IOPS can be inflated by host cache (a low one is still a red flag)."
  echo "Ask your admin if the disk bypasses host cache (a 'direct'/'no-cache' mode) and"
  echo "whether it has a burst-vs-baseline model (if so, rerun with --sustained)."
fi

# If two or more target paths resolved to the same physical device, the per-path
# results above are not independent measurements -- say so.
if (( ${#DEV_OF[@]} > 1 )); then
  declare -A paths_on_dev=()
  for path in "${!DEV_OF[@]}"; do
    for dev in ${DEV_OF[$path]}; do paths_on_dev[$dev]+=" $path"; done
  done

  for dev in "${!paths_on_dev[@]}"; do
    if (( $(wc -w <<<"${paths_on_dev[$dev]}") > 1 )); then
      echo
      echo "** Note: these paths share one physical device ($dev):${paths_on_dev[$dev]}"
      echo "   The results above are the SAME disk measured under separate tests,"
      echo "   not two independent storage devices -- and in real use they compete"
      echo "   for that one disk's throughput, IOPS, and latency budget."
    fi
  done
fi

echo
echo "Done. Per-mountpoint JSON reports: /tmp/satellite-storage-benchmark-${STAMP}-*.json"
echo "Results also saved to $LOGFILE (test files cleaned up)."
