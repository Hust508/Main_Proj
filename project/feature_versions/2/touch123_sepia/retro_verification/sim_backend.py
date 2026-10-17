"""Use the standard driver, or direct backend for Windows driver cleanup bugs."""
from pathlib import Path
import subprocess,os,re
def compile_and_run(root,iv,top,sources,parameters=None,plusargs=None,direct=True):
    work=root/'retro_verification/sim_work';work.mkdir(exist_ok=True)
    exe=work/f'{top}_v2.vvp';exe.unlink(missing_ok=True)
    env=dict(os.environ);env['PATH']=str(Path(iv).parent)+os.pathsep+env.get('PATH','')
    if direct:
        lib=Path(iv).resolve().parent.parent/'lib/ivl'
        cfg=work/f'{top}_v2.conf'
        entries=[f'root:{top}',f'basedir:{lib.as_posix()}',f'out:{exe.as_posix()}',
          'generation:2012','generation:assertions','generation:xtypes','generation:icarus-misc','iwidth:32','widthcap:65536']
        entries+=['module:'+(lib/f'{m}.vpi').as_posix() for m in ('system','vhdl_sys','vhdl_textio','v2005_math','va_math','v2009')]
        cfg.write_text('\n'.join(entries)+'\n',encoding='ascii')
        combined='\n'.join(Path(p).read_text(encoding='utf-8-sig',errors='replace') for p in sources)
        if parameters:
            marker=re.search(r'(module\s+'+re.escape(top)+r'\s*;\s*)parameter\s+[^;]+;',combined)
            assert marker,top
            combined=combined[:marker.start()]+marker[1]+'parameter '+','.join(f'{k}={v}' for k,v in parameters.items())+';'+combined[marker.end():]
        joined=work/f'{top}_v2_joined.sv';joined.write_text(combined,encoding='utf-8')
        cmd=[str(lib/'ivl.exe'),'-C',str(cfg),'-C',str(lib/'vvp.conf'),str(joined)]
    else:
        cmd=[iv,'-g2012','-s',top,'-o',str(exe)]
        for k,v in (parameters or {}).items():cmd.append(f'-P{top}.{k}={v}')
        cmd+=list(map(str,sources))
    c=subprocess.run(cmd,cwd=work,env=env,capture_output=True,text=True)
    (work/f'{top}_v2_compile.log').write_text(c.stdout+c.stderr)
    if c.returncode:raise RuntimeError(f'Compile {top} rc={c.returncode}: {c.stdout}{c.stderr}')
    vvp=Path(iv).parent/'vvp.exe' if os.name=='nt' else Path(iv).parent/'vvp'
    c=subprocess.run([str(vvp),str(exe),*(plusargs or [])],cwd=work,env=env,capture_output=True,text=True)
    (work/f'{top}_v2_run.log').write_text(c.stdout+c.stderr)
    if c.returncode or 'PASS' not in c.stdout:raise RuntimeError(f'Run {top} rc={c.returncode}: {c.stdout}{c.stderr}')
    return c.stdout

