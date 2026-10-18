from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
base = json.loads((root / "INTEGRATION_MANIFEST.json").read_text(encoding="utf-8"))
paths = set(base["files"])
paths.update(
    {
        "LATENCY_PROVENANCE.json",
        "tools/update_latency_manifest.py",
        "user_source/hdl_source/frame_latency_meter.v",
        "verification/latency_tb.sv",
        "build_evidence/latency_20261018/synthesis_console.txt",
        "build_evidence/latency_20261018/physical_console.txt",
        "build_evidence/latency_20261018/final_timing.rpt",
        "build_evidence/latency_20261018/final_area.rpt",
    }
)

files = {}
for rel in sorted(paths):
    path = root / rel
    if path.is_file():
        files[rel] = hashlib.sha256(path.read_bytes()).hexdigest()

manifest = {
    "date": "2026-10-18",
    "version": "unified-8filters-original-osd-frame-latency",
    "base_commit": "e5dff82",
    "files": files,
}
(root / "LATENCY_BUILD_MANIFEST.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(f"Wrote LATENCY_BUILD_MANIFEST.json with {len(files)} files")
