//! Independent scalar contracts. These are executable checks, not proof claims.
use oracle_runtime_core::value::{
    CalendarYear, ComparisonOp, Era, ExactNumber, GregorianDate, Quantity, TypedValue, UnitPolicy,
    ValueComparison, ValueKind, ValueLimits,
};
use serde_json::json;

fn number(text: &str) -> ExactNumber {
    ExactNumber::parse(text, &ValueLimits::default()).unwrap()
}

fn literal(text: &str, kind: ValueKind) -> TypedValue {
    TypedValue::parse_literal(text, kind, &ValueLimits::default()).unwrap()
}

#[test]
fn decimal_digits_and_ratios_remain_exact() {
    assert_eq!(number("0.1"), number("1/10"));
    assert_eq!(number("-2.50e+2"), number("-250"));
    assert_eq!(number("+.125"), number("1/8"));
    assert_eq!(number("1."), number("1"));
    assert_eq!(number("-0e1024"), number("0"));
    assert!(number("9007199254740992") < number("9007199254740993"));
    assert!(number("0.10000000000000000000000000000000000001") > number("0.1"));
    assert_ne!(
        number("1/3"),
        number("0.33333333333333333333333333333333333333")
    );
    assert_eq!(number("2/-6"), number("-1/3"));
}

#[test]
fn formatting_is_exact_and_not_float_rounding() {
    for (source, expected) in [
        ("-0", "0"),
        ("1e3", "1000"),
        ("1e-3", "0.001"),
        ("1/8", "0.125"),
        ("-1/20", "-0.05"),
        ("12.500", "12.5"),
        ("1/3", "1/3"),
        ("9007199254740993", "9007199254740993"),
    ] {
        assert_eq!(number(source).to_string(), expected, "{source}");
    }
}

#[test]
fn malformed_numeric_values_are_rejected_completely() {
    for text in [
        "", ".", "+", "--1", "1..2", "1e", "1e+", "1e1e2", "NaN", "inf", "Infinity", "1,000",
        "true", "1kg", "1/0", "1/2/3", "1.5/2", "1 / 2", "１２", "1\0",
    ] {
        assert!(
            ExactNumber::parse(text, &ValueLimits::default()).is_err(),
            "{text:?}"
        );
    }
}

#[test]
fn source_numeric_bool_null_arrays_and_objects_are_not_numbers() {
    for value in [json!(true), json!(false), json!(null), json!([]), json!({})] {
        for kind in ["year", "quantity"] {
            assert!(TypedValue::from_kqa(
                &json!({"type":kind,"value":value}),
                &ValueLimits::default()
            )
            .is_err());
        }
    }
    assert!(TypedValue::from_kqa(
        &json!({"type":"year","value":2000.5}),
        &ValueLimits::default()
    )
    .is_err());
    assert!(TypedValue::from_kqa(
        &json!({"type":"unknown","value":"2000"}),
        &ValueLimits::default()
    )
    .is_err());
}

#[test]
fn exact_json_source_number_is_preserved() {
    let source: serde_json::Value = serde_json::from_str(
        r#"{"type":"quantity","value":9007199254740993.000000000000000001,"unit":"1"}"#,
    )
    .unwrap();
    let value = TypedValue::from_kqa(&source, &ValueLimits::default()).unwrap();
    assert_eq!(
        value,
        literal("9007199254740993.000000000000000001", ValueKind::Quantity)
    );
}

#[test]
fn numeric_work_is_bounded_before_exponent_expansion() {
    let limits = ValueLimits {
        max_numeric_digits: 4,
        max_exponent: 10,
        ..ValueLimits::default()
    };
    assert!(ExactNumber::parse("12345", &limits).is_err());
    assert!(ExactNumber::parse("1e11", &limits).is_err());
    assert!(ExactNumber::parse("1e-11", &limits).is_err());
    assert!(ExactNumber::parse("1/1234", &limits).is_err());
    assert!(ExactNumber::parse("1e999999999999999999999999", &ValueLimits::default()).is_err());
    assert!(ExactNumber::parse("1e10", &limits).is_ok());
    assert!(ExactNumber::parse("1e-10", &limits).is_ok());
    let invalid_limits = ValueLimits {
        max_exponent: u32::MAX,
        ..ValueLimits::default()
    };
    assert!(ExactNumber::parse("1", &invalid_limits).is_err());
    let short_text = ValueLimits {
        max_text_bytes: 3,
        ..ValueLimits::default()
    };
    assert!(ExactNumber::parse("  1 ", &short_text).is_err());
}

#[test]
fn explicit_unit_policy_preserves_dimensions_and_exact_conversion() {
    let kilometre = literal("1 kilometre", ValueKind::Quantity);
    let metre = literal("1000 metre", ValueKind::Quantity);
    assert_eq!(kilometre.compare(&metre), ValueComparison::Incomparable);
    assert_eq!(
        kilometre.compare_with_units(&metre, UnitPolicy::KnownSi),
        ValueComparison::Equal
    );
    for (left, right) in [
        ("1 foot", "0.3048 metre"),
        ("1 pound", "0.45359237 kilogram"),
        ("36 kilometre per hour", "10 metre per second"),
        ("1 mile", "1609.344 metre"),
    ] {
        assert_eq!(
            literal(left, ValueKind::Quantity)
                .compare_with_units(&literal(right, ValueKind::Quantity), UnitPolicy::KnownSi),
            ValueComparison::Equal
        );
    }
    assert_eq!(
        literal("1 metre", ValueKind::Quantity).compare_with_units(
            &literal("1 second", ValueKind::Quantity),
            UnitPolicy::KnownSi
        ),
        ValueComparison::Incomparable
    );
    assert_eq!(
        literal("1 Metre", ValueKind::Quantity).compare_with_units(
            &literal("1 metre", ValueKind::Quantity),
            UnitPolicy::KnownSi
        ),
        ValueComparison::Incomparable
    );
    assert_eq!(
        literal("1 widget", ValueKind::Quantity).compare(&literal("2 widget", ValueKind::Quantity)),
        ValueComparison::Less
    );
    assert_eq!(
        literal("1", ValueKind::Quantity).compare(&literal("1 widget", ValueKind::Quantity)),
        ValueComparison::Incomparable
    );
}

#[test]
fn quantity_units_and_literals_are_validated() {
    let limits = ValueLimits {
        max_unit_bytes: 3,
        ..ValueLimits::default()
    };
    for unit in ["", " kg", "kg ", "k\ng", "metre"] {
        assert!(Quantity::new(number("1"), unit, &limits).is_err());
    }
    assert!(
        TypedValue::parse_literal("1kg", ValueKind::Quantity, &ValueLimits::default()).is_err()
    );
    assert!(TypedValue::from_kqa(
        &json!({"type":"quantity","value":"1","unit":true}),
        &ValueLimits::default()
    )
    .is_err());
}

#[test]
fn gregorian_calendar_checks_leap_centuries_and_month_lengths() {
    for date in [
        "2000-02-29",
        "2024/2/29",
        "1900-02-28",
        "2400-02-29",
        "2023-04-30",
    ] {
        assert!(
            GregorianDate::parse(date, &ValueLimits::default()).is_ok(),
            "{date}"
        );
    }
    for date in [
        "1900-02-29",
        "2100-02-29",
        "2023-02-29",
        "2024-02-30",
        "2023-04-31",
        "2020-00-01",
        "2020-13-01",
        "2020-01-00",
        "2020-01-32",
        "2024-02-29junk",
        "2024-2-29-1",
        "2024/2-29",
        "2024-02/29",
        "2024-002-29",
        "2024--2-29",
    ] {
        assert!(
            GregorianDate::parse(date, &ValueLimits::default()).is_err(),
            "{date}"
        );
    }
}

#[test]
fn bce_convention_is_explicit_and_calendar_has_year_zero() {
    assert_eq!(
        CalendarYear::from_common_era(Era::Bce, 1).unwrap().number(),
        0
    );
    assert_eq!(
        CalendarYear::from_common_era(Era::Bce, 2).unwrap().number(),
        -1
    );
    assert_eq!(
        CalendarYear::from_common_era(Era::Ce, 1).unwrap().number(),
        1
    );
    assert!(CalendarYear::from_common_era(Era::Bce, 0).is_err());
    assert!(GregorianDate::parse("0000-02-29", &ValueLimits::default()).is_ok());
    assert!(GregorianDate::parse("-0001-02-29", &ValueLimits::default()).is_err());
    assert!(GregorianDate::parse("-0400-02-29", &ValueLimits::default()).is_ok());
    assert!(GregorianDate::parse("-0100-02-29", &ValueLimits::default()).is_err());
    assert!(
        literal("-0001-12-31", ValueKind::Date).compare(&literal("0000-01-01", ValueKind::Date))
            == ValueComparison::Less
    );
    assert_eq!(CalendarYear::new(1_000_000).number(), 1_000_000);
}

#[test]
fn source_geologic_years_are_legitimate_year_precision_values() {
    // Actual KQA inception rows, which a broad FindAll/FilterYear encounters
    // before applying a narrower concept filter. Rejecting these globally
    // prevents otherwise unrelated football/county queries from completing.
    for year in [
        -4_540_000_000_i64,
        -4_527_000_000,
        -4_570_000_000,
        -66_000_000,
        -84_000_000_000,
    ] {
        let value = TypedValue::from_kqa(
            &json!({"type":"year","value":year}),
            &ValueLimits::default(),
        )
        .unwrap();
        assert_eq!(value.kind(), ValueKind::Year);
        assert_eq!(value.year().unwrap().number(), year);
        assert_eq!(
            value.compare(&literal("1887", ValueKind::Year)),
            ValueComparison::Less
        );
        assert_eq!(
            serde_json::from_str::<TypedValue>(&serde_json::to_string(&value).unwrap()).unwrap(),
            value
        );
    }
    let earth = literal("-4540000000", ValueKind::Year);
    let jainism = literal("-84000000000", ValueKind::Year);
    assert_eq!(earth.compare(&jainism), ValueComparison::Greater);
    assert_eq!(
        literal("30000000", ValueKind::Year).compare(&earth),
        ValueComparison::Greater
    );
}

#[test]
fn signed_year_boundaries_and_bce_conversion_do_not_overflow() {
    let limits = ValueLimits::default();
    for year in [i64::MIN, i64::MAX] {
        let value = CalendarYear::parse(&year.to_string(), &limits).unwrap();
        assert_eq!(value.number(), year);
        let date = GregorianDate::new(value, 1, 1).unwrap();
        assert_eq!(
            GregorianDate::parse(&date.to_string(), &limits).unwrap(),
            date
        );
    }
    assert!(CalendarYear::parse("9223372036854775808", &limits).is_err());
    assert!(CalendarYear::parse("-9223372036854775809", &limits).is_err());
    assert_eq!(
        CalendarYear::from_common_era(Era::Bce, 9_223_372_036_854_775_809)
            .unwrap()
            .number(),
        i64::MIN
    );
    assert_eq!(
        CalendarYear::from_common_era(Era::Ce, i64::MAX as u64)
            .unwrap()
            .number(),
        i64::MAX
    );
    assert!(CalendarYear::from_common_era(Era::Bce, u64::MAX).is_err());
    assert!(CalendarYear::from_common_era(Era::Ce, u64::MAX).is_err());
    for malformed in ["2000.0", "2000.1", "2e3", "2000 trailing"] {
        assert!(TypedValue::from_kqa(&json!({"type":"year","value":malformed}), &limits).is_err());
    }
}

#[test]
fn year_precision_overlaps_days_without_asserting_day_equality() {
    let year = literal("2000", ValueKind::Year);
    let day = literal("2000-06-01", ValueKind::Date);
    assert_eq!(year.compare(&day), ValueComparison::Overlap);
    assert_eq!(day.compare(&year), ValueComparison::Overlap);
    for operation in [
        ComparisonOp::Eq,
        ComparisonOp::Ne,
        ComparisonOp::Lt,
        ComparisonOp::Le,
        ComparisonOp::Gt,
        ComparisonOp::Ge,
    ] {
        assert_eq!(year.compare(&day).test(operation), None);
    }
    assert_eq!(day.compare_at_year(&year), ValueComparison::Equal);
    assert_eq!(
        year.compare(&literal("1999-12-31", ValueKind::Date)),
        ValueComparison::Greater
    );
    assert_eq!(
        year.compare(&literal("2001-01-01", ValueKind::Date)),
        ValueComparison::Less
    );
    assert_eq!(
        year.compare(&literal("2000", ValueKind::Date)),
        ValueComparison::Equal
    );
}

#[test]
fn january_first_is_not_implicitly_downgraded_to_year_precision() {
    let source = TypedValue::from_kqa(
        &json!({"type":"date","value":"2000/1/1"}),
        &ValueLimits::default(),
    )
    .unwrap();
    assert_eq!(source.kind(), ValueKind::Date);
    assert_eq!(source.to_string(), "2000-01-01");
    assert_eq!(
        source.compare(&literal("2000", ValueKind::Year)),
        ValueComparison::Overlap
    );
    assert!(TypedValue::from_kqa(
        &json!({"type":"date","value":"2000"}),
        &ValueLimits::default()
    )
    .is_err());
}

#[test]
fn text_predicates_do_not_coerce_types_or_impose_an_order() {
    let left = literal("Straße", ValueKind::String);
    let same = literal("STRAßE", ValueKind::String);
    assert_eq!(left.compare(&same).test(ComparisonOp::Eq), Some(true));
    let other = literal("Different", ValueKind::String);
    assert_eq!(left.compare(&other).test(ComparisonOp::Eq), Some(false));
    assert_eq!(left.compare(&other).test(ComparisonOp::Ne), Some(true));
    assert_eq!(left.compare(&other).test(ComparisonOp::Lt), None);
    assert_eq!(
        literal("2000", ValueKind::String).compare(&literal("2000", ValueKind::Year)),
        ValueComparison::Incomparable
    );
}

#[test]
fn comparison_predicates_obey_known_order() {
    for (comparison, expected) in [
        (
            ValueComparison::Less,
            [false, true, true, true, false, false],
        ),
        (
            ValueComparison::Equal,
            [true, false, false, true, false, true],
        ),
        (
            ValueComparison::Greater,
            [false, true, false, false, true, true],
        ),
    ] {
        for (operation, expected) in [
            ComparisonOp::Eq,
            ComparisonOp::Ne,
            ComparisonOp::Lt,
            ComparisonOp::Le,
            ComparisonOp::Gt,
            ComparisonOp::Ge,
        ]
        .into_iter()
        .zip(expected)
        {
            assert_eq!(comparison.test(operation), Some(expected));
        }
    }
    assert_eq!(ValueComparison::Incomparable.test(ComparisonOp::Ne), None);
}

#[test]
fn persistence_retains_exact_values_and_original_bounded_literals() {
    for value in [
        literal("1e1024", ValueKind::Quantity),
        literal("-1/3 pound", ValueKind::Quantity),
        literal("-0001-02-28", ValueKind::Date),
        literal("0", ValueKind::Year),
        literal("a string", ValueKind::String),
    ] {
        let encoded = serde_json::to_string(&value).unwrap();
        assert_eq!(serde_json::from_str::<TypedValue>(&encoded).unwrap(), value);
    }
    assert_eq!(
        literal("1e1024", ValueKind::Quantity).to_kqa()["value"],
        "1e1024"
    );
}

#[test]
fn relative_agreement_policy_is_exact_explicit_and_bounded() {
    let limits = ValueLimits::default();
    let tolerance = number("1/200");
    let floor = number("1e-12");
    assert!(number("100")
        .within_relative(&number("100.5"), &tolerance, &floor, &limits)
        .unwrap());
    assert!(!number("100")
        .within_relative(&number("101"), &tolerance, &floor, &limits)
        .unwrap());
    assert!(number("0")
        .within_relative(&number("0.000000000000005"), &tolerance, &floor, &limits)
        .unwrap());
    assert!(!number("-100")
        .within_relative(&number("100"), &tolerance, &floor, &limits)
        .unwrap());
    for tolerance in ["-0.1", "1", "2"] {
        assert!(number("1")
            .within_relative(&number("1"), &number(tolerance), &floor, &limits)
            .is_err());
    }
    assert!(number("1")
        .within_relative(&number("1"), &number("0"), &number("-1"), &limits)
        .is_err());
    let stricter = ValueLimits {
        max_numeric_digits: 2,
        ..limits
    };
    assert!(number("123")
        .within_relative(&number("123"), &number("0"), &number("0"), &stricter)
        .is_err());
}
