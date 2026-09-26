#!/usr/bin/env python3
"""Records a V2 task's status and evidence in tasks.json.

  python3 design/experience-v2/set_task.py U02 in_progress \
      --code "..." --layout "..." --design "..." --device "..."

Statuses: not_started, in_progress, verified, blocked_external,
not_applicable. The four evidence kinds stay separate; a missing kind is
left untouched. accepted_by_user is only ever set by --user-accepted with
the user's own words, never inferred."""
import argparse, json, pathlib

path = pathlib.Path(__file__).with_name('tasks.json')
parser = argparse.ArgumentParser()
parser.add_argument('task')
parser.add_argument('status', choices=[
    'not_started', 'in_progress', 'verified', 'blocked_external',
    'not_applicable'])
for kind in ('code', 'layout', 'design', 'device'):
    parser.add_argument(f'--{kind}')
parser.add_argument('--user-accepted')
args = parser.parse_args()
data = json.loads(path.read_text())
task = next(t for t in data['tasks'] if t['id'] == args.task)
task['status'] = args.status
for kind in ('code', 'layout', 'design', 'device'):
    value = getattr(args, kind)
    if value is not None:
        task['evidence'][kind] = value
task.setdefault('accepted_by_user', 'pending')
if args.user_accepted:
    task['accepted_by_user'] = args.user_accepted
path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
print(args.task, args.status)
