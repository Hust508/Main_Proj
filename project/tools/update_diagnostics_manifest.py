from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
previous = json.loads((root / 'LATENCY_BUILD_MANIFEST.json').read_text(encoding='utf-8'))
paths = set(previous['files'])
paths.update({
    'tools/update_diagnostics_manifest.py',
    'verification/check_project.py',
    'build_evidence/diagnostics_20261019/synthesis_console.txt',
    'build_evidence/diagnostics_20261019/physical_console.txt',
    'build_evidence/diagnostics_20261019/final_timing.rpt',
    'build_evidence/diagnostics_20261019/final_area.rpt',
})
files = {}
for rel in sorted(paths):
    path = root / rel
    if path.is_file():
        files[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {
    'date': '2026-10-19',
    'version': 'unified-8filters-diagnostics-ui',
    'base_commit': '3402b97',
    'files': files,
}
(root / 'DIAGNOSTICS_BUILD_MANIFEST.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Wrote DIAGNOSTICS_BUILD_MANIFEST.json with {len(files)} files')
