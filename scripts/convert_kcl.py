#!/usr/bin/env python3
import yaml
import sys

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)

items = data.get('items', [])
for item in items:
    print('---')
    print(yaml.dump(item, default_flow_style=False), end='')
