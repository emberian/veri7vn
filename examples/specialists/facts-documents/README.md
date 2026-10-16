# Ordered facts and original quotations

`python3 tests/families/facts-documents/check_source_instances.py` runs the actual
shipped `literature-v2` FactsOrgan. It checks source behavior independently of
native compilation. The source includes ordered overlap, source sentence and
structured value, narrative decline, normalization and boundary decline.

The actual `facts_literature_v2.py` source currently identifies NEW rule 0 at
half-open UTF-8 byte span [1721,1801), and NEW rule 4 at [2152,2280). The checker
extracts these ranges from the current original source AST; changing the source
requires recapturing its identity and revision rather than reusing these offsets.
A quotation of the Python rule is a quotation of that source, not a proof of the
literary claim and not a native implementation of its regex.

`Document_Request.project_document_span` pins document identity/revision and
extracts exact original bytes. Its independent `document_span_meaning` specifies
retention, bounds, bytes and metadata. `Source_Fact_Observation.observe_source_fact`
preserves the selected original guarded rule and its quotation. If that selected
rule's original document is missing, expired or changed, it reports source
unavailability; it cannot silently choose a later rule.

The delivery variants distinguish literal quotation, reference data and historical
quotation. Historical scope retains original result ID, part, scope and completeness;
route/date alone do not turn an old answer into a current fact. World adoption
requires a separate native accepted proposition and the resident authority pipeline.
These theories expose no world-adoption constructor.

Native regression session `Veri7vn_Source_Fact_Document_Tests` checks exact repeated
spaces/newline, unknown author, stale first-rule source, excluded-feature guard and
expired-source behavior. Its command-shaped data is explicitly an authored fixture.
The new projections and regression session await steward compilation. Managed
original-input retention, admitted operation, resident dispatch, licensed rendering
and deployed expiry/Forget remain required consumers; these HOL data functions do
not create those authorities.
