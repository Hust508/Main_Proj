from pathlib import Path
import sys,json,hashlib
from sim_backend import compile_and_run
ROOT=Path(__file__).resolve().parents[1]
iv='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
files=[ROOT/'enhance_extension/enhance_stream_diag.v',Path(__file__).with_name('stream_diag_tb.sv')]
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
log=compile_and_run(ROOT,iv,'stream_diag_tb',files)
(ROOT/'evidence/diag_result.json').write_text(json.dumps({'test':'stream_diag','log':log,'source_sha256':hashes},indent=2),encoding='utf-8')
print(log)
