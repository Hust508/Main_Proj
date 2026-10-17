from pathlib import Path
import json,hashlib,time
from sim_backend import compile_and_run
ROOT=Path(__file__).resolve().parents[1];H=ROOT/'user_source/hdl_source/touch'
files=[H/n for n in ('i2c_reg16_byte.v','touch_press_once.v','gt911_touch.v')]
files +=[ROOT/'enhance_extension/cartoon_mode_cycle.v',Path(__file__).with_name('touch_bus_tb.sv')]
iv='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
start=time.time();hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
log=compile_and_run(ROOT,iv,'touch_bus_tb',files)
p=ROOT/'evidence/regression_results.json';results=json.loads(p.read_text(encoding='utf-8'))
results=[{'test':'touch_bus_tb','log':log,'seconds':round(time.time()-start,2),'source_sha256':hashes} if t['test']=='touch_bus_tb' else t for t in results]
p.write_text(json.dumps(results,indent=2),encoding='utf-8');print(log)
