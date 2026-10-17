from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


project = ROOT / "td_project" / "wb_ui_dsi.al"
text = project.read_text(encoding="utf-8-sig")
inputs: set[Path] = {project, ROOT / "td_project" / "wb_ui_dsi.sdc"}
for item in re.findall(r'\bPath="([^"]+)"', text):
    if item == ".":
        continue
    candidate = (project.parent / item).resolve()
    if candidate.is_file() and ROOT in candidate.parents:
        inputs.add(candidate)

for item in [
    "build.ps1",
    "td_project/wb_ui_dsi_Runs/syn_1/settings.cfg",
    "td_project/wb_ui_dsi_Runs/syn_1/wb_ui_dsi.prj",
    "td_project/wb_ui_dsi_Runs/phy_1/settings.cfg",
    "td_project/wb_ui_dsi_Runs/phy_1/wb_ui_dsi.prj",
    "tools/generate_wb_ui.py",
    "tools/wb_ui_overlay.template.v",
]:
    inputs.add(ROOT / item)

input_hashes = {relative(path): digest(path) for path in sorted(inputs)}
(ROOT / "BUILD_INPUTS_SHA256.json").write_text(
    json.dumps(
        {
            "date": "2026-10-18",
            "target": "PH1P35MDG324 speed 3",
            "td_version": "6.2.1",
            "files": input_hashes,
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)

delivery = set(inputs)
for item in [
    "BUILD_INPUTS_SHA256.json",
    "BUILD_REPORT.md",
    "README.md",
    "DSI_UNIFIED_SC500_7inch.bit",
    "DSI_UNIFIED_SC500_7inch_compress.bit",
    "build_evidence/integrated_synthesis_console.txt",
    "build_evidence/integrated_physical_console.txt",
    "build_evidence/integrated_final_timing.rpt",
    "build_evidence/integrated_final_area.rpt",
    "verification/check_project.py",
    "verification/filter_bank_tb.sv",
    "verification/run_sim.ps1",
    "verification/ui_test.sv",
]:
    delivery.add(ROOT / item)

delivery_hashes = {relative(path): digest(path) for path in sorted(delivery)}
(ROOT / "BUILD_MANIFEST.json").write_text(
    json.dumps(
        {
            "date": "2026-10-18",
            "target": "PH1P35MDG324",
            "hardware_verified": False,
            "updated_simulation_executed": False,
            "td_flow_passed": True,
            "setup_slack_ns": 0.013,
            "hold_slack_ns": 0.021,
            "files": delivery_hashes,
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)

(ROOT / "SOURCE_PROVENANCE.json").write_text(
    json.dumps(
        {
            "date": "2026-10-18",
            "repository": "https://github.com/Hust508/Main_Proj.git",
            "integration_branch": "Yproject",
            "sources": {
                "Hproject": "d49e7f8",
                "Yproject": "cca8107",
                "main_before_merge": "dfc0631",
            },
            "policy": "Hproject UI and camera controls are primary; Yproject image-style work is integrated through a unified filter bank.",
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)

print(f"Wrote {len(input_hashes)} build-input hashes and {len(delivery_hashes)} delivery hashes")
