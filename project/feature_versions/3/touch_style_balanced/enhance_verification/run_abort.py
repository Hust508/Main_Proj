from pathlib import Path
import json,hashlib,sys,argparse,shutil
from sim_backend import compile_and_run
sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;E=ROOT/'enhance_extension'
files=[E/n for n in ('enhance_lut.v','enhance_window.v','enhance_core.v','enhance_frame_select.v')]
files +=[HERE/'enhance_abort_tb.sv']
iv='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
ap=argparse.ArgumentParser();ap.add_argument('--iverilog',default=shutil.which('iverilog') or iv);iv=ap.parse_args().iverilog
log=compile_and_run(ROOT,iv,'enhance_abort_tb',files)
(ROOT/'evidence/abort_result.json').write_text(json.dumps({'test':'enhance_abort','log':log,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2),encoding='utf-8')
print(log)
