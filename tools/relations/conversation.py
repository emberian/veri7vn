"""UNTRUSTED source-relative entity metadata for receipt-grounded follow-ups.

Identity comes from native eligible-query IDs or exact entity-valued source rows,
never reverse lookup of a rendered label. The source class/closure and explicit
reader-domain classification remain premises, not a theorem about real people.
"""
import fetch as F

DOMAIN_KINDS = {"countries": "country", "countries2": "country", "novels": "novel", "books": "book",
                "films": "film", "cities": "city", "towns": "town", "islands": "island",
                "rivers": "river", "lakes": "lake", "mountains": "mountain", "airports": "airport",
                "albums": "album", "songs": "song", "paintings": "painting"}
# Labels checked against this immutable source; not a general ontology proof.
CLASS_KINDS = {515: "city", 6256: "country", 3624078: "country", 571: "book", 8261: "novel",
               11424: "film", 482994: "album", 7366: "song", 3305213: "painting", 4022: "river",
               23397: "lake", 8502: "mountain", 23442: "island", 1248784: "airport"}


def entity(qid, domain=None):
    classes, _ = F.RS1.classes_of(qid)
    closure = set(classes)
    for cls in classes:
        closure.update(F.RS1.ancestors(cls))
    human = 5 in closure
    typed = {kind for root, kind in CLASS_KINDS.items() if root in closure}
    if domain in DOMAIN_KINDS:
        typed.add(DOMAIN_KINDS[domain])
    # A novel is also a book; this explicit subtype pair is not a contradiction.
    if "novel" in typed:
        typed.discard("book")
    thing = not human and len(typed) == 1
    kind = "person" if human else "thing" if thing else "unknown"
    result = {"qid": "Q%d" % qid, "label": F.STORE.label(qid) or "Q%d" % qid,
              "is_person": True if human else False if thing else None,
              "entity_kind": kind,
              "classification": "supplied human class/closure" if human else
                  "finite source class/closure map and optional native admitted domain" if thing else "not established"}
    if thing:
        result["entity_domain"] = next(iter(typed))
    return result


def metadata(out, evidence, attempt, domain):
    if attempt is None or "eligible_query_ids" not in out:
        return None
    result = {"property": out["property"], "direction": attempt["dir"],
              "slot_surface": attempt.get("slot"),
              "scope": "source-relative identities; source rows/classification and slot recognition assumed"}
    query_ids = set(out["eligible_query_ids"])
    if len(query_ids) == 1:
        qid = next(iter(query_ids))
        result["query_entity"] = entity(qid, domain if attempt["dir"] == "fwd" else None)
        result["query_identity_check"] = "singleton native eligible-query ID set"
    if attempt["dir"] == "inv":
        result["answer_entity"] = entity(out["subject"], domain)
        result["answer_identity_check"] = "native unique requested-kind subject ID"
    else:
        # Unlabelled entity IDs are still alternatives. Rendering may omit them,
        # but a missing label cannot establish a unique conversational identity.
        rows = [(obj, lit) for prop, obj, lit in F.STORE.props_of(out["subject"])
                if prop == out["property"] and (obj or lit)]
        ids = {obj for obj, _ in rows if obj}
        if len(ids) == 1 and all(obj for obj, _ in rows):
            result["answer_entity"] = entity(next(iter(ids)))
            result["answer_identity_check"] = "all raw entity/literal property rows are the same entity ID"
    return result
