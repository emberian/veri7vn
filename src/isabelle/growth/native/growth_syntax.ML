structure Veri7vn_Growth_Syntax =
struct
  fun require true _=() | require false message=error message;
  fun number term=IntInf.fromInt(snd(HOLogic.dest_number term));
  fun rational term =
    (case term of Const(name,_) $ a $ b =>
      if name = @{const_name Fract} then
        let val n=number a;val d=number b
        in if d=0 then (0,1) else (n,d) end
      else error "Growth rational requires a literal or Fract"
    | Const(name,_) $ a =>
      if name = @{const_name uminus} then
        let val(n,d)=rational a in (~n,d) end
      else (number term,1)
    | _ => (number term,1));
  fun natural term=let val n=number term
    in require(n>=0 andalso n<=4096) "Growth parameter/power bound";() end;
  fun expression depth term =
    (require(depth<=64) "Growth expression depth bound";
     case strip_comb term of
       (Const(name,_),[q]) =>
         if name = @{const_name Rational} then (rational q;())
         else if name = @{const_name Parameter} then natural q
         else if member(op =)[@{const_name Negate},@{const_name Absolute}]name
           then expression(depth+1)q else error "Unsupported growth expression constructor"
     | (Const(name,_),[a,b]) =>
         if name = @{const_name Power} then (expression(depth+1)a;natural b)
         else if member(op =)[@{const_name Plus},@{const_name Times},@{const_name Divide}]name
           then (expression(depth+1)a;expression(depth+1)b)
         else error "Unsupported growth expression constructor"
     | _=>error "Growth expression must use installed constructors");
  fun bindings term =
    let val entries=HOLogic.dest_list term
      val _=require(length entries<=128) "Growth sample binding bound"
      val _=List.app(fn entry=>let val(n,q)=HOLogic.dest_prod entry
        in natural n;ignore(rational q) end)entries
    in () end;
end;
