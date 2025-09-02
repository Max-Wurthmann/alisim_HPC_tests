#!/bin/bash

run_experimment() {
  n_sites=$1
  n_taxa=$2
  n_alignments=$3
  model=$4

  n_procs=$5
  n_threads=$6
  omp_alg=$7

  echo "Running experiment with $n_sites sites, $n_taxa taxa, $n_alignments alignments, model $model"
  echo "Using $n_procs processes, $n_threads threads per process, OpenMP algorithm $omp_alg"

  # clear tmp logfile if it exists
  rm -f $mem_logfile

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
  cmd=(
    iqtree2 --alisim "$output_dir/alg" -m "$model"
    --length 1 --num-alignments 1
    -r "$n_taxa"
    -nt 1
  )
  tree_file="$output_dir/alg.treefile"

  # save current datetime
  cur_datetime=$(date)

  # start memory monitor in background
  while true; do
    # Sum RSS of all processes matching iqtree2
    ps -eo pid,rss,comm | awk 'BEGIN {sum = 0} /iqtree2/ {sum += $2} END {print sum}' >>$mem_logfile
    sleep 1
  done &

  # save pid of memory monitor
  pid_mem=$!

  # save pids of all background processes
  pids=()

  for ((i = 0; i < "$n_procs"; i++)); do
    out_logfile_i="$logs_dir/outlog$i.tmp"
    err_logfile_i="$logs_dir/err$i.log"

    cmd=(
      iqtree2 --alisim "$output_dir/alg$i" -m "$model"
      --length "$n_sites" --num-alignments "$n_alignments"
      -t "$tree_file"
      -nt "$n_threads"
      --openmp-alg "$omp_alg"
    )

    # execute command asychronously, logging stdout and stderr to file
    "${cmd[@]}" >$out_logfile_i 2>>$err_logfile_i &
    # save process id corresponding to the job that was just started
    pids[i]=$!
  done

  runtime_max=0
  # wait for all background processes to finish and
  # get their runtimes to compute the runtime_max
  for ((i = 0; i < "$n_procs"; i++)); do
    out_logfile_i="$logs_dir/outlog$i.tmp"

    # wait for job to finish
    Wait "${pids[i]}"

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

  # record data
  # csv format:  peakRSS,runtime,n_procs,n_threads,n_sites,n_taxa,n_alignments,omp_alg,full_command,datetime_of_run
  echo "$peakRSS,$runtime_max,$n_procs,$n_threads,$n_sites,$n_taxa,$n_alignments,$omp_alg,${cmd[*]},$cur_datetime" >>$data_file
}

# define file names
mem_logfile=memlog.tmp # cleared before each run
data_file=data.csv
logs_dir=logs
output_dir=output

# n_sites=200000
# n_taxa=6000
n_alignments=48
model='GTR+I{0.2}+G4{0.5}'

# n_procs=1
n_threads=1
omp_alg='IM' # other option 'EM', irrelevant for n_threads=1

for tuple in '200000 6000' '6000 20000'; do
  read -r n_sites n_taxa <<<"$tuple"
  for n_procs in 1 2 4 8 12 16; do
    run_experimment "$n_sites" "$n_taxa" "$n_alignments" "$model" "$n_procs" "$n_threads" "$omp_alg"
  done
done
