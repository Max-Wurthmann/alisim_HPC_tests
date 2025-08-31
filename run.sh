#!/bin/bash

n_sites=1000000
n_taxa=500
n_alignments=10
model='JC'

n_proc=5
n_threads=2
omp_alg='IM' # other option 'EM'

# define file names
mem_logfile=memlog.tmp
out_logfile=outlog.tmp
data_file=data.csv
output_dir=output

# clear tmp logfile if it exists
rm -f $mem_logfile
# create output directory if it doesn't exist
mkdir -p $output_dir
# create data_file if not exists
if [[ ! -f $data_file ]]; then
  # schema of csv
  echo 'peakRSS, runtime, full command, datetime of run' >$data_file
fi

# save current datetime
cur_datetime="$(date)"

# define command to run
if [[ "$n_proc" -gt 1 ]]; then
  # MPI version
  cmd=(
    mpirun -np "$n_proc" --allow-run-as-root
    iqtree2-mpi --alisim "$output_dir/alg" -t "RANDOM{yh/$n_taxa}" -m "$model"
    --length "$n_sites" --num-alignments "$n_alignments"
    -nt "$n_threads"
    --openmp-alg "$omp_alg"
    -redo
  )
else
  # single process version
  cmd=(
    iqtree2 --alisim "$output_dir/alg" -t "RANDOM{yh/$n_taxa}" -m "$model"
    --length "$n_sites" --num-alignments "$n_alignments"
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

# execute command, logging stdout to cmd.log while also printing to console
"${cmd[@]}" | tee $out_logfile

# kill memory monitor
kill -15 $pid

# calculate peak memory usage
peakRSS=$(awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}' $mem_logfile)

# grep runtime from out_logfile
pattern='Simulation time: '
runtime=$(grep "$pattern" $out_logfile)
#cut pattern prefix
runtime="${runtime#$pattern}"

# record data
# csv format: peakRSS, runtime, full command, current date/time
echo "$peakRSS, $runtime, ${cmd[*]}, $cur_datetime" >>$data_file
