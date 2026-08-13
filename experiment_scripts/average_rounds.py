#!/usr/bin/env python3
"""
This script is used for benchmarks that have repeated runs.
It simply averages the results from the rounds.

average_rounds.py <benchmark_label> <out.csv> <round1.csv> <round2.csv> ...
"""

import csv
import sys
from statistics import mean

if len(sys.argv) < 4:
    sys.exit(__doc__)

metrics = (
    'energy_J_per_inv', 'time_s_per_inv', 
    'power_W', 'cpu_pct', 
    'mem_MB'
)

benchmark_name = sys.argv[1]
output_csv_filename = sys.argv[2]
per_round_files = sys.argv[3:]

values = {m: [] for m in metrics}
for path in per_round_files:
    row = list(csv.DictReader(open(path)))[0]
    for m in metrics:
        values[m].append(float(row[m]))

header = ['benchmark', 'rounds']
result = [benchmark_name, len(per_round_files)]
for m in metrics:
    header.append(m)
    result.append(f'{mean(values[m]):.6f}')

with open(output_csv_filename, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerow(result)
