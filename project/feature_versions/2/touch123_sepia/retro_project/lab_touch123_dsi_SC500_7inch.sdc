create_clock -name {sys_clk_25m} -period 40.000 -waveform {0.000 20.000} [get_ports {I_sys_clk}]
# SC500 720p input clock constraint retained from the supplied HDMI project.
create_clock -name {mipi_rx_ck_pad} -period 4.167 -waveform {0.000 2.083} [get_nets {IO_rx_clk_pad_p}]
derive_clocks
rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {dpll_ref_clk} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
rename_clock -name {pll_clk_10m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[3]}]
rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]
rename_clock -name {MIPI_TX_BYTE_CLK} [get_clocks {u_mipi_dphy_tx_over_ph1p_mipiio_wrapper/u_ph1p_mipiio_tx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_TX.o_fabric_div4_8_clk}]
set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {MIPI_TX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_25m pll_clk_100m pll_clk_24m dpll_ref_clk pll_clk_10m u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]

# Only asynchronous assertion of the new display reset synchronizers is cut.
# Reset release is registered in each destination domain and remains timed.
set_false_path -through [get_nets {S_display_async_n}]
set_false_path -through [get_nets {S_lp_async_n}]

# Touch I2C asynchronous inputs, sampled by two-stage synchronizers.
set_false_path -from [get_ports {IO_touch_scl IO_touch_sda}]
# Bundled-data mailbox: payload is held until the synchronized request ACK.
set_false_path -through [get_nets {u_mode_to_camera/payload[0] u_mode_to_camera/payload[1]}]

# Coordinated recovery reset: asynchronous assertion only into two-stage
# reset synchronizers. Functional reset release paths remain fully timed.
set_false_path -through [get_nets {S_transport_async_n}]

# Diagnostic health inputs are sampled by two flip-flops. Only the six
# first-stage status sampler registers are CDC endpoints. Their second
# stages and all image/transport functional registers remain timed.
set_false_path -to [get_regs -hier -filter {NAME =~ meta* || NAME =~ u_fault_monitor/meta*} {*meta*}]

# Fault snapshot CDC: source payload is held from the triggering DDR edge
# until a later recovery (>=2 ms apart); seq_sync is timed in the SYS domain.
set_false_path -to [get_regs -hier -filter {NAME =~ seq_meta* || NAME =~ u_fault_trace/seq_meta*} {*seq_meta*}]
set_false_path -to [get_regs -hier -filter {NAME =~ sys_trace* || NAME =~ u_fault_trace/sys_trace*} {*sys_trace*}]
