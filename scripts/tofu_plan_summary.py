#!/usr/bin/env python3
import sys
import json
from collections import defaultdict

def main():
    if sys.stdin.isatty():
        print("Error: Expected 'tofu show -json plan.binary' output on stdin.")
        sys.exit(1)

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Error: Input is not valid JSON. Run with: tofu show -json <plan_file> | python3 script.py")
        sys.exit(1)

    if 'resource_changes' not in data:
        print("**Plan:** No resources analyzed. Infrastructure is likely up-to-date.")
        sys.exit(0)

    changes = defaultdict(list)
    stats = {'create': 0, 'update': 0, 'delete': 0, 'replace': 0}

    for res in data['resource_changes']:
        actions = res.get('change', {}).get('actions', [])
        
        address = res.get('address', '')
        
        if 'no-op' in actions and len(actions) == 1:
            continue
            
        if 'create' in actions and 'delete' in actions:
            changes['replace'].append(address)
            stats['replace'] += 1
        elif 'create' in actions:
            changes['create'].append(address)
            stats['create'] += 1
        elif 'delete' in actions:
            changes['delete'].append(address)
            stats['delete'] += 1
        elif 'update' in actions:
            changes['update'].append(address)
            stats['update'] += 1

    total_changes = sum(stats.values())
    
    if total_changes == 0:
        print("### 🌈 OpenTofu Plan Summary")
        print("\n**Plan:** No changes. Infrastructure is up-to-date.")
        sys.exit(0)

    print("### 🏗️ OpenTofu Plan Summary\n")
    print(f"**Plan:** 🟢 {stats['create']} to add, 🟡 {stats['update']} to change, 🔴 {stats['delete']} to destroy, 🔄 {stats['replace']} to replace\n")

    if changes['create']:
        print("#### 🟢 Added")
        for addr in changes['create']:
            print(f"- `{addr}`")
        print("")

    if changes['update']:
        print("#### 🟡 Changed")
        for addr in changes['update']:
            print(f"- `{addr}`")
        print("")

    if changes['replace']:
        print("#### 🔄 Replaced")
        for addr in changes['replace']:
            print(f"- `{addr}`")
        print("")

    if changes['delete']:
        print("#### 🔴 Destroyed")
        for addr in changes['delete']:
            print(f"- `{addr}`")
        print("")

if __name__ == "__main__":
    main()
