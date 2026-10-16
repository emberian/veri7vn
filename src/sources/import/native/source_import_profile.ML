(* The only parser is generated from the native decoder above. Scala acquisition
   preserves raw bytes and supplies a candidate, never pre-decoded authoritative rows. *)
structure Veri7vn_Source_Row_Codec : VERI7VN_TYPED_BULK_CODEC
  where type value = Native_Source_Import.source_cell list
    and type batch = Native_Source_Import.source_batch =
struct
  type value = Native_Source_Import.source_cell list;
  type batch = Native_Source_Import.source_batch;
  type error = string;
  datatype decoded = Decoded of batch | Rejected of error;
  fun length batch = List.length (Native_Source_Import.batch_rows batch);
  fun sub batch i = nth (Native_Source_Import.batch_rows batch) i;
  fun encode batch = (case Native_Source_Import.encode_wire_checked batch of
      NONE => error "source.non_wellformed_batch"
    | SOME wire => Word8Vector.fromList (map (Word8.fromInt o IntInf.toInt) wire));
  fun decode {max_bytes, max_elements} wire =
    if max_bytes < 0 orelse max_elements < 0 orelse Word8Vector.length wire > max_bytes
    then Rejected "source.materialization_limit"
    else (case Native_Source_Import.decode_wire_bounded (IntInf.fromInt max_bytes) (IntInf.fromInt max_elements)
      (Word8Vector.foldr (fn (b, bs) => IntInf.fromInt (Word8.toInt b) :: bs) [] wire) of
        Native_Source_Import.Source_Malformed => Rejected "source.malformed_rows"
      | Native_Source_Import.Source_Bytes_Bound => Rejected "source.materialization_limit"
      | Native_Source_Import.Source_Rows_Bound => Rejected "source.materialization_limit"
      | Native_Source_Import.Source_Decoded batch => Decoded batch);
end;

structure Veri7vn_Source_Import_Profile =
struct
  structure R = Veri7vn_Native_Registry;
  structure P = Veri7vn_Native_Profiles;
  fun declare generation registry =
    let
      val (law, r1) = R.insert generation "sources.row-codec-roundtrip"
        (R.Theorem @{thm wire_codec_roundtrip}) registry;
      val (sound, r2) = R.insert generation "sources.row-decoder-sound"
        (R.Theorem @{thm decode_wire_sound}) r1;
      val (bounded, r3) = R.insert generation "sources.bounded-decoder-association"
        (R.Theorem @{thm bounded_decoder_association}) r2;
      val (entry, registry') = R.insert generation "sources.actual-bounded-decoder"
        (R.Certified @{cterm decode_wire_bounded}) r3;
      val profile = P.declare generation {
        carrier = @{typ source_batch}, representation = SOME @{cterm decode_wire_bounded},
        numeric = P.Exact, shape = @{cterm "\<lambda>b::source_batch. snapshot_wellformed (batch_snapshot b)"},
        scope = P.Partial {covered = @{cterm "\<lambda>b::source_batch. set (batch_rows b)"},
          missing = @{cterm "\<lambda>b::source_batch. \<not> complete_materialization (batch_snapshot b)"}},
        literal_policy = "source-row/1 exact bytes; schema encoding; SQL NULL distinct; ordered duplicate rows; explicit prefix flag",
        display_projection = NONE, materialization_limit = SOME 65536, dependencies = [law,sound,bounded,entry]};
    in (profile, registry') end;
end;


(* A proposal binds actual immutable raw bytes to the actual generated decoder
   result and its privately created exact family profile. It is not acceptance,
   source truth or a source-publication token. No callback can mint a candidate. *)
signature VERI7VN_SOURCE_IMPORT_CANDIDATES =
sig
  type decoder
  type candidate
  datatype result = Prepared of candidate | Rejected of string
  val create: Veri7vn_Native_Registry.generation -> Veri7vn_Native_Registry.registry ->
    decoder * Veri7vn_Native_Registry.registry
  val prepare: decoder -> {max_bytes:int,max_elements:int} -> Word8Vector.vector -> result
  val release: candidate -> unit
  val release_decoder: decoder -> unit
  val is_live: candidate -> bool
  val raw: candidate -> Word8Vector.vector
  val profile: decoder -> Veri7vn_Native_Profiles.declaration
  val batch: Veri7vn_Native_Registry.generation -> decoder -> candidate -> Veri7vn_Source_Row_Codec.batch
end;
structure Veri7vn_Source_Import_Candidates :> VERI7VN_SOURCE_IMPORT_CANDIDATES =
struct
  structure R = Veri7vn_Native_Registry;
  structure P = Veri7vn_Native_Profiles;
  datatype decoder = Decoder of (R.generation * P.declaration) option Unsynchronized.ref;
  datatype candidate = Candidate of (R.generation * P.declaration * Word8Vector.vector * Veri7vn_Source_Row_Codec.batch) option Unsynchronized.ref;
  datatype result = Prepared of candidate | Rejected of string;
  fun create generation registry =
    let val (profile, registry') = Veri7vn_Source_Import_Profile.declare generation registry
    in (Decoder (Unsynchronized.ref (SOME (generation, profile))), registry') end;
  fun retained_decoder (Decoder state) =
    (case !state of SOME value => value | NONE => error "Source decoder released");
  fun retained_candidate (Candidate state) =
    (case !state of SOME value => value | NONE => error "Source candidate released");
  fun release (Candidate state) = state := NONE;
  fun release_decoder (Decoder state) = state := NONE;
  fun is_live (Candidate state) = is_some (!state);
  fun profile decoder = #2 (retained_decoder decoder);
  fun prepare decoder limits raw =
    let val (generation, profile) = retained_decoder decoder in
      (case Veri7vn_Source_Row_Codec.decode limits raw of
        Veri7vn_Source_Row_Codec.Rejected reason => Rejected reason
      | Veri7vn_Source_Row_Codec.Decoded batch => Prepared (Candidate (Unsynchronized.ref (SOME (generation,profile,raw,batch)))))
    end;
  fun raw candidate = #3 (retained_candidate candidate);
  fun batch generation decoder candidate =
    let val (owner,p) = retained_decoder decoder;
        val (actual,q,_,value) = retained_candidate candidate
    in if R.same_generation (generation, owner) andalso R.same_generation (owner,actual)
      andalso P.same_declaration (p,q) then value
    else error "Source candidate decoder/generation association mismatch" end;
end;
