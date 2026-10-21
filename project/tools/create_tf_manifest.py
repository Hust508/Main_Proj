"""Record hashes of the TF recorder's source and build artifacts."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixed = [
    "README.md",
    "build_recording.ps1",
    "docs/TF_RECORDING.md",
    "td_project/tf_recording.sdc",
    "td_project/wb_ui_dsi_Runs/syn_1/wb_ui_dsi.prj",
    "td_project/wb_ui_dsi_Runs/phy_1/wb_ui_dsi.prj",
    "tools/create_recording_project.py",
    "tools/create_tf_manifest.py",
    "tools/generate_wb_ui.py",
    "tools/tf_prepare.py",
    "tools/verify_avi.py",
    "tools/wb_ui_overlay.template.v",
    "user_source/constraints_source/pin.adc",
    "user_source/hdl_source/design_top_wrapper.v",
    "user_source/hdl_source/ui/wb_ui_control.v",
    "user_source/hdl_source/ui/wb_ui_font.hex",
    "user_source/hdl_source/ui/wb_ui_font.v",
    "user_source/hdl_source/ui/wb_ui_overlay.v",
    "verification/check_project.py",
    "TF_RECORDING_7inch.bit",
    "TF_RECORDING_7inch_compress.bit",
]
recording = sorted(p.relative_to(root).as_posix() for p in
                   (root / "user_source/hdl_source/recording").iterdir()
                   if p.is_file())
paths = fixed + recording
files = {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
         for name in paths}
manifest = {
    "variant": "tf_recording",
    "tool": "Tang Dynasty 6.2.168116",
    "source_branch": "Yproject",
    "files": files,
}
out = root / "TF_RECORDING_BUILD_MANIFEST.json"
out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {out}: {len(files)} files")
