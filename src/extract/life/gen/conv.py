import sys,re
src=open(sys.argv[1],encoding='utf-8').read()
def esc(body):
    out=[]
    for b in body.encode('utf-8'):
        c=chr(b)
        if c=='\\': out.append('\\\\')
        elif c=='"': out.append('\\"')
        elif b<32 or b>126: out.append('\\%03d'%b)
        else: out.append(c)
    return '"'+''.join(out)+'"'
res=re.sub(r'⟦(.*?)⟧',lambda m:esc(m.group(1)),src,flags=re.S)
open(sys.argv[2],'w').write(res)
