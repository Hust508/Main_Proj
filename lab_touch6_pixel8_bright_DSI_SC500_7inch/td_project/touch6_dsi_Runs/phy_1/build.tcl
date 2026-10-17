
if {[catch {source {C:/APP2/ALTD/doc/scripts/DefaultFlow.tcl}} taskError]} {

    puts stderr $taskError

    exit 1

}

set_param bitgen compress on
bitgen -bit touch6_dsi.bit

exit

