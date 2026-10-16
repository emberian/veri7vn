(* A fixed generated checkpoint query, not a reducer or a native constructor.
   The C-authenticated factory supplies the bytes and independently checks source
   ownership, all role hashes and native policy/image before issuing a witness. *)
structure Veri7vn_Native_Scope_Checkpoint =
struct
  structure S=Veri7vn_Native_Scope_Saved;
  structure W=Veri7vn_Native_Authority_Wire;
  fun nat n= Veri7vn_Numerals.nat_of_integer n;
  fun decoded checkpoint =
    let fun convert(W.Atom number)= @{code WireNat}(nat number)
          | convert(W.Node(tag,children))=
              @{code WireNode}(nat(IntInf.fromInt tag),map convert children)
    in @{code decode_checkpoint}(convert(W.read checkpoint))end;
  fun parent_active checkpoint (saved:S.parent)=(case decoded checkpoint of NONE=>false
    | SOME state=> @{code scope_checkpoint_parent_active} state (nat(#request saved)));
  fun matches checkpoint (saved:S.parent) (required:S.required)=
    let
      fun child({identity,predecessors,...}:S.child)=
        (nat(#goal identity),(nat(#slot identity),(nat(#interpretation identity),
          map(nat o #1)predecessors)));
      val children= #children saved;
      fun identity_ok({identity,...}:S.child)= #request identity= #request saved andalso
        forall(fn n=>n>0 andalso size(IntInf.toString n)<=128)
          [#request identity,#goal identity,#slot identity,#interpretation identity,#decision identity];
      fun predecessors_ok _ []=true
        | predecessors_ok seen ((c:S.child)::rest)=
            forall(fn key=>member(op =)seen key)(#predecessors c) andalso
            length(distinct(op =)(#predecessors c))=length(#predecessors c) andalso
            predecessors_ok((#goal(#identity c),#slot(#identity c))::seen)rest;
      val keys=map(fn(c:S.child)=>(#goal(#identity c),#slot(#identity c)))children;
      val shape= #version saved=1 andalso not(null children) andalso length children<=256 andalso
        forall identity_ok children andalso length(distinct(op =)keys)=length keys andalso
        predecessors_ok [] children andalso length(distinct(op =)required)=length required andalso
        forall(fn key=>member(op =)keys key)required;
    in shape andalso (case decoded checkpoint of
      NONE=>false
    | SOME state=> @{code scope_checkpoint_plan_matches} state (nat(#request saved))
        (map child children) (map(fn(gid,slot)=>(nat gid,nat slot))required))
    end;
end;
