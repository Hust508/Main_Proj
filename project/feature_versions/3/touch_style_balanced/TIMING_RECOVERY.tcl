# Run in the existing physical-design process after DefaultFlow, before the
# final bitgen. Changes physical placement/routing only, never SDC constraints.
set recovery_f [open ${prj_name}_pr.timing r]
set recovery_report [read $recovery_f]
close $recovery_f
if {![regexp {SWNS:\s*(-?[0-9.]+)ns} $recovery_report recovery_all recovery_wns] || ![regexp {HWNS:\s*(-?[0-9.]+)ns} $recovery_report recovery_all recovery_hwns]} {
    error "Missing final setup/hold timing"
}
if {$recovery_wns < 0} {
    puts "TIMING_RECOVERY: post-route high effort for SWNS ${recovery_wns}ns"
    phys_opt -post_route -effort high
}
if {$recovery_wns < 0 || $recovery_hwns < 0} {
    puts "TIMING_RECOVERY: repair hold, then recheck both setup and hold"
    fix_hold
    update_timing -mode final
    export_db ${prj_name}_pr.db
    report_area -io_info -file ${prj_name}_phy.area
    report_timing_status -file ${prj_name}_phy.ts
    report_timing_summary -file ${prj_name}_pr.timing
    report_timing_exception -file ${prj_name}_exception.timing
}
set recovery_f [open ${prj_name}_pr.timing r]
set recovery_report [read $recovery_f]
close $recovery_f
if {![regexp {SWNS:\s*(-?[0-9.]+)ns} $recovery_report recovery_all recovery_wns] || ![regexp {HWNS:\s*(-?[0-9.]+)ns} $recovery_report recovery_all recovery_hwns]} {
    error "Missing final setup/hold timing after optimization"
}
if {$recovery_wns < 0 || $recovery_hwns < 0} {
    error "Timing failed: setup ${recovery_wns}ns, hold ${recovery_hwns}ns. Bitstream rejected."
}
puts "TIMING_PASS: setup ${recovery_wns}ns hold ${recovery_hwns}ns"
