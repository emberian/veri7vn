import json, re, sys
T = json.load(open('/Users/ember/dev/o7vn/var/audit/thms.json'))
def sym(s):
    rep = {'\\<Longrightarrow>':'==>','\\<longrightarrow>':'-->','\\<longleftrightarrow>':'<->','\\<noteq>':'~=','\\<and>':'&','\\<or>':'|','\\<not>':'~','\\<le>':'<=','\\<ge>':'>=','\\<forall>':'ALL','\\<exists>':'EX','\\<in>':':','\\<notin>':'~:','\\<bar>':'|','\\<Rightarrow>':'=>','\\<lambda>':'%','\\<open>':'<','\\<close>':'>','\\<lparr>':'(|','\\<rparr>':'|)','\\<subseteq>':'<=s','\\<times>':'*','\\<inter>':'Int','\\<union>':'Un','\\<lbrakk>':'[|','\\<rbrakk>':'|]','\\<equiv>':'==','\\<circ>':'o','\\<sharp>':'#'}
    for k,v in rep.items(): s = s.replace(k,v)
    return re.sub(r'\s+',' ',s)
for d in sys.argv[1:]:
    rows = [t for t in T if t['dir'].endswith(d)]
    for t in rows:
        st = sym(t['stmt'])
        st = re.sub(r'^(theorem|lemma|corollary|proposition)\s+','',st)
        pf = sym(t['proof'].split('\n')[0])[:70]
        print(f"{t['file'].split('/')[-1][:-4]}:{t['line']} {st[:420]}  ||{t['plines']}| {pf}")
