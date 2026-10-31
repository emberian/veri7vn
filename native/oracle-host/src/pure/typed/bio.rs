//! Borrowed source replay. No result Value, record copies, or decoded copies.
use super::*;
use oracle_execution::WorkControl;
use sha2::{Digest, Sha256};
fn field(h: &mut Sha256, v: &[u8]) {
    h.update((v.len() as u64).to_le_bytes());
    h.update(v);
}
fn complement(b: u8) -> u8 {
    match b {
        b'A' => b'T',
        b'C' => b'G',
        b'G' => b'C',
        b'T' => b'A',
        b'R' => b'Y',
        b'Y' => b'R',
        b'S' => b'S',
        b'W' => b'W',
        b'K' => b'M',
        b'M' => b'K',
        b'B' => b'V',
        b'D' => b'H',
        b'H' => b'D',
        b'V' => b'B',
        _ => b'N',
    }
}
fn amino(c: &str) -> &'static str {
    match c {
        "TTT" | "TTC" => "F",
        "TTA" | "TTG" | "CTT" | "CTC" | "CTA" | "CTG" => "L",
        "TCT" | "TCC" | "TCA" | "TCG" | "AGT" | "AGC" => "S",
        "TAT" | "TAC" => "Y",
        "TAA" | "TAG" | "TGA" => "*",
        "TGT" | "TGC" => "C",
        "TGG" => "W",
        "CCT" | "CCC" | "CCA" | "CCG" => "P",
        "CAT" | "CAC" => "H",
        "CAA" | "CAG" => "Q",
        "CGT" | "CGC" | "CGA" | "CGG" | "AGA" | "AGG" => "R",
        "ATT" | "ATC" | "ATA" => "I",
        "ATG" => "M",
        "ACT" | "ACC" | "ACA" | "ACG" => "T",
        "AAT" | "AAC" => "N",
        "AAA" | "AAG" => "K",
        "GTT" | "GTC" | "GTA" | "GTG" => "V",
        "GCT" | "GCC" | "GCA" | "GCG" => "A",
        "GAT" | "GAC" => "D",
        "GAA" | "GAG" => "E",
        "GGT" | "GGC" | "GGA" | "GGG" => "G",
        _ => "X",
    }
}

pub(super) fn alignment(s: &Structured<'_>, r: oracle_bio::AlignmentResult) -> CheckedPureReply {
    let c = &r.candidate;
    let valid = r.schema == s.catalog["schema"].as_str().unwrap_or("")
        && r.query_length >= 1
        && r.reference_length >= 1
        && c.score == r.checks.replayed_score
        && c.score == r.checks.independently_computed_optimal_score
        && c.query_start <= c.query_end
        && c.query_end <= r.query_length
        && c.reference_start <= c.reference_end
        && c.reference_end <= r.reference_length;
    if !valid {
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    classification(
        s.id,
        s.identity,
        "integer_alignment_with_independent_score_checks",
        Payload::Alignment(r),
    )
}
pub(super) fn search(
    s: &Structured<'_>,
    input: &oracle_bio::collection::SearchInput,
    r: oracle_bio::collection::SearchResult,
    c: &dyn WorkControl,
) -> CheckedPureReply {
    let mut exhausted = false;
    let valid = (|| -> Option<()> {
        macro_rules! pay {
            ($n:expr) => {
                if c.checkpoint($n as u64).is_err() {
                    exhausted = true;
                    return None;
                }
            };
        }
        pay!(1);
        let mut h = Sha256::new();
        field(&mut h, input.collection.schema.as_bytes());
        h.update((input.collection.records.len() as u64).to_le_bytes());
        for row in &input.collection.records {
            pay!(row
                .label
                .len()
                .saturating_add(row.sequence.len())
                .saturating_add(16));
            field(&mut h, row.label.as_bytes());
            field(&mut h, row.sequence.as_bytes());
        }
        let collection = format!("{:x}", h.finalize());
        let mut h = Sha256::new();
        field(&mut h, b"oracle-sequence-search-v1");
        field(&mut h, collection.as_bytes());
        h.update((input.patterns.len() as u64).to_le_bytes());
        for row in &input.patterns {
            pay!(row
                .label
                .len()
                .saturating_add(row.sequence.len())
                .saturating_add(16));
            field(&mut h, row.label.as_bytes());
            field(&mut h, row.sequence.as_bytes());
        }
        let request = format!("{:x}", h.finalize());
        if r.schema != "oracle-sequence-search-v1"
            || r.collection_sha256 != collection
            || r.request_sha256 != request
            || r.coverage_start != input.cursor
            || r.hits.len() > 1024
            || r.hits.len() > input.page_size
            || (r.complete && r.next_cursor.is_some())
            || (!r.complete && (r.next_cursor.is_none() || r.hits.is_empty()))
        {
            return None;
        }
        let mut previous = None;
        for hit in &r.hits {
            let record = input.collection.records.get(hit.record_index)?;
            let pattern = input.patterns.get(hit.pattern_index)?;
            pay!(pattern.sequence.len().saturating_mul(4).saturating_add(1));
            let forward = pattern.sequence.to_ascii_uppercase();
            let reverse: String = forward
                .bytes()
                .rev()
                .map(|b| complement(b) as char)
                .collect();
            use oracle_bio::collection::Strand;
            let (expected, rank) = match hit.strand {
                Strand::Forward => (&forward, 0),
                Strand::Reverse => (&reverse, 1),
                Strand::Both => (&forward, 2),
            };
            let order = (hit.record_index, hit.start, hit.pattern_index, rank);
            if (hit.strand == Strand::Both) != (forward == reverse)
                || hit.record_label != record.label
                || hit.pattern_label != pattern.label
                || hit.start >= hit.end
                || hit.end.checked_sub(hit.start)? != expected.len()
                || !record
                    .sequence
                    .get(hit.start..hit.end)?
                    .eq_ignore_ascii_case(expected)
                || hit.matched_sequence != *expected
                || previous.is_some_and(|p| p >= order)
            {
                return None;
            }
            previous = Some(order);
        }
        if let Some(cursor) = &r.next_cursor {
            if cursor.request_sha256 != request || Some(cursor) == input.cursor.as_ref() {
                return None;
            }
        }
        Some(())
    })();
    if exhausted {
        return withheld_reply(s.id, "native_reply_check_budget_exhausted", None);
    }
    if valid.is_none() {
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    classification(
        s.id,
        s.identity,
        "exact_supplied_dna_page",
        Payload::Search(r),
    )
}

pub(super) fn translation(
    s: &Structured<'_>,
    input: &oracle_bio::translation::TranslationInput,
    r: oracle_bio::translation::TranslationResult,
    c: &dyn WorkControl,
) -> CheckedPureReply {
    use oracle_bio::translation::{
        AmbiguityPolicy, CodingFeature, CodonMapping, RemainderPolicy, SourceInterval, StopPolicy,
        Strand,
    };
    fn interval(f: &CodingFeature, lo: usize, hi: usize) -> Option<(usize, usize, Strand)> {
        if lo == hi {
            None
        } else {
            Some(if f.strand == Strand::Forward {
                (f.start + lo, f.start + hi, f.strand)
            } else {
                (f.end - hi, f.end - lo, f.strand)
            })
        }
    }
    fn same(actual: &Option<SourceInterval>, expected: Option<(usize, usize, Strand)>) -> bool {
        actual.as_ref().map(|i| (i.start, i.end, i.strand)) == expected
    }
    fn mapping(
        actual: &CodonMapping,
        ci: usize,
        aa: &str,
        codon: &str,
        source: Option<(usize, usize, Strand)>,
    ) -> bool {
        actual.amino_acid_index == ci
            && actual.amino_acid == aa
            && actual.codon == codon
            && Some((actual.source.start, actual.source.end, actual.source.strand)) == source
    }
    let mut exhausted = false;
    let valid = (|| -> Option<()> {
        macro_rules! pay {
            ($n:expr) => {
                if c.checkpoint($n as u64).is_err() {
                    exhausted = true;
                    return None;
                }
            };
        }
        pay!(1);
        if input.source.schema != "oracle-translation-source-v1"
            || input.genetic_code != "ncbi-standard-1-2024-09-23"
            || input.features.is_empty()
            || input.features.len() > 256
            || input.source.records.len() > 256
        {
            return None;
        }
        let mut h = Sha256::new();
        field(&mut h, b"oracle-translation-source-v1");
        h.update((input.source.records.len() as u64).to_le_bytes());
        let mut total = 0usize;
        for row in &input.source.records {
            total = total.checked_add(row.sequence.len())?;
            if total > 131072 {
                return None;
            }
            pay!(row
                .label
                .len()
                .saturating_add(row.sequence.len())
                .saturating_add(16));
            if !row.sequence.bytes().all(|b| {
                if input.ambiguity == AmbiguityPolicy::Reject {
                    b"ACGT".contains(&b.to_ascii_uppercase())
                } else {
                    b"ACGTRYSWKMBDHVN".contains(&b.to_ascii_uppercase())
                }
            }) {
                return None;
            }
            field(&mut h, row.label.as_bytes());
            field(&mut h, row.sequence.as_bytes());
        }
        let source_id = format!("{:x}", h.finalize());
        let mut h = Sha256::new();
        field(&mut h, b"oracle-coding-translation-v1");
        field(&mut h, source_id.as_bytes());
        field(&mut h, input.genetic_code.as_bytes());
        field(
            &mut h,
            &serde_json::to_vec(&(
                input.initiation,
                input.remainder,
                input.stops,
                input.ambiguity,
            ))
            .ok()?,
        );
        h.update((input.features.len() as u64).to_le_bytes());
        if r.translations.len() != input.features.len() {
            return None;
        }
        let mut potential = 0usize;
        let mut examined = 0usize;
        for (fi, (f, t)) in input.features.iter().zip(&r.translations).enumerate() {
            pay!(f.label.len().saturating_add(1));
            field(&mut h, &serde_json::to_vec(f).ok()?);
            let row = input.source.records.get(f.record_index)?;
            let text = row.sequence.as_bytes();
            let span = f.end.checked_sub(f.start)?;
            let length = span.checked_sub(f.frame)?;
            let full = length / 3;
            potential = potential.checked_add(full)?;
            if potential > 16384
                || f.start >= f.end
                || f.end > text.len()
                || f.frame > 2
                || (input.remainder == RemainderPolicy::Reject && length % 3 != 0)
            {
                return None;
            }
            let tf = &t.feature;
            if t.feature_index != fi
                || t.record_label != row.label
                || tf.label != f.label
                || tf.record_index != f.record_index
                || tf.start != f.start
                || tf.end != f.end
                || tf.strand != f.strand
                || tf.frame != f.frame
                || !same(&t.frame_skipped, interval(f, 0, f.frame))
                || !same(&t.trailing_bases, interval(f, f.frame + full * 3, span))
            {
                return None;
            }
            let mut protein = String::new();
            let mut stopped = false;
            for ci in 0..full {
                pay!(4);
                examined = examined.checked_add(1)?;
                let lo = f.frame + 3 * ci;
                let mut bases = [0u8; 3];
                for (j, b) in bases.iter_mut().enumerate() {
                    let i = lo + j;
                    *b = if f.strand == Strand::Forward {
                        text[f.start + i].to_ascii_uppercase()
                    } else {
                        complement(text[f.end - i - 1].to_ascii_uppercase())
                    };
                }
                let codon = std::str::from_utf8(&bases).ok()?;
                let aa = amino(codon);
                if aa == "*" && input.stops == StopPolicy::Reject {
                    return None;
                }
                if aa == "*" && input.stops == StopPolicy::Terminate {
                    if t.codons.len() != ci
                        || !mapping(
                            t.termination_stop.as_ref()?,
                            ci,
                            aa,
                            codon,
                            interval(f, lo, lo + 3),
                        )
                        || !same(&t.untranslated_after_stop, interval(f, lo + 3, span))
                    {
                        return None;
                    }
                    stopped = true;
                    break;
                }
                if !mapping(t.codons.get(ci)?, ci, aa, codon, interval(f, lo, lo + 3)) {
                    return None;
                }
                protein.push_str(aa);
            }
            if (!stopped
                && (t.codons.len() != full
                    || t.termination_stop.is_some()
                    || t.untranslated_after_stop.is_some()))
                || t.protein != protein
            {
                return None;
            }
        }
        if r.schema != "oracle-coding-translation-v1"
            || !r.complete
            || r.source_sha256 != source_id
            || r.request_sha256 != format!("{:x}", h.finalize())
            || r.genetic_code != "ncbi-standard-1-2024-09-23"
            || r.genetic_code_source
                != "https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1"
            || r.initiation != input.initiation
            || r.remainder != input.remainder
            || r.stops != input.stops
            || r.ambiguity != input.ambiguity
            || r.codons_examined != examined
        {
            return None;
        }
        Some(())
    })();
    if exhausted {
        return withheld_reply(s.id, "native_reply_check_budget_exhausted", None);
    }
    if valid.is_none() {
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    classification(
        s.id,
        s.identity,
        "literal_supplied_coding_translation",
        Payload::Translation(r),
    )
}
