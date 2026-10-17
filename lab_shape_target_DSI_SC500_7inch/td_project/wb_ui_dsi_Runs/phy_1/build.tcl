
if {[catch {source {C:/APP2/ALTD/doc/scripts/DefaultFlow.tcl}} taskError]} {

    puts stderr $taskError

    exit 1

}

set_param bitgen compress on
bitgen -bit wb_ui_dsi.bit

exit

