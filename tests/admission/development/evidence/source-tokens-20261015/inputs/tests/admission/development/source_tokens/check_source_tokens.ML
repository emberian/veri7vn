local
  val keywords=Thy_Header.get_keywords @{theory};
  val utf8=String.implode [Char.chr 206,Char.chr 187];
  val named=String.str(Char.chr 92) ^ "<Rightarrow>";
  val quoted="\"a " ^ named ^ " b\"";
  val cartouche=Symbol.open_ ^ "a " ^ utf8 ^ Symbol.close;
  val original="(* " ^ utf8 ^ " (* nested *) *)\r\nlemma sample: " ^ quoted ^
    " by (simp)\r\n" ^ cartouche;
  fun slice source ({start,stop,...}:Veri7vn_Native_Source_Tokens.located): string = String.substring(source,start,stop-start);
  fun check source =
    let
      val located=Veri7vn_Native_Source_Tokens.tokenize keywords source;
      val _=if implode(map (slice source) located)=source then ()
        else error "Original token bytes changed";
    in located end;
  val located=check original;
  val strings=filter (Token.is_kind Token.String o #token) located;
  val cartouches=filter (Token.is_kind Token.Cartouche o #token) located;
  val _=if map (slice original) strings=[quoted] andalso
    map (slice original) cartouches=[cartouche] then ()
    else error "Token spans exclude original delimiters or miscount symbols";
  val _=List.app (ignore o check)
    ["", "\r", "\r\n", "\n\r\n\r", "  (* comment *)  ",
     "\"a\\\"b\"", String.implode [Char.chr 192,Char.chr 138]];
in
  val _=writeln "native_source_tokens_original_bytes_ok";
end;
