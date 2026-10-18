# Run from project/td_project/wb_ui_dsi_Runs/phy_1 after the complete route.
source settings.cfg
import_device $device_name -package $package_name -speed $speed
open_project ${prj_name}.prj -noanalyze
import_db ${prj_name}_pr.db
# The database contains the unchanged original SDC. Apply ONLY the appended
# FIFO CDC block, avoiding any duplicate or cleared IP/user clock definitions.
set sdc_f [open ../../wb_ui_dsi.sdc r]
set sdc_text [read $sdc_f]
close $sdc_f
set marker {# BEGIN PROCESS_DDR_GRAY_CDC}
set idx [string first $marker $sdc_text]
if {$idx < 0} {error "Missing bounded FIFO CDC constraints"}
set runtime_f [open fifo_gray_runtime.sdc w]
puts $runtime_f [string range $sdc_text $idx end]
close $runtime_f
read_sdc fifo_gray_runtime.sdc
update_timing -mode final
report_timing_summary -file ${prj_name}_pr.timing
report_timing_exception -file ${prj_name}_exception.timing
report_area -io_info -file ${prj_name}_phy.area
source ../../../tools/finalize_timing.tcl
export_db ${prj_name}_pr.db
set slacks [final_slacks]
set sw [lindex $slacks 0]
set hw [lindex $slacks 1]
set_param bitgen compress off
bitgen -bit ${prj_name}.bit
set_param bitgen compress on
bitgen -bit ${prj_name}.bit
puts "PASS FINAL BOUNDED_CDC_TIMING: setup $sw ns hold $hw ns"
exit
