"""Updates reports/optimization/tasks-status.json: one entry per plan task.

Usage: python3 reports/optimization/set_status.py T01 verified "evidence text" ...
The plan's own tasks.json (docs/optimization, gitignored) seeds titles once.
"""
import json, pathlib, sys

here = pathlib.Path(__file__).parent
path = here / 'tasks-status.json'
if path.exists():
    data = json.loads(path.read_text())
else:
    plan = json.loads((here / '../../docs/optimization/tasks.json').read_text())
    data = {'baseline_commit': plan['baseline_commit'], 'tasks': [
        {'id': t['id'], 'stage': t['stage'], 'title': t['title'],
         'conditional': t['conditional'], 'status': 'not_started', 'evidence': []}
        for t in plan['tasks']]}
allowed = {'not_started', 'in_progress', 'verified', 'blocked_external', 'not_applicable'}
if len(sys.argv) >= 3:
    task_id, status, *evidence = sys.argv[1:]
    assert status in allowed, status
    task = next(t for t in data['tasks'] if t['id'] == task_id)
    task['status'] = status
    task['evidence'].extend(evidence)
path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
