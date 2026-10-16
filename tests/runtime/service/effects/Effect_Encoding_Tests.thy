theory Effect_Encoding_Tests
  imports Veri7vn_Runtime_Effects.Native_Effects_Service
begin
ML \<open>
local
  val nat=Veri7vn_Numerals.nat_of_integer;
  val int=Veri7vn_Numerals.int_of_integer;
  fun bytes raw=map(nat o IntInf.fromInt o Char.ord)(String.explode raw);
  fun string xs= @{code EJString}(map nat xs);
  val valid= @{code effect_json_valid};
  val exact= @{code effect_json_encoding_exact};
  val encoded= @{code effect_json_bytes};
  fun check true _=()|check false message=error message;
  val escaped=string[34,92,10,128,128512];
  val _=check(encoded escaped=map nat [34,92,34,92,92,92,110,92,117,48,48,56,48,240,159,152,128,34])
    "Escaping/Unicode encoder differs from pinned producer";
  val _=check(not(exact true(string[10])(map nat[34,10,34]))) "Unescaped control byte accepted";
  val _=check(not(valid true(string[55296])) andalso not(valid true(string[1114112])))
    "Invalid Unicode scalar accepted";
  val _=check(encoded(@{code EJInt}(int(~2147483648)))=bytes "-2147483648" andalso
    encoded(@{code EJInt}(int 2147483647))=bytes "2147483647") "Signed32 boundary encoding differs";
  val _=check(not(valid true(@{code EJInt}(int 2147483648)))) "Out-of-fragment integer accepted";
  val a=(bytes "a",@{code EJInt}(int 1));
  val b=(bytes "b",@{code EJInt}(int 2));
  val unordered= @{code EJObject}[b,a];
  val _=check(valid false unordered andalso not(valid true unordered)) "Receipt/record order distinction lost";
  val _=check(not(valid false(@{code EJObject}[a,a]))) "Duplicate object key accepted";
  val receipt=unordered;
  val canonical_response= @{code effect_json_normalize}receipt;
  val record= @{code EJObject}[(bytes "response",canonical_response)];
  val _=check(@{code effect_observation_encoding_check}record receipt(encoded record)(encoded receipt))
    "Original receipt order did not match normalized response";
  val _=check(not(@{code effect_observation_encoding_check}record receipt(encoded record)(encoded canonical_response)))
    "Reordered bytes silently replaced original receipt";
  fun nest 0 value=value|nest n value=nest(n-1)(@{code EJArray}[value]);
  val deep=nest 25 @{code EJNull};
  val _=check(not(exact true deep(encoded deep))) "Witness depth bound ignored";
  val long=string(replicate 24577 65);
  val _=check(not(valid true long)) "Encoded-field scalar ceiling ignored";
in val _=writeln "EFFECT_ENCODING unicode_integer_order_bounds PASS" end;
\<close>
end
