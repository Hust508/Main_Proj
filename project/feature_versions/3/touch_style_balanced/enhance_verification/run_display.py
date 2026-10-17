from pathlib import Path
import sys,json,hashlib,argparse,time
from sim_backend import compile_and_run
sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent
ap=argparse.ArgumentParser();ap.add_argument('--stall',type=int,default=3500);args=ap.parse_args()
TARGET=ROOT
E=TARGET/'enhance_extension';H=TARGET/'user_source';IP=H/'ip_source'
files=[E/n for n in ('enhance_frame_select.v','enhance_core.v','enhance_window.v','enhance_lut.v','cartoon_packer.v','cartoon_video_in.v','cartoon_video_out.v','cartoon_command_queue.v','cartoon_ddr_bridge.v')]
files +=[IP/'w128_d512_fifo/w128_d512_fifo.v',IP/'w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v',IP/'w155_d512_fifo/w155_d512_fifo.v',IP/'w155_d512_fifo/soft_fifo_al_f58e8b3e1f3d.v',HERE/'enhance_display_tb.sv']
iv='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe';t=time.time()
log=compile_and_run(TARGET,iv,'enhance_display_tb',files,{'REQUIRE_CLEAN':int(not False),'STALL_LEN':args.stall})
result={'test':'display_baseline' if False else 'display_fixed','log':log,'seconds':round(time.time()-t,2),'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_relative_to(ROOT)},'baseline_source_sha256':{str(p.relative_to(TARGET)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_relative_to(TARGET) and TARGET!=ROOT}}
(ROOT/'evidence'/f"{result['test']}_{args.stall}.json").write_text(json.dumps(result,indent=2),encoding='utf-8');print(log,flush=True)
