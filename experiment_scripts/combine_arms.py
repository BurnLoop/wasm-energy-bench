#!/usr/bin/env python3
"""
Simply puts all the final ddata form all the 
configurations into one file.
combine_arms.py <out.csv> <arm1_final.csv> <arm2_final.csv> ...
"""
import csv
import sys

if len(sys.argv) < 3:
    sys.exit(__doc__)

out_csv = sys.argv[1]
final_files = sys.argv[2:]

rows = [list(csv.DictReader(open(path)))[0] for path in final_files]

with open(out_csv, 'w', newline='') as f:
    writer = csv.DictWriter(
        f, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)

print(','.join(rows[0].keys()))
for r in rows:
    print(','.join(r.values()))