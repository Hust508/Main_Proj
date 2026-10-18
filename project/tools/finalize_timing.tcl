# Adapted from Lproject's TIMING_RECOVERY.tcl. Physical changes only.
# All clock periods, CDC maximum datapath bounds and remaining checks stay active.
proc final_slacks {} {
 global prj_name
 set f [open ${prj_name}_pr.timing r]
 set text [read $f]
 close $f
 if {![regexp {SWNS:\s*(-?[0-9.]+)ns} $text all sw] ||
     ![regexp {HWNS:\s*(-?[0-9.]+)ns} $text all hw]} {
  error "Missing final setup/hold report"
 }
 return [list $sw $hw]
}
set slacks [final_slacks]
if {[lindex $slacks 0] < 0 || [lindex $slacks 1] < 0} {
 puts "FINAL_TIMING: optimizing remaining timed paths: $slacks"
 phys_opt -post_route -effort high
 fix_hold
 update_timing -mode final
 report_timing_summary -file ${prj_name}_pr.timing
 report_timing_exception -file ${prj_name}_exception.timing
 report_area -io_info -file ${prj_name}_phy.area
 report_timing_status -file ${prj_name}_phy.ts
 export_db ${prj_name}_pr.db
}
set slacks [final_slacks]
if {[lindex $slacks 0] < 0 || [lindex $slacks 1] < 0} {
 error "Final timing failed: setup/hold $slacks; bitstream rejected"
}
puts "PASS FINAL_TIMING: setup/hold $slacks ns"
