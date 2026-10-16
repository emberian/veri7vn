theory Native_Slice_Reader_Tests
  imports Veri7vn_Runtime_Service.Native_Service
begin
ML \<open>
local
  structure L=Veri7vn_Native_Literals;
  structure Reader=Veri7vn_Native_Language_Input;
  val first="the sum of -2 and 3";
  val second="the product of 4 and 5";
  val blocked="the sum of bad and 3";
  val prefix=String.implode(replicate 300 #"x") ^ "\195\169 ";
  val separator=" | ";
  val raw=prefix ^ first ^ separator ^ second ^ separator ^ blocked;
  val input=L.input{bytes=raw,encoding="UTF-8"};
  val first_start=size prefix;
  val second_start=first_start+size first+size separator;
  val blocked_start=second_start+size second+size separator;
  fun part start text=L.slice input{start=start,stop=start+size text,expected=text};
  val first_slice=part first_start first;
  val second_slice=part second_start second;
  val blocked_slice=part blocked_start blocked;
  val _=if #over_budget(Reader.inspect input) then () else error "Whole input byte budget changed";
  val _=if #alternatives(Reader.inspect_slice first_slice)=[0] andalso
    #alternatives(Reader.inspect_slice second_slice)=[0] then () else error "Scoped questions not independently readable";
  val left=Reader.select_slice first_slice 0;
  val right=Reader.select_slice second_slice 0;
  val _=if L.same_input(Reader.owner left,input) andalso L.same_input(Reader.owner right,input)
    andalso L.offsets(Reader.input_slice left)=L.offsets first_slice then ()
    else error "Reader copied child input or lost parent span";
  val (left_op,a,b,left_literals)=Reader.resolve left;
  val (right_op,c,d,right_literals)=Reader.resolve right;
  val _=(case (left_op,right_op) of (Reader.Sum,Reader.Product)=>()
    | _=>error "Wrong scoped operations");
  val _=if (a,b,c,d)=(~2,3,4,5) andalso map L.original left_literals=["-2","3"]
    andalso map L.original right_literals=["4","5"] then () else error "Scoped literal values changed";
  val _=if map L.offsets left_literals=
    [{start=first_start+11,stop=first_start+13},{start=first_start+18,stop=first_start+19}]
    andalso map L.offsets right_literals=
    [{start=second_start+15,stop=second_start+16},{start=second_start+21,stop=second_start+22}]
    then () else error "Scoped spans are not original UTF-8 byte offsets";
  val _=if Reader.native_expression left aconv @{term "Plus (Rational (-2)) (Rational 3)"}
    then () else error "Native expression consumed surrounding parent bytes";
  val _=if #blocked_literals(Reader.inspect_slice blocked_slice)=
    [[(blocked_start+11,blocked_start+14)]] then () else error "Blocked diagnostic lost parent offset";
  val _=L.invalidate input;
  val _=if is_none(try Reader.native_expression left) andalso is_none(try Reader.resolve right)
    then () else error "Invalidated parent retained child reading access";
  val _=ignore(L.drop_base input);
in val _=writeln "LANGUAGE native_original_slice_reader PASS" end;
\<close>
end
