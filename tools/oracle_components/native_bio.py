"""Untrusted supplied-DNA adapter; native checks establish supplied sequence computations.

The host supplies a fixed catalog and call closure. This module never imports a
caller-selected extension and infers no homology or biological significance.
"""
from __future__ import annotations
import hashlib
import json
import re
from .native_science import NativeStructuredOperations, obj, string, positive_limits, array


class NativeBioOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity):
        super().__init__(catalog, call, identity)
        limits = positive_limits(catalog, ("request_bytes", "sequence_bases", "dp_cells", "working_bytes_estimate"))
        operations = catalog.get("operations")
        if (catalog.get("schema") != "oracle-bio-experimental-v1" or not isinstance(operations, list)
                or not any(isinstance(row, dict) and row.get("id") == "bio.align_pairwise" for row in operations)):
            raise ValueError("unsupported bio catalog")
        sequence = {**string(limits["sequence_bases"]), "pattern": "^[ACGTRYSWKMBDHVNacgtryswkmbdhvn]+$"}
        integer = lambda lo, hi: {"type": "integer", "minimum": lo, "maximum": hi}
        scoring = obj({"match_score": integer(1, 1000), "mismatch_score": integer(-1000, 0),
                       "gap_open": integer(-1000, -1), "gap_extend": integer(-1000, -1)})
        schema = obj({"query": sequence, "reference": sequence,
                      "mode": {"type": "string", "enum": ["global", "local", "query_global"]},
                      "scoring": scoring, "ambiguity": {"type": "string", "enum": ["reject", "always_mismatch"]}},
                     ["query", "reference", "mode", "scoring"])
        self.add("bio.align_pairwise", schema,
                 "Align two supplied DNA strings with explicit affine-gap scoring, then independently replay the path and recompute the optimal score.",
                 {"query": "ACGT", "reference": "ACGT", "mode": "global",
                  "scoring": {"match_score": 2, "mismatch_score": -1, "gap_open": -3, "gap_extend": -1}},
                 ["Gap run length k scores gap_open + (k-1)*gap_extend; require gap_open <= gap_extend. One optimal path is returned; tied paths need not be unique.",
                  "Global consumes both sequences; local may return an empty zero-score path; query_global consumes the entire query with free reference-end clipping.",
                  "DNA letters only, case insensitive; no U, whitespace, gaps or FASTA. Ambiguity defaults to reject. With always_mismatch every non-ACGT letter scores as mismatch, including N versus N.",
                  "Coordinates are zero-based half-open in supplied forward orientation; insertion consumes query and deletion consumes reference. No reverse-complement search, homology, variant interpretation, diagnostic or design claim.",
                  "Native admission checks sequence lengths, DP cells, estimated memory, mode, scoring and ambiguity before alignment allocation. Memory estimate excludes allocator metadata and process RSS; native alignment is not interruptible."])
        self.declarations["bio.align_pairwise"]["output_schema"]["anyOf"][0]["properties"]["result"]["description"] = (
            "Complete native candidate path, supplied scoring/mode, coordinates and independent score checks; no biological interpretation.")

        collection = catalog.get("sequence_collection")
        if any(isinstance(row, dict) and row.get("id") == "bio.search_collection" for row in operations):
            if not isinstance(collection, dict) or collection.get("schema") != "oracle-sequence-collection-v1":
                raise ValueError("unsupported sequence collection catalog")
            record = obj({"label": string(256, 0), "sequence": {**string(131072, 0), "pattern": "^[ACGTacgt]*$"}})
            pattern = obj({"label": string(256, 0), "sequence": {**string(4096), "pattern": "^[ACGTacgt]+$"}})
            cursor = obj({"request_sha256": {**string(64), "pattern": "^[0-9a-f]{64}$"},
                          "record": integer(0, 255), "start": integer(0, 131071), "offset": integer(0, 256)})
            schema = obj({"collection": obj({"schema": {"const": "oracle-sequence-collection-v1"},
                           "records": array(record, 256)}), "patterns": array(pattern, 128, 1),
                          "page_size": integer(1, 1024), "cursor": cursor}, ["collection", "patterns", "page_size"])
            self.add("bio.search_collection", schema,
                     "Find exact supplied fragments in either DNA strand with original coordinates and bounded pages.",
                     {"collection": {"schema": "oracle-sequence-collection-v1", "records": [{"label": "sample", "sequence": "AAACGT"}]},
                      "patterns": [{"label": "fragment", "sequence": "ACG"}], "page_size": 100},
                     ["ACGT only, case insensitive; ambiguity and empty patterns rejected. Empty records allowed; no FASTA parsing or circular wrap.",
                      "Overlaps count. Duplicate labels and duplicate patterns retain distinct input indices. Reverse complement palindromes count once with strand both.",
                      "Order is record index, original start, pattern index, strand. Cursor binds original ordered input bytes and patterns; page_size may change.",
                      "Complete means this cursor's remaining suffix was exhausted. Full absence requires starting without cursor and consuming all pages. Resource refusal establishes no absence.",
                      "One immutable normalized collection and shared pattern trie per batch; no retained global registry. Typed callers may reuse SequenceCollection across batches.",
                      "131072 collection bases, 256 records, 128 patterns, 4096 total pattern bases, 1024 hits per page, 16777216 charged trie transitions; JSON byte cap also applies.",
                      "Exact traversal is handwritten untrusted computation. No alignment score, homology or biological interpretation follows."])

        translation = catalog.get("coding_translation")
        if any(isinstance(row, dict) and row.get("id") == "bio.translate_coding_intervals" for row in operations):
            if (not isinstance(translation, dict) or translation.get("schema") != "oracle-coding-translation-v1"
                    or translation.get("source_schema") != "oracle-translation-source-v1"
                    or translation.get("genetic_code") != TRANSLATION_CODE_ID
                    or any(translation.get(k) != v for k, v in {"source_bases":131072,"records":256,"features":256,"potential_codons":16384,"label_bytes":256}.items())):
                raise ValueError("unsupported coding translation catalog")
            record = obj({"label": string(256, 0), "sequence": {**string(131072, 0), "pattern": "^[ACGTRYSWKMBDHVNacgtryswkmbdhvn]*$"}})
            feature = obj({"label": string(256, 0), "record_index":integer(0,255),"start":integer(0,131071),
                           "end":integer(1,131072),"strand":{"type":"string","enum":["forward","reverse"]},"frame":integer(0,2)})
            schema = obj({"source":obj({"schema":{"const":"oracle-translation-source-v1"},"records":array(record,256)}),
                          "features":array(feature,256,1),"genetic_code":{"const":TRANSLATION_CODE_ID},
                          "initiation":{"const":"literal_codon"},"remainder":{"type":"string","enum":["reject","drop"]},
                          "stops":{"type":"string","enum":["include","terminate","reject"]},
                          "ambiguity":{"type":"string","enum":["reject","unknown"]}})
            self.add("bio.translate_coding_intervals",schema,
                     "Translate explicitly supplied coding intervals and map each literal standard-code amino acid to its original source codon.",
                     {"source":{"schema":"oracle-translation-source-v1","records":[{"label":"supplied","sequence":"CATGGGCAT"}]},
                      "features":[{"label":"declared interval","record_index":0,"start":0,"end":9,"strand":"reverse","frame":0}],
                      "genetic_code":TRANSLATION_CODE_ID,"initiation":"literal_codon","remainder":"reject","stops":"include","ambiguity":"reject"},
                     ["The NCBI standard table 1 September 23 2024 ordinary codon assignments are explicit assumptions; only this named table is supported. No initiation recoding, ORF selection or gene inference.",
                      "Each feature names a record ordinal and original zero-based half-open interval. Frame skips 0..2 bases from its oriented 5-prime end; reverse codon intervals descend in original coordinates.",
                      "Remainder reject refuses incomplete codons before stop handling; drop retains omitted coordinates. Stop include emits *, terminate retains the excluded stop and untranslated suffix, reject refuses encountered stops.",
                      "Ambiguity reject requires all supplied source bases to be ACGT; unknown gives X for every ambiguous codon, including GCN and TAR. IUPAC reverse complement is preserved; no U, gaps, whitespace or FASTA.",
                      "131072 source bases, 256 records/features, 256 UTF-8 bytes/label and 16384 potential codons summed before termination. Resource failure returns no partial completion.",
                      "PreparedTranslationSource shares immutable normalized source across caller-owned typed batches. HTTP calls rebuild source. No global registry; source/request hashes bind original bytes, ordered features and policies.",
                      "Complete means every feature processed under its declared policies, including deliberate stop truncation. Returned maps independently replayed by this untrusted adapter; no protein function or Isabelle claim."])
            self.declarations["bio.translate_coding_intervals"]["sources"] = [{"name":"NCBI standard genetic code table 1, Sep 23 2024 snapshot", "url":TRANSLATION_CODE_SOURCE}]

    def invoke(self, operation, arguments):
        translation_expected = None
        if operation == "bio.translate_coding_intervals":
            try:
                translation_expected = translation_reference(arguments)
            except (KeyError, TypeError, ValueError, IndexError, OverflowError):
                return self.withheld(operation, "invalid_arguments")
        # JSON Schema uses a portable regex subset. Python re.search('$') also
        # accepts a final newline, unlike the host's Rust regex. Native alphabet
        # admission remains authoritative; fullmatch closes this adapter gap.
        if operation == "bio.search_collection":
            try:
                records = arguments["collection"]["records"]
                patterns = arguments["patterns"]
                if (any(re.fullmatch(r"[ACGTacgt]*", row["sequence"]) is None for row in records)
                        or any(re.fullmatch(r"[ACGTacgt]+", row["sequence"]) is None for row in patterns)
                        or (arguments.get("cursor") is not None and re.fullmatch(r"[0-9a-f]{64}", arguments["cursor"]["request_sha256"]) is None)):
                    return self.withheld(operation, "invalid_arguments")
            except (KeyError, TypeError):
                return self.withheld(operation, "invalid_arguments")
        elif operation == "bio.align_pairwise":
            if any(not isinstance(arguments.get(k), str) or re.fullmatch(r"[ACGTRYSWKMBDHVNacgtryswkmbdhvn]+", arguments[k]) is None for k in ("query", "reference")):
                return self.withheld(operation, "invalid_arguments")
        reply = super().invoke(operation, arguments)
        if operation == "bio.translate_coding_intervals" and reply.get("status") == "answered":
            try:
                check_translation_reply(arguments, reply["result"], translation_expected)
            except (KeyError, TypeError, ValueError, IndexError):
                return self.withheld(operation, "native_reply_invalid")
            return reply
        if operation != "bio.search_collection" or reply.get("status") != "answered":
            return reply
        result = reply["result"]
        def require(condition):
            if not condition:
                raise ValueError("native search reply mismatch")
        try:
            collection_id, request_id = search_identities(arguments)
            require(result["collection_sha256"] == collection_id and result["request_sha256"] == request_id)
            require(result["coverage_start"] == arguments.get("cursor"))
            require(len(result["hits"]) <= arguments["page_size"])
            previous = None
            for hit in result["hits"]:
                ri, pi = hit["record_index"], hit["pattern_index"]
                require(type(ri) is int and 0 <= ri < len(arguments["collection"]["records"]))
                require(type(pi) is int and 0 <= pi < len(arguments["patterns"]))
                record, pattern = arguments["collection"]["records"][ri], arguments["patterns"][pi]
                forward = pattern["sequence"].upper()
                reverse = forward.translate(str.maketrans("ACGT", "TGCA"))[::-1]
                strand = hit["strand"]
                expected = forward if strand in ("forward", "both") else reverse
                require((strand == "both") == (forward == reverse))
                require(hit["record_label"] == record["label"] and hit["pattern_label"] == pattern["label"])
                start, end = hit["start"], hit["end"]
                require(type(start) is int and type(end) is int and 0 <= start < end <= len(record["sequence"]))
                require(end-start == len(expected) and record["sequence"][start:end].upper() == expected == hit["matched_sequence"])
                order = (ri, start, pi, {"forward": 0, "reverse": 1, "both": 2}[strand])
                require(previous is None or previous < order)
                previous = order
            cursor = result["next_cursor"]
            if cursor is not None:
                require(cursor["request_sha256"] == request_id)
                require(all(type(cursor[k]) is int and cursor[k] >= 0 for k in ("record", "start", "offset")))
                require(cursor != arguments.get("cursor"))
        except (AssertionError, KeyError, TypeError, ValueError, IndexError):
            return self.withheld(operation, "native_reply_invalid")
        return reply

    def interpret(self, operation, result):
        if operation == "bio.translate_coding_intervals":
            if (result.get("schema") != "oracle-coding-translation-v1" or result.get("complete") is not True
                    or not isinstance(result.get("translations"), list) or not 1 <= len(result["translations"]) <= 256
                    or type(result.get("codons_examined")) is not int or not 0 <= result["codons_examined"] <= 16384):
                return self.withheld(operation, "native_reply_invalid")
            return self.answered(operation, result, "literal_supplied_coding_translation")
        if operation == "bio.search_collection":
            if (result.get("schema") != "oracle-sequence-search-v1" or type(result.get("complete")) is not bool
                    or not isinstance(result.get("hits"), list) or len(result["hits"]) > 1024
                    or any(not isinstance(hit, dict) or hit.get("strand") not in ("forward", "reverse", "both") for hit in result["hits"])
                    or (result["complete"] and result.get("next_cursor") is not None)
                    or (not result["complete"] and (not isinstance(result.get("next_cursor"), dict) or not result["hits"]))):
                return self.withheld(operation, "native_reply_invalid")
            return self.answered(operation, result, "exact_supplied_dna_page")
        candidate, checks = result.get("candidate"), result.get("checks")
        if (result.get("schema") != self.native_catalog["schema"] or not isinstance(candidate, dict)
                or not isinstance(checks, dict) or type(candidate.get("score")) is not int
                or type(checks.get("replayed_score")) is not int
                or type(checks.get("independently_computed_optimal_score")) is not int
                or candidate["score"] != checks["replayed_score"]
                or candidate["score"] != checks["independently_computed_optimal_score"]
                or not isinstance(candidate.get("operations"), list)
                or any(edit not in ("match", "substitution", "insertion", "deletion") for edit in candidate["operations"])
                or result.get("mode") not in ("global", "local", "query_global")
                or result.get("ambiguity") not in ("reject", "always_mismatch")
                or any(type(result.get(k)) is not int or result[k] < 1 for k in ("query_length", "reference_length"))):
            return self.withheld(operation, "native_reply_invalid")
        for prefix in ("query", "reference"):
            start, end = candidate.get(prefix + "_start"), candidate.get(prefix + "_end")
            if type(start) is not int or type(end) is not int or not 0 <= start <= end <= result[prefix + "_length"]:
                return self.withheld(operation, "native_reply_invalid")
        return self.answered(operation, result, "integer_alignment_with_independent_score_checks")


def search_identities(arguments):
    """Native length-prefixed identity encoding; original source bytes retained."""
    def field(h, text):
        raw = text.encode("utf-8")
        h.update(len(raw).to_bytes(8, "little")); h.update(raw)
    collection = arguments["collection"]
    h = hashlib.sha256(); field(h, collection["schema"])
    h.update(len(collection["records"]).to_bytes(8, "little"))
    for record in collection["records"]:
        field(h, record["label"]); field(h, record["sequence"])
    collection_id = h.hexdigest()
    h = hashlib.sha256(); field(h, "oracle-sequence-search-v1"); field(h, collection_id)
    h.update(len(arguments["patterns"]).to_bytes(8, "little"))
    for record in arguments["patterns"]:
        field(h, record["label"]); field(h, record["sequence"])
    return collection_id, h.hexdigest()

TRANSLATION_CODE_ID = "ncbi-standard-1-2024-09-23"
TRANSLATION_CODE_SOURCE = "https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1"
_TRANSLATION_GROUPS = {"F":"TTT TTC","L":"TTA TTG CTT CTC CTA CTG","S":"TCT TCC TCA TCG AGT AGC",
    "Y":"TAT TAC","*":"TAA TAG TGA","C":"TGT TGC","W":"TGG","P":"CCT CCC CCA CCG",
    "H":"CAT CAC","Q":"CAA CAG","R":"CGT CGC CGA CGG AGA AGG","I":"ATT ATC ATA","M":"ATG",
    "T":"ACT ACC ACA ACG","N":"AAT AAC","K":"AAA AAG","V":"GTT GTC GTA GTG",
    "A":"GCT GCC GCA GCG","D":"GAT GAC","E":"GAA GAG","G":"GGT GGC GGA GGG"}
_TRANSLATION_CODE = {codon:aa for aa,codons in _TRANSLATION_GROUPS.items() for codon in codons.split()}


def translation_reference(arguments):
    """Bounded independent literal codon/source replay, not a proof or backend."""
    def require(test):
        if not test:
            raise ValueError("invalid translation input")
    def compact(value):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    def field(h, text):
        raw = text.encode(); h.update(len(raw).to_bytes(8, "little")); h.update(raw)
    require(isinstance(arguments, dict) and set(arguments) == {"source","features","genetic_code","initiation","remainder","stops","ambiguity"})
    require(arguments["genetic_code"] == TRANSLATION_CODE_ID and arguments["initiation"] == "literal_codon")
    require(arguments["remainder"] in ("reject","drop") and arguments["stops"] in ("include","terminate","reject") and arguments["ambiguity"] in ("reject","unknown"))
    source = arguments["source"]; features = arguments["features"]
    require(isinstance(source, dict) and set(source) == {"schema","records"} and source["schema"] == "oracle-translation-source-v1")
    records = source["records"]
    require(isinstance(records, list) and len(records) <= 256 and isinstance(features, list) and 1 <= len(features) <= 256)
    total = 0; normalized = []; h = hashlib.sha256(); field(h, source["schema"])
    h.update(len(records).to_bytes(8, "little"))
    alphabet = r"[ACGTacgt]*" if arguments["ambiguity"] == "reject" else r"[ACGTRYSWKMBDHVNacgtryswkmbdhvn]*"
    for record in records:
        require(isinstance(record, dict) and set(record) == {"label","sequence"} and isinstance(record["label"], str) and isinstance(record["sequence"], str))
        total += len(record["sequence"])
        require(total <= 131072 and len(record["label"].encode()) <= 256 and re.fullmatch(alphabet, record["sequence"]) is not None)
        field(h, record["label"]); field(h, record["sequence"]); normalized.append(record["sequence"].upper())
    source_id = h.hexdigest(); h = hashlib.sha256(); field(h, "oracle-coding-translation-v1"); field(h, source_id)
    field(h, arguments["genetic_code"]); field(h, compact([arguments[k] for k in ("initiation","remainder","stops","ambiguity")]))
    h.update(len(features).to_bytes(8, "little")); potential = 0
    for feature in features:
        require(isinstance(feature, dict) and set(feature) == {"label","record_index","start","end","strand","frame"})
        require(isinstance(feature["label"], str) and len(feature["label"].encode()) <= 256)
        require(all(type(feature[k]) is int for k in ("record_index","start","end","frame")))
        ri, start, end, frame = (feature[k] for k in ("record_index","start","end","frame"))
        require(0 <= ri < len(records) and feature["strand"] in ("forward","reverse"))
        require(0 <= start < end <= len(normalized[ri]) and 0 <= frame <= min(2,end-start))
        length = end-start-frame
        require(arguments["remainder"] == "drop" or length % 3 == 0)
        potential += length//3; require(potential <= 16384)
        field(h, compact({k:feature[k] for k in ("label","record_index","start","end","strand","frame")}))
    result = []; examined = 0
    complement = str.maketrans("ACGTRYSWKMBDHVN", "TGCAYRSWMKVHDBN")
    for fi, feature in enumerate(features):
        text = normalized[feature["record_index"]][feature["start"]:feature["end"]]
        if feature["strand"] == "reverse":
            text = text.translate(complement)[::-1]
        def interval(lo, hi):
            if lo == hi:
                return None
            start, end = ((feature["start"]+lo, feature["start"]+hi) if feature["strand"] == "forward"
                          else (feature["end"]-hi, feature["end"]-lo))
            return {"start":start,"end":end,"strand":feature["strand"]}
        frame = feature["frame"]; full = (len(text)-frame)//3
        protein = ""; codons = []; termination = None; after = None
        for ci in range(full):
            lo = frame+3*ci; codon = text[lo:lo+3]; aa = _TRANSLATION_CODE.get(codon, "X"); examined += 1
            mapping = {"amino_acid_index":ci,"amino_acid":aa,"codon":codon,"source":interval(lo,lo+3)}
            require(not (aa == "*" and arguments["stops"] == "reject"))
            if aa == "*" and arguments["stops"] == "terminate":
                termination = mapping; after = interval(lo+3,len(text)); break
            protein += aa; codons.append(mapping)
        result.append({"feature_index":fi,"feature":feature,"record_label":records[feature["record_index"]]["label"],
            "protein":protein,"codons":codons,"frame_skipped":interval(0,frame),"trailing_bases":interval(frame+full*3,len(text)),
            "termination_stop":termination,"untranslated_after_stop":after})
    return source_id, h.hexdigest(), result, examined


def check_translation_reply(arguments, result, expected):
    """Retain provenance, coverage and original coordinates, including omissions."""
    source_id, request_id, translations, examined = expected
    if (result.get("source_sha256") != source_id or result.get("request_sha256") != request_id
            or result.get("genetic_code") != TRANSLATION_CODE_ID or result.get("genetic_code_source") != TRANSLATION_CODE_SOURCE
            or any(result.get(k) != arguments[k] for k in ("initiation","remainder","stops","ambiguity"))
            or result.get("translations") != translations or type(result.get("codons_examined")) is not int
            or result["codons_examined"] != examined):
        raise ValueError("source-bound translation mismatch")
    for feature in result["translations"]:
        if type(feature["feature_index"]) is not int or any(type(feature["feature"][k]) is not int for k in ("record_index","start","end","frame")):
            raise ValueError("translation ordinal type")
        mappings = feature["codons"] + ([feature["termination_stop"]] if feature["termination_stop"] is not None else [])
        for mapping in mappings:
            if type(mapping["amino_acid_index"]) is not int or any(type(mapping["source"][k]) is not int for k in ("start","end")):
                raise ValueError("codon coordinate type")
        for interval in (feature["frame_skipped"],feature["trailing_bases"],feature["untranslated_after_stop"]):
            if interval is not None and any(type(interval[k]) is not int for k in ("start","end")):
                raise ValueError("omitted interval type")
