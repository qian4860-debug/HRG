from pathlib import Path
import json,re

root=Path(__file__).resolve().parents[2]
expected=json.loads((root/'config/scoreboard_baseline.json').read_text())['build_sha256']
text=(root/'src/hrg_head_config.vh').read_text()
match=re.search(r"HRG_BUILD_SHA256 256'h([0-9a-f]{64})",text)
if not match or match[1]!=expected:
    raise SystemExit('Baseline scoreboard vectors do not describe this RTL build. Use profile-specific verification; do not relabel old vectors as passing the new configuration.')
# A matching ID is insufficient if someone manually edited a generated constant.
import sys
sys.path.insert(0,str(root/'tools'))
import head_config
head_config.active_matches(head_config.validate(head_config.load(root/'config/head_default.json')))
print('SCOREBOARD_BUILD_CONTRACT_PASS')
