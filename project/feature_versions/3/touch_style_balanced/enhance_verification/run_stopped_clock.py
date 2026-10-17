from pathlib import Path
import sys,json,hashlib,argparse,time,shutil
from sim_backend import compile_and_run
sys.stdout.reconfigure(encoding='utf-8')
R=Path(__file__).resolve().parents[1];E=R/'enhance_extension';V=R/'enhance_verification'
ap=argparse.ArgumentParser();ap.add_argument('--baseline',action='store_true');ap.add_argument('--small',action='store_true');ap.add_argument('--tail',type=int,default=38)
ap.add_argument('--iverilog',default=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe');a=ap.parse_args()
top=('stopped_clock_baseline' if a.baseline else 'stopped_clock_fixed')+('_small' if a.small else '_720p')+f'_tail{a.tail}_tb'
b=V/(top+'.sv');b.write_text((V/'stopped_clock_tb.sv').read_text().replace('module stopped_clock_tb;','module '+top+';'),encoding='utf-8')
files=[E/n for n in ('enhance_rgb_async_fifo.v','enhance_clock_bridge.v','enhance_core.v','enhance_lut.v','enhance_window.v','enhance_frame_select.v','cartoon_packer.v','cartoon_video_in.v')]
files +=[R/'user_source/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v',b]
hashes={str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files};t=time.time()
log=compile_and_run(R,a.iverilog,top,files,{'W':1280,'H':8 if a.small else 720,'NEW_CLOCK':int(not a.baseline),'TAIL_CLOCKS':a.tail})
name=('stopped_baseline' if a.baseline else 'stopped_fixed')+('_small' if a.small else '_720p')+f'_tail{a.tail}'
(R/'evidence'/f'{name}.json').write_text(json.dumps({'test':name,'log':log,'seconds':round(time.time()-t,2),'source_sha256':hashes},indent=2),encoding='utf-8')
print(log,flush=True)
