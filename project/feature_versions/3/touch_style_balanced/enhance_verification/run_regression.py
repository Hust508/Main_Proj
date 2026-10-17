from pathlib import Path
import sys,shutil,time,json,hashlib,argparse
sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent
from sim_backend import compile_and_run
ap=argparse.ArgumentParser();ap.add_argument('--iverilog',default=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe')
args=ap.parse_args()
H=ROOT/'user_source/hdl_source';E=ROOT/'enhance_extension';IP=ROOT/'user_source/ip_source'
fifo=[IP/'w128_d512_fifo/w128_d512_fifo.v',IP/'w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v']
tasks=[
 ('touch_two_cycle_tb',[H/'touch/touch_press_once.v',E/'cartoon_mode_cycle.v']),
 ('touch_bus_tb',[H/'touch/i2c_reg16_byte.v',H/'touch/touch_press_once.v',H/'touch/gt911_touch.v',E/'cartoon_mode_cycle.v']),
 ('i2c_fault_tb',[H/'touch/i2c_reg16_byte.v',H/'touch/touch_press_once.v',H/'touch/gt911_touch.v']),
 ('paxi_order_tb',[E/'cartoon_ddr_bridge.v']),
 ('writer_stream_tb',[E/'cartoon_video_in.v',fifo[1]]),
 ('reader_underflow_tb',[E/'cartoon_video_out.v',*fifo]),
 ('scanout_arbitration_tb',[E/'cartoon_video_in.v',E/'cartoon_video_out.v',*fifo]),
 ('transport_recovery_tb',[E/'cartoon_video_out.v',E/'cartoon_recovery.v',*fifo]),
 ('reader_capacity_tb',[E/'cartoon_video_out.v',*fifo]),

]
results=[]
for top,files in tasks:
    files=[*files,HERE/f'{top}.sv']
    start=time.time()
    output=compile_and_run(ROOT,args.iverilog,top,files)
    result={'test':top,'seconds':round(time.time()-start,2),'log':output,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
    results.append(result)
    (ROOT/'evidence/regression_results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print(output,flush=True)
