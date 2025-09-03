#!/bin/bash

run_experimment() {
  echo "Running experiment with $n_sites sites, $n_taxa taxa, $n_alignments alignments, model $model"
  echo "Using $n_procs processes, $n_threads threads per process, OpenMP algorithm $omp_alg"

  # clear logs and previous output
  rm -f $mem_logfile
  rm -rf $logs_dir
  rm -rf $output_dir

  # create data_file if not exists
  if [[ ! -f $data_file ]]; then
    # schema of csv
    echo 'peakRSS_[KiB],runtime_[s],n_procs,n_threads,n_sites,n_taxa,n_alignments,omp_alg,full_command,datetime_of_run' >$data_file
  fi

  # create logs_dir if not exists
  mkdir -p $logs_dir
  # create output directory if it doesn't exist
  mkdir -p $output_dir

  # run dummy command to sample random tree
  iqtree2 --alisim "$output_dir/alg" -m 'JC' \
    --length 1 --num-alignments 1 \
    -r "$n_taxa" -nt 1 -redo \
    >/dev/null 2>"$logs_dir/err.log"

  tree_file="$output_dir/alg.treefile"

  # save current datetime
  cur_datetime=$(date)

  # start memory monitor in background
  while true; do
    # Sum RSS of all processes matching iqtree2
    ps -eo pid,rss,comm | awk 'BEGIN {sum = 0} /iqtree2/ {sum += $2} END {print sum}' >>$mem_logfile
    sleep $monitor_interval
  done &

  # save pid of memory monitor
  pid_mem=$!

  # save pids of all background processes
  pids=()

  n_algnments_per_proc=$((n_alignments / n_procs))
  remainder=$((n_alignments % n_procs))

  for ((i = 0; i < "$n_procs"; i++)); do
    out_logfile_i="$logs_dir/outlog$i.tmp"
    err_logfile_i="$logs_dir/err$i.log"

    n_alignments_proc_i=$n_algnments_per_proc
    if ((i < remainder)); then
      n_alignments_proc_i=$((n_algnments_per_proc + 1))
    fi

    # execut command in background
    iqtree2 --alisim "$output_dir/alg$i" -m "$model" \
      --length "$n_sites" --num-alignments "$n_alignments_proc_i" \
      -t "$tree_file" \
      -nt "$n_threads" \
      --openmp-alg "$omp_alg" \
      -redo \
      >$out_logfile_i 2>>$err_logfile_i &

    # save process id corresponding to the job that was just started
    pids[i]=$!
  done

  runtime_max=0
  # wait for all background processes to finish and
  # get their runtimes to compute the runtime_max
  for ((i = 0; i < "$n_procs"; i++)); do
    out_logfile_i="$logs_dir/outlog$i.tmp"

    # wait for job to finish
    wait "${pids[i]}"

    # grep runtime from out_logfile
    pattern='Simulation time: '
    runtime=$(grep "$pattern" "$out_logfile_i")
    #cut pattern prefix
    runtime=${runtime#"$pattern"}
    #cut 's' suffix
    runtime=${runtime%s}

    runtime_max=$(echo "$runtime $runtime_max" | awk '{if($1>$2) print $1; else print $2}')
  done

  # kill memory monitor
  kill -15 $pid_mem

  # calculate peak memory usage
  peakRSS=$(awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}' $mem_logfile)

  cmd='manual'

  # record data
  # csv format:  peakRSS,runtime,n_procs,n_threads,n_sites,n_taxa,n_alignments,omp_alg,full_command,datetime_of_run
  echo "$peakRSS,$runtime_max,$n_procs,$n_threads,$n_sites,$n_taxa,$n_alignments,$omp_alg,$cmd,$cur_datetime" >>$data_file
}

# define file names
mem_logfile=memlog.tmp # cleared before each run
logs_dir=logs          # cleared before each run
output_dir=output      # cleared before each run
data_file=data.csv

monitor_interval=0.2 # time between checking memory usage in seconds

n_alignments=48
model='GTR+I{0.2}+G4{0.5}'
long='200000 6000' # (n_sites, n_taxa) pair
deep='6000 200000' # (n_sites, n_taxa) pair

n_threads=1
omp_alg='IM' # other option 'EM', irrelevant for n_threads=1

for size_tuple in "$deep" "$long"; do
  read -r n_sites n_taxa <<<"$size_tuple"
  for n_procs in 1 2 4 8 12 16; do
    run_experimment
  done
done
