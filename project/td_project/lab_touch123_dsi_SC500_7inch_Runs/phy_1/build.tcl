
if {[catch {source {C:/APP2/ALTD/doc/scripts/DefaultFlow.tcl}} taskError]} {

    puts stderr $taskError

    exit 1

}

set_param bitgen compress on
bitgen -bit lab_touch123_dsi_SC500_7inch.bit

exit

