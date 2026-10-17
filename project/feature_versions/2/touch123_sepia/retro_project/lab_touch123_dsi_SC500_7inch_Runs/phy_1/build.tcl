if {[catch {source {C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/doc/scripts/DefaultFlow.tcl}} taskError]} {
    puts stderr $taskError
    exit 1
}
set_param bitgen compress on
bitgen -bit lab_touch123_dsi_SC500_7inch.bit
exit
