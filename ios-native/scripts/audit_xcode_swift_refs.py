#!/usr/bin/env python3
import argparse, os, re, subprocess, json

def parse_pbxproj(path):
    text=open(path,encoding='utf-8').read()
    obj_re=re.compile(r'\t\t([A-F0-9]{24}) /\* .*? \*/ = \{(.*?)\};')
    objs={}
    for m in obj_re.finditer(text):
        oid=m.group(1); body=m.group(2)
        attrs={}
        for part in body.split(';'):
            if ' = ' in part:
                k,v=part.strip().split(' = ',1)
                attrs[k.strip()]=v.strip().strip('"')
        objs[oid]=attrs
    group_blocks=re.finditer(r'\t\t([A-F0-9]{24}) /\* .*? \*/ = \{\n\t\t\tisa = PBXGroup;(.*?)\n\t\t\};',text,re.S)
    groups={}
    for m in group_blocks:
        gid,b=m.group(1),m.group(2)
        path_m=re.search(r'\n\t\t\tpath = (.*?);',b)
        cm=re.search(r'children = \((.*?)\);',b,re.S)
        children=re.findall(r'\b([A-F0-9]{24})\b',cm.group(1)) if cm else []
        groups[gid]={'path':path_m.group(1).strip('"') if path_m else None,'children':children}
    parent={}
    for gid,g in groups.items():
        for c in g['children']: parent[c]=gid
    def group_path(child):
        parts=[]
        gid=parent.get(child)
        while gid:
            p=groups.get(gid,{}).get('path')
            if p: parts.append(p)
            gid=parent.get(gid)
        return list(reversed(parts))
    refs=[]
    for oid,a in objs.items():
        p=a.get('path') or a.get('name')
        if a.get('isa')=='PBXFileReference' and p and p.endswith('.swift'):
            rel=os.path.normpath('/'.join(group_path(oid)+[p]))
            refs.append({'id':oid,'name':os.path.basename(p),'rel':rel,'sourceTree':a.get('sourceTree','')})
    return refs

def main():
    ap=argparse.ArgumentParser()
    script_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    repo_default = os.path.abspath(os.path.join(script_root, '..'))
    ap.add_argument('--repo', default=repo_default)
    ap.add_argument('--pbxproj', default='ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj')
    ap.add_argument('--json',action='store_true')
    args=ap.parse_args()
    repo=os.path.abspath(args.repo)
    pbxproj_path = os.path.join(args.repo, args.pbxproj)
    if not os.path.exists(pbxproj_path) and os.path.basename(args.repo) == 'ios-native':
        pbxproj_path = os.path.join(args.repo, 'AutoInspectorNetwork.xcodeproj/project.pbxproj')
    refs=parse_pbxproj(pbxproj_path)
    tracked=set(subprocess.check_output(['git','-C',args.repo,'ls-files'],text=True).splitlines())
    all_sw=[p for p in subprocess.check_output(['bash','-lc',f'cd {args.repo} && find ios-native -name "*.swift" -type f'],text=True).splitlines() if p]

    missing=[]; abs_refs=[]; outside=[]
    for r in refs:
        if r['rel'].startswith('/') or r['sourceTree']=='<absolute>': abs_refs.append(r['rel'])
        phys=os.path.normpath(os.path.join(args.repo,'ios-native',r['rel']))
        if not os.path.exists(phys):
            candidates=[p for p in all_sw if os.path.basename(p)==r['name']]
            if len(candidates)==1:
                phys=os.path.normpath(os.path.join(args.repo,candidates[0]))
            else:
                missing.append(r['rel'])
        if not os.path.abspath(phys).startswith(repo): outside.append(r['rel'])
    ref_phys=set(os.path.normpath(os.path.join('ios-native',r['rel'])) for r in refs)
    untracked=[f for f in all_sw if f not in tracked]
    orphaned=[r for r in missing]
    from collections import defaultdict
    byname=defaultdict(list)
    for f in all_sw: byname[os.path.basename(f)].append(f)
    dups={k:v for k,v in byname.items() if len(v)>1}

    report={
        'referenced_swift_files':len(refs),
        'missing_files':sorted(missing),
        'orphaned_references':sorted(orphaned),
        'absolute_path_references':sorted(abs_refs),
        'outside_repo_references':sorted(outside),
        'untracked_swift_files':sorted(untracked),
        'duplicate_swift_files':dups,
        'inspector_dashboard_home_view_exists':os.path.exists(os.path.join(args.repo,'ios-native/Features/Dashboard/InspectorDashboardHomeView.swift')),
    }
    if args.json:
        print(json.dumps(report,indent=2))
    else:
        for k,v in report.items(): print(f'{k}: {v}')

if __name__=='__main__': main()
