from app import app
import json

rules = sorted([r.rule for r in app.url_map.iter_rules()])
print(json.dumps(rules, indent=2))
