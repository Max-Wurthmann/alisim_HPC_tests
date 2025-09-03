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
  # create output directory if it doesn't exist
  mkdir -p $output_dir
  # create data_file if not exists
  if [[ ! -f $data_file ]]; then
    # schema of csv
    echo 'peakRSS_[KiB],runtime_[s],n_procs,n_threads,n_sites,n_taxa,n_alignments,omp_alg,full_command,datetime_of_run' >$data_file
  fi

  # save current datetime
  cur_datetime=$(date)

  # define command to run
  if [[ $n_procs -gt 1 ]]; then
    # MPI version
    cmd=(
      mpirun -np "$n_procs" --allow-run-as-root
      iqtree2-mpi --alisim "$output_dir/alg" -m "$model"
      --length "$n_sites" --num-alignments "$n_alignments"
      -r "$n_taxa"
      -nt "$n_threads"
      --openmp-alg "$omp_alg"
      -redo
    )
  else
    # single process version
    cmd=(
      iqtree2 --alisim "$output_dir/alg" -m "$model"
      --length "$n_sites" --num-alignments "$n_alignments"
      -r "$n_taxa"
      -nt "$n_threads"
      --openmp-alg "$omp_alg"
      -redo
    )
  fi

  # start memory monitor in background
  while true; do
    # Sum RSS of all processes matching iqtree2
    ps -eo pid,rss,comm | awk 'BEGIN {sum = 0} /iqtree2/ {sum += $2} END {print sum}' >>$mem_logfile
    sleep 1
  done &

  # save pid of memory monitor
  pid=$!

  # execute command, logging stdout and stderr to file
  "${cmd[@]}" >$out_logfile 2>>$err_logfile

  # kill memory monitor
  kill -15 $pid

  # calculate peak memory usage
  peakRSS=$(awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}' $mem_logfile)

  # grep runtime from out_logfile
  pattern='Simulation time: '
  runtime=$(grep "$pattern" $out_logfile)
  #cut pattern prefix
  runtime=${runtime#"$pattern"}
  #cut 's' suffix
  runtime=${runtime%s}

  # record data
  # csv format:  peakRSS,runtime,n_procs,n_threads,n_sites,n_taxa,n_alignments,omp_alg,full_command,datetime_of_run
  echo "$peakRSS,$runtime,$n_procs,$n_threads,$n_sites,$n_taxa,$n_alignments,$omp_alg,${cmd[*]},$cur_datetime" >>$data_file
}

# define file names
mem_logfile=memlog.tmp # cleared before each run
out_logfile=outlog.tmp # cleared before each run
err_logfile=err.log
data_file=data.csv
output_dir=output

# n_sites=200000
# n_taxa=6000
n_alignments=48
model='GTR+I{0.2}+G4{0.5}'

# n_procs=1
# n_threads=1
# omp_alg='IM' # other option 'EM', irrelevant for n_threads=1

for omp_alg in 'IM' 'EM'; do
  for size_tuple in '200000 6000' '6000 20000'; do
    read -r n_sites n_taxa <<<"$size_tuple"
    for proc_tuple in '1 16' '2 8' '4 4' '8 2' '16 1'; do
      read -r n_procs n_threads <<<"$proc_tuple"
      run_experimment "$n_sites" "$n_taxa" "$n_alignments" "$model" "$n_procs" "$n_threads" "$omp_alg"
    done
  done
done
