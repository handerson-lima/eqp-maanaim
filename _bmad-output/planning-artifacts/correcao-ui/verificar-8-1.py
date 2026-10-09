from pathlib import Path
import subprocess,re,json
root=Path(__file__).resolve().parents[3]
baseline='28955146786a328768535d8ef5473c3271f39e59'
old=subprocess.check_output(['git','show',baseline+':_bmad-output/implementation-artifacts/sprint-status.yaml'],cwd=root,text=True)
new=(root/'_bmad-output/implementation-artifacts/sprint-status.yaml').read_text()
olddev=old.split('development_status:\n')[1].split('action_items:')[0]
assert all(line in new for line in olddev.splitlines() if line.strip()),'Histórico development_status alterado'
assert old.split('action_items:',1)[1]==new.split('action_items:',1)[1],'Action items alterados'
entries=re.findall(r'^  (8-\d+-[^:]+): (.+)$',new,re.M)
assert len(entries)==16 and len(set(k for k,v in entries))==16,entries
assert all(v=='backlog' for k,v in entries if not k.startswith('8-1-')),entries
assert '  epic-8: in-progress' in new
tracked=subprocess.check_output(['git','diff','--name-only',baseline],cwd=root,text=True).splitlines()
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
files=sorted(set(tracked+untracked))
assert all(f.startswith('_bmad-output/') for f in files),files
assert not any(f.endswith('ARCHITECTURE-SPINE.md') for f in files)
for name in ['contrato-visual-ui.md','inventario-dados-ui.md']:
    s=(root/'_bmad-output/planning-artifacts/correcao-ui'/name).read_text()
    assert all(f'S{i:02}' in s for i in range(1,15)),name
broken=[]
for f in files:
    if not f.endswith('.md'): continue
    p=root/f
    for dest in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        dest=dest.split('#')[0].strip('<>')
        if not dest or '://' in dest:continue
        if not (p.parent/dest).exists():broken.append([f,dest])
assert not broken,broken
print(json.dumps({'historico':'preservado','historias_epico8':len(entries),'8.2-8.16':'backlog','arquivos_alterados':len(files),'codigo':'inalterado','ADs':'inalterados','S01-S14':'cobertas','links':'validos'},ensure_ascii=False,indent=2))
