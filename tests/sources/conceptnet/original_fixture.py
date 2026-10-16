#!/usr/bin/env python3
"""Emit a small transient Isabelle fixture from the actual retained local corpus.
No corpus is downloaded or committed. This is an independent test oracle, not an importer.
The deliberately sense-crossing robin/bird/meat path tests source-report scope.
"""
import pathlib, sqlite3, struct, sys
ROOT=pathlib.Path(__file__).resolve().parents[3]
CORPUS=ROOT/'upstream/root/fable-content/oracle-m-series-2026-08-15/m13e5_conceptnet_build_a_v1/conceptnet_specialist.sqlite3'
def cell(v):
    if v is None: return 'Cell_Null'
    if isinstance(v,str): return 'Cell_Text '+nums(v.encode())
    if isinstance(v,float): return 'Cell_RealBits '+nums(struct.pack('>d',v))
    if isinstance(v,int):
        bs=abs(v).to_bytes((abs(v).bit_length()+7)//8,'big')
        return 'Cell_Integer '+('True' if v<0 else 'False')+' '+nums(bs)
    raise ValueError(type(v))
def nums(bs): return '['+','.join(map(str,bs))+']'
def main():
    destination=pathlib.Path(sys.argv[1])
    if not CORPUS.is_file(): raise SystemExit('original ConceptNet corpus unavailable: '+str(CORPUS))
    c=sqlite3.connect(CORPUS.as_uri()+'?mode=ro',uri=True)
    selected=c.execute(
        "SELECT rowid,rel,start,start_pos,end,end_pos,weight,surface_text,dataset FROM edge "
        "WHERE rel=? AND ((start=? AND end=?) OR (end=?)) "
        "ORDER BY end,start,weight,start_pos,end_pos,surface_text,dataset,rel LIMIT 45",
        ('IsA','robin','bird','meat')).fetchall()
    ids=[r[0] for r in selected]
    rows=[r[1:] for r in selected]
    c.close()
    native='['+',\n'.join('['+','.join(cell(v) for v in row)+']' for row in rows)+']'
    destination.write_text('''theory ConceptNet_Original_Fixture
 imports Veri7vn_ConceptNet_Source.ConceptNet_Source Veri7vn_Source_Stream.Source_Row_Stream
begin
external_file "ConceptNet_Original.wire"
external_file "ConceptNet_Original.selection"
text \\<open>Generated local corpus subset; source reports only. The robin/bird/meat
chain deliberately demonstrates why graph reachability cannot assert world IsA.
SQLite rowids used to select this fixture are '''+str(ids)+'''.\\<close>
definition original_subset where "original_subset = Source_Batch 8
'''+native+''' False"
ML \\<open>
 val n= Veri7vn_Numerals.nat_of_integer;
 val wire_path=Path.append (Resources.master_directory @{theory}) (Path.basic "ConceptNet_Original.wire");
 val wire=map (fn c => Veri7vn_Numerals.integer_of_nat (n (IntInf.fromInt (Char.ord c)))) (String.explode (File.read wire_path));
 val batch=(case @{code materialize_source_stream} @{code stream_test_limits} true wire of
    SOME result=>result | NONE=>error "actual ConceptNet producer /2 bytes rejected");
 val _ = if batch= @{code original_subset} then () else error "native /2 rows differ from independent original corpus oracle";
 val reply= @{code run_structured_concept_query}
  (@{code ConceptNetQuery} (n 128,n 128,map n [114,111,98,105,110],map n [109,101,97,116]))
  batch;
 val _ = (case reply of @{code ConceptPath} (_,rows,@{code FeasiblePath}(path,_),false) =>
   if length path=2 andalso length rows=2 then () else error "actual ConceptNet source chain changed"
  | _ => error "actual ConceptNet original subset did not reach checked graph consumer");
 val _ = writeln "VERI7VN_CONCEPTNET actual original corpus subset checked native path PASS";
\\<close>
end
''')
    print(f'Generated {len(rows)} original eight-column source rows at {destination}')
if __name__=='__main__': main()
