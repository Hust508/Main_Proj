from pathlib import Path
import json,hashlib
from sim_backend import compile_and_run
R=Path(__file__).resolve().parents[1]
files=[R/'enhance_extension'/n for n in ('enhance_rgb_async_fifo.v','enhance_clock_bridge.v')]+[Path(__file__).with_name('clock_bridge_tb.sv')]
iv='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
h={str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
log=compile_and_run(R,iv,'clock_bridge_tb',files)
(R/'evidence/clock_bridge_result.json').write_text(json.dumps({'test':'clock_bridge','log':log,'source_sha256':h},indent=2),encoding='utf-8')
print(log)
