use oracle_reasoning::stoichiometry::{
    balance_reaction, check_balance, BalanceStatus as S, ChemistryLimits, ReactionInput,
};
use serde_json::json;
fn input(species: serde_json::Value) -> ReactionInput {
    serde_json::from_value(json!({"species":species})).unwrap()
}
fn solve(species: serde_json::Value, expected: &[&str]) {
    let i = input(species);
    let l = ChemistryLimits::default();
    let out = balance_reaction(&i, &l).unwrap();
    assert_eq!(out.status, S::UniquePositive);
    assert_eq!(
        out.coefficients.as_ref().unwrap(),
        &expected.iter().map(|x| x.to_string()).collect::<Vec<_>>()
    );
    assert!(out.conservation.iter().all(|r| r.reactant == r.product));
    let mut wrong = out.coefficients.unwrap();
    wrong[0] = "99".into();
    assert!(check_balance(&i, &wrong, &l).is_err());
}
#[test]
fn combustion_and_metal_oxidation() {
    solve(
        json!([
            {"name":"ethane","side":"reactant","composition":{"C":2,"H":6},"charge":0},
            {"name":"oxygen","side":"reactant","composition":{"O":2},"charge":0},
            {"name":"carbon dioxide","side":"product","composition":{"C":1,"O":2},"charge":0},
            {"name":"water","side":"product","composition":{"H":2,"O":1},"charge":0}
        ]),
        &["2", "7", "4", "6"],
    );
    solve(
        json!([
            {"name":"iron","side":"reactant","composition":{"Fe":1},"charge":0},
            {"name":"oxygen","side":"reactant","composition":{"O":2},"charge":0},
            {"name":"oxide","side":"product","composition":{"Fe":2,"O":3},"charge":0}
        ]),
        &["4", "3", "2"],
    );
}
#[test]
fn charge_and_supplied_electrons() {
    solve(
        json!([
            {"name":"Fe2+","side":"reactant","composition":{"Fe":1},"charge":2},
            {"name":"Fe3+","side":"product","composition":{"Fe":1},"charge":3},
            {"name":"electron","side":"product","composition":{},"charge":-1}
        ]),
        &["1", "1", "1"],
    );
    solve(
        json!([
            {"name":"permanganate","side":"reactant","composition":{"Mn":1,"O":4},"charge":-1},
            {"name":"proton","side":"reactant","composition":{"H":1},"charge":1},
            {"name":"electron","side":"reactant","composition":{},"charge":-1},
            {"name":"Mn2+","side":"product","composition":{"Mn":1},"charge":2},
            {"name":"water","side":"product","composition":{"H":2,"O":1},"charge":0}
        ]),
        &["1", "8", "5", "1", "4"],
    );
    let i = input(json!([
        {"name":"Fe2+","side":"reactant","composition":{"Fe":1},"charge":2},
        {"name":"Fe3+","side":"product","composition":{"Fe":1},"charge":3}
    ]));
    assert_eq!(
        balance_reaction(&i, &ChemistryLimits::default())
            .unwrap()
            .status,
        S::NoNonzeroBalance
    );
}
#[test]
fn isotope_inventory_is_not_silently_interchangeable() {
    let i = input(json!([
        {"name":"carbon13","side":"reactant","composition":{"C-13":1},"charge":0},
        {"name":"carbon","side":"product","composition":{"C":1},"charge":0}
    ]));
    assert_eq!(
        balance_reaction(&i, &ChemistryLimits::default())
            .unwrap()
            .status,
        S::NoNonzeroBalance
    );
}
#[test]
fn underdetermined_search_and_no_false_impossibility() {
    let i = input(json!([
        {"name":"carbon","side":"reactant","composition":{"C":1},"charge":0},
        {"name":"oxygen","side":"reactant","composition":{"O":2},"charge":0},
        {"name":"CO","side":"product","composition":{"C":1,"O":1},"charge":0},
        {"name":"CO2","side":"product","composition":{"C":1,"O":2},"charge":0}
    ]));
    let mut l = ChemistryLimits::default();
    let out = balance_reaction(&i, &l).unwrap();
    assert_eq!(out.status, S::MultipleWithPositiveCandidate);
    assert_eq!(out.nullity, 2);
    assert_eq!(out.coefficients.unwrap(), vec!["4", "3", "2", "2"]);
    l.search_candidates = 0;
    assert_eq!(
        balance_reaction(&i, &l).unwrap().status,
        S::MultipleSearchInconclusive
    );
}
#[test]
fn zero_required_species_cannot_be_removed_silently() {
    let i = input(json!([
        {"name":"H2","side":"reactant","composition":{"H":2},"charge":0},
        {"name":"H","side":"product","composition":{"H":1},"charge":0},
        {"name":"O2","side":"product","composition":{"O":2},"charge":0}
    ]));
    assert_eq!(
        balance_reaction(&i, &ChemistryLimits::default())
            .unwrap()
            .status,
        S::NoStrictlyPositiveBalance
    );
}
#[test]
fn bad_input_and_budgets() {
    let i = input(json!([
        {"name":"a","side":"reactant","composition":{"H":2},"charge":0},
        {"name":"b","side":"product","composition":{"H":1},"charge":0}
    ]));
    let mut l = ChemistryLimits::default();
    assert!(check_balance(&i, &["0".into(), "0".into()], &l).is_err());
    assert!(check_balance(&i, &["-1".into(), "-2".into()], &l).is_err());
    assert!(check_balance(&i, &["2".into(), "4".into()], &l).is_err());
    l.work = 0;
    assert!(balance_reaction(&i, &l).is_err());
    l = ChemistryLimits::default();
    l.species = 1;
    assert!(balance_reaction(&i, &l).is_err());
    l = ChemistryLimits::default();
    l.coefficient_bits = 1;
    assert!(balance_reaction(&i, &l).is_err());
    let invalid = input(json!([
        {"name":"a","side":"reactant","composition":{"Xx":1},"charge":0},
        {"name":"b","side":"product","composition":{"H":1},"charge":0}
    ]));
    assert!(balance_reaction(&invalid, &ChemistryLimits::default()).is_err());
}
#[test]
fn json_inventory_duplicates_are_rejected_before_map_construction() {
    for composition in [r#"{"O":1,"O":2}"#, r#"{"O":1,"O":1}"#] {
        let text = format!(
            r#"{{"species":[{{"name":"oxygen","side":"reactant","composition":{composition},"charge":0}}]}}"#
        );
        let err = serde_json::from_str::<ReactionInput>(&text).unwrap_err();
        assert!(err.to_string().contains("duplicate inventory"));
    }
}
#[test]
fn blank_names_and_large_unsigned_counts() {
    let mut i = input(json!([
        {"name":"a","side":"reactant","composition":{"H":u64::MAX},"charge":0},
        {"name":"b","side":"product","composition":{"H":1},"charge":0}
    ]));
    let l = ChemistryLimits::default();
    let out = balance_reaction(&i, &l).unwrap();
    assert_eq!(out.coefficients.unwrap(), vec!["1", "18446744073709551615"]);
    assert_eq!(out.schema, "oracle-stoichiometry-v1");
    assert_eq!(out.operation, "chemistry.balance_reaction");
    i.species[0].name = " \t\n".into();
    assert!(balance_reaction(&i, &l).is_err());
    for count in ["18446744073709551616", "-1", "1.5"] {
        let text = format!(
            r#"{{"species":[{{"name":"a","side":"reactant","composition":{{"H":{count}}},"charge":0}}]}}"#
        );
        assert!(serde_json::from_str::<ReactionInput>(&text).is_err());
    }
}
#[test]
fn candidate_replay_shares_solver_work_budget() {
    let i = input(json!([
        {"name":"a","side":"reactant","composition":{"H":2},"charge":0},
        {"name":"b","side":"product","composition":{"H":1},"charge":0}
    ]));
    // RREF: two divisions; primitive conversion: four steps. Replay: four
    // species/inventory products. Each separate phase fits six; composition does not.
    let l = ChemistryLimits {
        work: 6,
        ..ChemistryLimits::default()
    };
    assert!(check_balance(&i, &["1".into(), "2".into()], &l).is_ok());
    assert!(balance_reaction(&i, &l).is_err());
}

#[test]
fn public_json_dispatch_preserves_counts_and_rejects_duplicate_inventories() {
    let request = json!({"operation":"chemistry.balance_reaction", "arguments":{"species":[
        {"name":"large","side":"reactant","composition":{"H":u64::MAX},"charge":0},
        {"name":"unit","side":"product","composition":{"H":1},"charge":0}
    ]}})
    .to_string();
    let reply: serde_json::Value = serde_json::from_str(
        &oracle_reasoning::call(&request, &oracle_reasoning::Limits::default()).unwrap(),
    )
    .unwrap();
    assert_eq!(reply["coefficients"], json!(["1", "18446744073709551615"]));
    let duplicated = request.replace("\"H\":1}", "\"H\":1,\"H\":2}");
    assert_ne!(request, duplicated);
    assert!(oracle_reasoning::call(&duplicated, &oracle_reasoning::Limits::default()).is_err());
}
#[test]
fn positive_balance_beyond_old_free_coefficient_bound() {
    let i = input(json!([
        {"name":"H","side":"reactant","composition":{"H":1},"charge":0},
        {"name":"H-product","side":"product","composition":{"H":1},"charge":0},
        {"name":"H100","side":"reactant","composition":{"H":100},"charge":0}
    ]));
    let l = ChemistryLimits::default();
    let out = balance_reaction(&i, &l).unwrap();
    assert_eq!(out.status, S::MultipleWithPositiveCandidate);
    assert_eq!(
        out.coefficients.as_ref().unwrap(),
        &vec!["1".to_string(), "101".into(), "1".into()]
    );
    assert!(check_balance(&i, out.coefficients.as_ref().unwrap(), &l).is_ok());
}
#[test]
fn multidimensional_impossibility_from_original_rows() {
    let i = input(json!([
        {"name":"hydrogen","side":"reactant","composition":{"H":1},"charge":0},
        {"name":"hydrogen2","side":"product","composition":{"H":2},"charge":0},
        {"name":"hydrogen3","side":"product","composition":{"H":3},"charge":0},
        {"name":"oxygen","side":"product","composition":{"O":1},"charge":0}
    ]));
    let out = balance_reaction(&i, &ChemistryLimits::default()).unwrap();
    assert_eq!(out.nullity, 2);
    assert_eq!(out.status, S::NoStrictlyPositiveBalance);
}
