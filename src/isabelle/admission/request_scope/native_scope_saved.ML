(* Inert original-plan data shared by fixed family recovery codecs. These records
   never construct a Scope or establish a source/identity association. *)
structure Veri7vn_Native_Scope_Saved =
struct
  type identity={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    interpretation:IntInf.int,decision:IntInf.int};
  type source={identity:IntInf.int,encoding:string,bytes:string};
  type span={source:IntInf.int,start:int,stop:int};
  type child={identity:identity,source:span,predecessors:(IntInf.int*IntInf.int)list};
  datatype observation=StateTimeUnused;
  type parent={version:int,workspace:string,request:IntInf.int,
    observation:observation,sources:source list,children:child list};
  (* The full immutable plan remains in parent.children. This list identifies
     only the currently required accessible subset after selective denial. *)
  type required=(IntInf.int*IntInf.int)list;
end;
