"""Compile user-edited Q10 white-balance CSV into synthesizable Verilog."""
from pathlib import Path
import csv
root=Path(__file__).resolve().parent.parent
folder=root/'user_source/hdl_source/wb'
with (folder/'kelvin_gains_demo.csv').open(encoding='utf-8-sig',newline='') as f:
    rows=[(int(r['kelvin']),int(r['r_gain_q10']),int(r['b_gain_q10'])) for r in csv.DictReader(f)]
assert [r[0] for r in rows]==list(range(2500,10001,100)), 'Require all 76 ascending 100K entries'
assert all(512<=r<=3072 and 512<=b<=3072 for _,r,b in rows), 'Q10 gain must be in [512,3072]'
text='// Q10 white-balance gains generated from the supplied calibration CSV.\nmodule wb_gain_lut(input wire [6:0] I_index,output reg [11:0] O_r,O_b);\nalways @(*)begin\ncase(I_index)\n'
for i,(k,r,b) in enumerate(rows):text+=f"7'd{i}:begin O_r=12'd{r};O_b=12'd{b};end // {k} K\n"
text+="default:begin O_r=12'd1024;O_b=12'd1024;end\nendcase\nend\nendmodule\n"
(folder/'wb_gain_lut.v').write_text(text,encoding='utf-8')
print('Compiled 76 white-balance gain entries; rebuild the FPGA project to apply.')
