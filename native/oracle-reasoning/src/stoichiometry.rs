//! Exact supplied-species conservation, not reaction feasibility or chemical identity validation.
//! Element labels and isotope labels (e.g. C-13) denote distinct conserved inventories.
use crate::{Error, Result};
use num_bigint::BigInt;
use num_integer::Integer;
use num_rational::BigRational as Q;
use num_traits::{One, Signed, Zero};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Side {
    Reactant,
    Product,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Species {
    pub name: String,
    pub side: Side,
    /// Positive counts; symbols and isotope labels are separate inventories.
    #[serde(deserialize_with = "unique_composition")]
    pub composition: BTreeMap<String, u64>,
    pub charge: i64,
}
// A normal BTreeMap deserializer silently replaces repeated JSON keys. Reject them
// before information is lost, including duplicates with identical counts.
fn unique_composition<'de, D>(
    deserializer: D,
) -> std::result::Result<BTreeMap<String, u64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    struct UniqueMap;
    impl<'de> serde::de::Visitor<'de> for UniqueMap {
        type Value = BTreeMap<String, u64>;
        fn expecting(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            formatter.write_str("inventory map with unique keys and u64 counts")
        }
        fn visit_map<M>(self, mut map: M) -> std::result::Result<Self::Value, M::Error>
        where
            M: serde::de::MapAccess<'de>,
        {
            let mut result = BTreeMap::new();
            while let Some((key, count)) = map.next_entry::<String, u64>()? {
                if result.insert(key.clone(), count).is_some() {
                    return Err(serde::de::Error::custom(format!(
                        "duplicate inventory: {key}"
                    )));
                }
            }
            Ok(result)
        }
    }
    deserializer.deserialize_map(UniqueMap)
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ReactionInput {
    pub species: Vec<Species>,
}
#[derive(Clone, Debug, Serialize)]
pub struct ChemistryLimits {
    pub species: usize,
    pub conserved_rows: usize,
    pub coefficient_bits: u64,
    pub work: usize,
    pub free_coefficient_bound: u32,
    pub search_candidates: usize,
}
impl Default for ChemistryLimits {
    fn default() -> Self {
        Self {
            species: 32,
            conserved_rows: 128,
            coefficient_bits: 4096,
            work: 1_000_000,
            free_coefficient_bound: 8,
            search_candidates: 4096,
        }
    }
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BalanceStatus {
    UniquePositive,
    NoNonzeroBalance,
    NoStrictlyPositiveBalance,
    MultipleWithPositiveCandidate,
    MultipleSearchInconclusive,
}
#[derive(Clone, Debug, Serialize)]
pub struct ConservationRow {
    pub inventory: String,
    pub reactant: String,
    pub product: String,
}
#[derive(Clone, Debug, Serialize)]
pub struct BalanceOutput {
    pub schema: &'static str,
    pub operation: &'static str,
    pub status: BalanceStatus,
    pub rank: usize,
    pub nullity: usize,
    /// Rational vectors in species order, with one free coordinate equal to one.
    pub nullspace_basis: Vec<Vec<String>>,
    pub free_species_indices: Vec<usize>,
    /// Primitive strictly positive integers in input species order, if found.
    pub coefficients: Option<Vec<String>>,
    pub conservation: Vec<ConservationRow>,
    pub searched_candidates: usize,
    pub free_coefficient_bound: u32,
    pub assurance: &'static str,
}
struct Budget<'a> {
    limits: &'a ChemistryLimits,
    used: usize,
    control: &'a dyn oracle_execution::WorkControl,
}
impl Budget<'_> {
    fn step(&mut self) -> Result<()> {
        crate::checkpoint(self.control, 1)?;
        if self.used >= self.limits.work {
            Err(Error::Limit("stoichiometry arithmetic work"))
        } else {
            self.used += 1;
            Ok(())
        }
    }
    fn integer(&self, n: &BigInt) -> Result<()> {
        if n.bits() > self.limits.coefficient_bits {
            Err(Error::Limit("stoichiometry coefficient bits"))
        } else {
            Ok(())
        }
    }
    fn rational(&self, q: &Q) -> Result<()> {
        self.integer(q.numer())?;
        self.integer(q.denom())
    }
}
fn inventories(input: &ReactionInput, limits: &ChemistryLimits) -> Result<Vec<String>> {
    if input.species.len() < 2 {
        return Err(Error::Invalid("at least two species required".into()));
    }
    if input.species.len() > limits.species {
        return Err(Error::Limit("stoichiometry species"));
    }
    if !input.species.iter().any(|s| s.side == Side::Reactant)
        || !input.species.iter().any(|s| s.side == Side::Product)
    {
        return Err(Error::Invalid("both reaction sides required".into()));
    }
    let elements: BTreeSet<&str> = "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og".split_whitespace().collect();
    let mut labels = BTreeSet::new();
    let mut names = BTreeSet::new();
    for s in &input.species {
        if s.name.trim().is_empty() || s.name.len() > 128 || !names.insert(&s.name) {
            return Err(Error::Invalid(
                "species names must be nonempty, unique and at most 128 bytes".into(),
            ));
        }
        if s.composition.is_empty() && s.charge != -1 {
            return Err(Error::Invalid(
                "empty composition reserved for supplied electron (charge -1)".into(),
            ));
        }
        if s.composition.len() > limits.conserved_rows {
            return Err(Error::Limit("stoichiometry inventories"));
        }
        for (label, count) in &s.composition {
            let (element, isotope) = label
                .split_once('-')
                .map_or((label.as_str(), None), |(e, i)| (e, Some(i)));
            if *count == 0
                || !elements.contains(element)
                || isotope.is_some_and(|i| {
                    i.is_empty()
                        || i.len() > 3
                        || i.starts_with('0')
                        || !i.bytes().all(|b| b.is_ascii_digit())
                })
            {
                return Err(Error::Invalid(format!(
                    "invalid inventory or count: {label}"
                )));
            }
            labels.insert(label.clone());
        }
    }
    labels.insert("charge".into());
    if labels.len() > limits.conserved_rows {
        return Err(Error::Limit("stoichiometry conserved rows"));
    }
    Ok(labels.into_iter().collect())
}
fn amount(s: &Species, label: &str) -> BigInt {
    if label == "charge" {
        BigInt::from(s.charge)
    } else {
        BigInt::from(*s.composition.get(label).unwrap_or(&0))
    }
}
/// Replay only the supplied inventories and coefficients; does not trust the elimination matrix.
/// Requires primitive, strictly positive integers and checks charge even for neutral reactions.
pub fn check_balance(
    input: &ReactionInput,
    coefficients: &[String],
    limits: &ChemistryLimits,
) -> Result<Vec<ConservationRow>> {
    let mut budget = Budget {
        limits,
        used: 0,
        control: &std::sync::atomic::AtomicBool::new(false),
    };
    check_balance_inner(input, coefficients, &mut budget)
}
fn check_balance_inner(
    input: &ReactionInput,
    coefficients: &[String],
    budget: &mut Budget<'_>,
) -> Result<Vec<ConservationRow>> {
    let limits = budget.limits;
    let labels = inventories(input, limits)?;
    if coefficients.len() != input.species.len() {
        return Err(Error::Invalid("coefficient count".into()));
    }
    let mut values = Vec::new();
    let mut gcd = BigInt::zero();
    for text in coefficients {
        if text.len() > (limits.coefficient_bits as usize).saturating_add(1) {
            return Err(Error::Limit("coefficient text"));
        }
        let x = text
            .parse::<BigInt>()
            .map_err(|_| Error::Invalid("integer coefficient required".into()))?;
        budget.integer(&x)?;
        if !x.is_positive() {
            return Err(Error::Invalid(
                "strictly positive coefficients required".into(),
            ));
        }
        gcd = gcd.gcd(&x);
        values.push(x);
    }
    if gcd != BigInt::one() {
        return Err(Error::Invalid("primitive coefficients required".into()));
    }
    let mut rows = Vec::new();
    for label in labels {
        let mut left = BigInt::zero();
        let mut right = BigInt::zero();
        for (s, c) in input.species.iter().zip(&values) {
            budget.step()?;
            let term = amount(s, &label) * c;
            budget.integer(&term)?;
            if s.side == Side::Reactant {
                left += term;
                budget.integer(&left)?;
            } else {
                right += term;
                budget.integer(&right)?;
            }
        }
        if left != right {
            return Err(Error::Check("stoichiometry inventory mismatch"));
        }
        rows.push(ConservationRow {
            inventory: label,
            reactant: left.to_string(),
            product: right.to_string(),
        });
    }
    Ok(rows)
}
fn primitive(v: &[Q], budget: &mut Budget<'_>) -> Result<Option<Vec<String>>> {
    if !(v.iter().all(Q::is_positive) || v.iter().all(Q::is_negative)) {
        return Ok(None);
    }
    let mut scale = BigInt::one();
    for q in v {
        budget.step()?;
        scale = scale.lcm(q.denom());
        budget.integer(&scale)?;
    }
    let mut integers = Vec::new();
    let mut gcd = BigInt::zero();
    for q in v {
        budget.step()?;
        let x = (q.numer() * (&scale / q.denom())).abs();
        budget.integer(&x)?;
        gcd = gcd.gcd(&x);
        integers.push(x);
    }
    Ok(Some(
        integers
            .into_iter()
            .map(|x| (x / &gcd).to_string())
            .collect(),
    ))
}
/// Exact RREF and complete rational nullspace. Bounded rational feasibility
/// closes multidimensional positivity when a witness or Farkas certificate is found. No species are inferred or inserted.
/// Elimination, search and independent replay share a single arithmetic work budget.
pub fn balance_reaction(input: &ReactionInput, limits: &ChemistryLimits) -> Result<BalanceOutput> {
    balance_reaction_controlled(input, limits, &std::sync::atomic::AtomicBool::new(false))
}
pub fn balance_reaction_controlled(
    input: &ReactionInput,
    limits: &ChemistryLimits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<BalanceOutput> {
    let labels = inventories(input, limits)?;
    let n = input.species.len();
    let m = labels.len();
    let mut budget = Budget {
        limits,
        used: 0,
        control,
    };
    let mut a: Vec<Vec<Q>> = labels
        .iter()
        .map(|l| {
            input
                .species
                .iter()
                .map(|s| {
                    let x = amount(s, l);
                    Q::from_integer(if s.side == Side::Reactant { x } else { -x })
                })
                .collect()
        })
        .collect();
    for row in &a {
        for q in row {
            budget.rational(q)?;
        }
    }
    let mut pivots = Vec::new();
    for col in 0..n {
        let rank = pivots.len();
        let Some(p) = (rank..m).find(|&r| !a[r][col].is_zero()) else {
            continue;
        };
        a.swap(rank, p);
        let pivot = a[rank][col].clone();
        for value in &mut a[rank] {
            budget.step()?;
            *value /= &pivot;
            budget.rational(value)?;
        }
        for r in 0..m {
            if r == rank || a[r][col].is_zero() {
                continue;
            }
            let factor = a[r][col].clone();
            let (pivot_row, row) = if r < rank {
                let (head, tail) = a.split_at_mut(rank);
                (&tail[0], &mut head[r])
            } else {
                let (head, tail) = a.split_at_mut(r);
                (&head[rank], &mut tail[0])
            };
            for (value, pivot) in row.iter_mut().zip(pivot_row.iter()).take(n) {
                budget.step()?;
                let term = &factor * pivot;
                budget.rational(&term)?;
                *value -= term;
                budget.rational(value)?;
            }
        }
        pivots.push(col);
    }
    let free: Vec<usize> = (0..n).filter(|c| !pivots.contains(c)).collect();
    let mut basis = Vec::new();
    for &f in &free {
        let mut v = vec![Q::zero(); n];
        v[f] = Q::one();
        for (r, &p) in pivots.iter().enumerate() {
            v[p] = -a[r][f].clone();
        }
        basis.push(v);
    }
    let searched = 0;
    let (status, coefficients) = if basis.is_empty() {
        (BalanceStatus::NoNonzeroBalance, None)
    } else if basis.len() == 1 {
        let c = primitive(&basis[0], &mut budget)?;
        (
            if c.is_some() {
                BalanceStatus::UniquePositive
            } else {
                BalanceStatus::NoStrictlyPositiveBalance
            },
            c,
        )
    } else {
        // Original inventories, not the elimination matrix, define the LP.
        // Each equality is paired inequalities; -x <= -1 requires positivity.
        let mut rows = Vec::new();
        for label in &labels {
            let values: Vec<Q> = input
                .species
                .iter()
                .map(|s| {
                    let x = amount(s, label);
                    Q::from_integer(if s.side == Side::Reactant { x } else { -x })
                })
                .collect();
            for sign in [1i32, -1] {
                rows.push(crate::exact_lp::Row {
                    id: format!("{label}_{sign}"),
                    coefficients: values
                        .iter()
                        .map(|v| (v * Q::from_integer(sign.into())).to_string())
                        .collect(),
                    bound: "0".into(),
                });
            }
        }
        for j in 0..n {
            rows.push(crate::exact_lp::Row {
                id: format!("species_{j}_positive"),
                coefficients: (0..n)
                    .map(|i| if i == j { "-1" } else { "0" }.into())
                    .collect(),
                bound: "-1".into(),
            });
        }
        let problem = crate::exact_lp::Problem {
            variables: (0..n).map(|i| format!("species_{i}")).collect(),
            rows,
            objective: None,
        };
        let lp_limits = crate::exact_lp::Limits {
            variables: limits.species,
            rows: limits
                .conserved_rows
                .saturating_mul(2)
                .saturating_add(limits.species),
            generated_rows: limits.search_candidates,
            bits: limits.coefficient_bits,
            work: limits.work.saturating_sub(budget.used) / 2,
        };
        let result = crate::exact_lp::solve_controlled(&problem, &lp_limits, control)?;
        budget.used = budget.used.saturating_add(lp_limits.work);
        match result.certificate {
            Some(crate::exact_lp::Certificate::Feasible { point }) => {
                let v = point
                    .iter()
                    .map(|text| {
                        text.parse::<Q>()
                            .map_err(|_| Error::Check("linear rational witness"))
                    })
                    .collect::<Result<Vec<_>>>()?;
                (
                    BalanceStatus::MultipleWithPositiveCandidate,
                    primitive(&v, &mut budget)?,
                )
            }
            Some(crate::exact_lp::Certificate::Infeasible { .. }) => {
                (BalanceStatus::NoStrictlyPositiveBalance, None)
            }
            _ => (BalanceStatus::MultipleSearchInconclusive, None),
        }
    };
    let conservation = match &coefficients {
        Some(c) => check_balance_inner(input, c, &mut budget)?,
        None => Vec::new(),
    };
    Ok(BalanceOutput { schema: "oracle-stoichiometry-v1", operation: "chemistry.balance_reaction", status, rank: pivots.len(), nullity: free.len(),
        nullspace_basis: basis.iter().map(|v| v.iter().map(ToString::to_string).collect()).collect(),
        free_species_indices: free, coefficients, conservation, searched_candidates: searched,
        free_coefficient_bound: limits.free_coefficient_bound,
        assurance: "exact rational elimination and bounded exact positivity certificates; positive candidate independently replayed over supplied inventories; no chemical feasibility or integer minimum claim" })
}
