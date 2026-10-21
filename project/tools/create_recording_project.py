"""Create isolated TD project files for the TF recording top."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "td_project" / "wb_ui_dsi_Runs"
TARGET = ROOT / "td_project" / "tf_recording_Runs"
base_sdc = (ROOT / "td_project" / "wb_ui_dsi.sdc").read_text(encoding="utf-8")
recording_sdc = re.sub(r"(?<![A-Za-z0-9_/])u_(?=[A-Za-z])", "u_core/u_", base_sdc)
recording_sdc = recording_sdc.replace("{S_display_async_n}", "{u_core/S_display_async_n}")
recording_sdc = recording_sdc.replace("{S_lp_async_n}", "{u_core/S_lp_async_n}")
(ROOT / "td_project" / "tf_recording.sdc").write_text(recording_sdc, encoding="utf-8")
RECORDING_SOURCES = [
    "recording/recording_top.v",
    "recording/tf_avi_recorder.v",
    "recording/sd_card_top.v",
    "recording/sd_card_sec_read_write.v",
    "recording/sd_card_cmd.v",
    "recording/spi_master.v",
]


def source_xml(path: str, order: int) -> str:
    return f'''            <File Path="../../../user_source/hdl_source/{path}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
'''


for run in ("syn_1", "phy_1"):
    source = SOURCE / run / "wb_ui_dsi.prj"
    project = source.read_text(encoding="utf-8")
    if "recording/tf_avi_recorder.v" not in project:
        project = project.replace("        </Verilog>",
                                  "".join(source_xml(name, 201 + i)
                                          for i, name in enumerate(RECORDING_SOURCES[1:])) +
                                  "        </Verilog>", 1)
        source.write_text(project, encoding="utf-8")
    project = project.replace("<Name>wb_ui_dsi</Name>", "<Name>tf_recording</Name>")
    project = project.replace("../../wb_ui_dsi.sdc", "../../tf_recording.sdc")
    project = project.replace("<LABEL>design_top_wrapper</LABEL>", "<LABEL>recording_top</LABEL>")
    project = project.replace("<MODULE>design_top_wrapper</MODULE>", "<MODULE>recording_top</MODULE>")
    project = project.replace("        </Verilog>",
                              source_xml(RECORDING_SOURCES[0], 200) + "        </Verilog>", 1)
    target = TARGET / run
    target.mkdir(parents=True, exist_ok=True)
    (target / "tf_recording.prj").write_text(project, encoding="utf-8")
    settings = (SOURCE / run / "settings.cfg").read_text(encoding="utf-8")
    settings = settings.replace("set prj_name {wb_ui_dsi}", "set prj_name {tf_recording}")
    settings = settings.replace("set top_model_name {design_top_wrapper}",
                                "set top_model_name {recording_top}")
    settings = settings.replace("../../wb_ui_dsi.sdc", "../../tf_recording.sdc")
    (target / "settings.cfg").write_text(settings, encoding="utf-8")
    print(target / "tf_recording.prj")
