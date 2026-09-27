#!/usr/bin/env python3
"""Validate the fixed 16-rank Ring AllReduce smoke workload, not arbitrary workloads."""
import collections
import csv
import json
import math
import re
import sys
from pathlib import Path

run = Path(sys.argv[1]).resolve()
flows = list(csv.DictReader((run / 'ncclFlowModel_detailed_flows.csv').open()))
fct = [line.split() for line in (run / 'fct.txt').read_text().splitlines()]
assert flows and len(flows) == len(fct), 'Some generated flows did not finish'
assert all(len(r) == 8 and int(r[6]) > 0 for r in fct), 'Invalid RDMA completion records'
assert {int(r['data_size']) for r in flows} == {1048576, 4194304}
assert {int(r['algorithm']) for r in flows} == {1}, 'Expected Ring algorithm'
assert {int(r['src']) for r in flows} == set(range(16))
expected_bytes = 2 * 15 * (1048576 + 4194304)
assert sum(int(r['flow_size']) for r in flows) == expected_bytes
assert sum(int(r[4]) for r in fct) == expected_bytes
cross = [r for r in flows if int(r['src']) // 8 != int(r['dest']) // 8]
assert cross, 'No inter-server RDMA traffic'
assert collections.Counter(int(r['flow_size']) for r in flows) == collections.Counter(int(r[4]) for r in fct)
log = (run / 'run.log').read_text()
assert 'Percentage of finished streams: 100 %' in log
assert 'Total streams finished: 2' in log
for rank in range(16):
    for verb in ['sent from', 'received by']:
        assert f'All data {verb} node {rank} is 9830400' in log
rows = list(csv.reader((run / 'ncclFlowModel_EndToEnd.csv').open()))
measurements = {}
for row in rows:
    if row and row[0] in ('allreduce_1MiB', 'allreduce_4MiB'):
        us = float(row[8])
        assert math.isfinite(us) and 0 < us < 10000, 'Unexpected smoke latency; check time units'
        measurements[row[0]] = us
assert len(measurements) == 2
summary = {'status':'PASS','ranks':16,'servers':2,'nic_gbps':100,
           'flow_count':len(flows),'completed_rdma_flows':len(fct),
           'inter_server_flow_count':len(cross),'total_flow_bytes':expected_bytes,
           'collective_time_us':measurements,
           'note':'CPU simulation with local send-latency unit fix; not hardware-calibrated.'}
(run / 'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
