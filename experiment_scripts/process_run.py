#!/usr/bin/env python3
"""
process_run.py <benchmark_name> <num_iterations> <idle.csv> <idle.txt> <run.csv> <run.txt> <out.csv>

num_itearions is for processing runs that use multiple iterations/calls
For example calling, the same benchmark 200 times.
it is used to average the multiple iterations. 
        

Processes the data for a benchmark run. It accounts for
idle background measurements to produce cleanrer resluts.

Creates a csv file with:
enegy_J_per_inv : Energy in joules per invocation
time_s_per_inv: Execution time in seconds per invocation
power_w: Average power over the whole run (for example all 100 invocations)
cpu_pct: Average CPU utilisation over the whole run.
mem_mb: Average memory used over the whole run in MB.

"""
import csv
import os
import re
import sys
from statistics import mean

# Energibridge has an awkward design wehte it
# will output the total energy and time of the run
# to the console only. 
# I route the console output to a file and use this
# regex to capture the energy and time values.
summary_regex = re.compile(r'Energy consumption in joules:\s*([\d.]+)\s*for\s*([\d.]+)\s*sec')

if len(sys.argv) != 8:
    sys.exit(__doc__)

# Name of the benchmark to be written to the final csv file.
benchmark_label = sys.argv[1]
try:
    n = int(sys.argv[2])
    if n < 1:
        raise ValueError
except ValueError:
    sys.exit('error: N should be a positive number')

idle_csv  = sys.argv[3] 
idle_summary_txt  = sys.argv[4]
run_csv  = sys.argv[5]
run_summary_txt = sys.argv[6]
out_csv = sys.argv[7]

# Read the files containing the summary line
summaries = {}
for path in (idle_summary_txt, run_summary_txt):
    if not os.path.exists(path):
        sys.exit(f'error: file does not exist: {path}')
    match = summary_regex.search(
        open(path, errors='ignore').read())
    if not match:
        sys.exit(f'error: no summary data found in file {path}')
    summaries[path] = (float(match.group(1)), float(match.group(2)))

# Read the csv data.
series = {}
for path in (idle_csv, run_csv):
    if not os.path.exists(path):
        sys.exit(f'error: file does not exist: {path}')
    rows = list(csv.DictReader(open(path)))
    num_rows = len(rows)
    if num_rows < 3:
        sys.exit(
            f'error: {path} contians {num_rows} rows, run may have failed,')
   
    # First row is collected before the run starts by EnergiBridge
    # it contains idle state so we drop it..
    series[path] = rows[1:]

# RAPL uses an unsigned 32 bit integer counter under the hood
# This counter in rare cases can overflow and after maximum 
# rollover to 0. 
# I have ssen this mentioned in some GitHub issue tickes
# so check for it just in case.
# https://github.com/tdurieux/energibridge/issues/17
for path in (idle_csv, run_csv):
    energy = [float(row['CPU_ENERGY (J)']) for row in series[path]]
    for i in range(len(energy) - 1):
        if energy[i + 1] < energy[i]:
            sys.exit(f'error: RAPL overflow detected in {path}.'
                     f'Need to repeat this run.')

# Compute mean memory and CPU utilisation
# NOTE: CPU is the utilization percentage of the alloacted CPU resourcesd
# We disable Zen 5c cores so on our system we have 8 alloactd cores/threads
# Apps are signle threaded so expect aroudn 13% utilisation.
means = {}
for path in (idle_csv, run_csv):
    rows = series[path]
    columns = [c for c in rows[0] if c.startswith('CPU_USAGE_')]

    cpu = mean(float(r[c]) for r in rows for c in columns)
    memory = mean(float(r['USED_MEMORY']) for r in rows)
    memory /= 1e6 # in MB

    means[path] = (cpu, memory)


# Compute final metrics
idle_joules, idle_seconds = summaries[idle_summary_txt]
run_joules, run_seconds = summaries[run_summary_txt]
idle_watt = idle_joules / idle_seconds

energy_net_j = run_joules - idle_watt * run_seconds
energy_j = energy_net_j / n
time_s = run_seconds / n
power_w = energy_net_j / run_seconds
cpu_pct = means[run_csv][0] - means[idle_csv][0]
mem_mb = means[run_csv][1] - means[idle_csv][1]

# Write out to csv file.
with open(out_csv, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(
        ['benchmark', 'energy_J_per_inv', 
         'time_s_per_inv', 'power_W',
         'cpu_pct', 'mem_MB'])
    writer.writerow([benchmark_label, f'{energy_j:.6f}', f'{time_s:.6f}',
                 f'{power_w:.3f}', f'{cpu_pct:.3f}', f'{mem_mb:.2f}'])
