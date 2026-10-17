 set phyWildParams {place pr_strategy 3 place opt_timing high place post_place_opt high}
if {[catch {source {C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/doc/scripts/DefaultFlow.tcl}} taskError]} {
    puts stderr $taskError
    exit 1
}
source ../../../TIMING_RECOVERY.tcl
set_param bitgen compress on
bitgen -bit lab_touch_style_balanced.bit
exit
