# Source token fidelity check

The selected `Veri7vn_Source_Tokens` session passed in 5 s (theory cumulative time 0.102 s)
under Isabelle2026-RC1, one build job/two ML threads. The overall batched receipt is
failed because an unrelated Source_Metadata_Codec proof failed; it is not a green
batch. The source-token session loads the production helper and executes all source
span assertions. Exact helper/test bodies below match the immutable attempt hash
map before shared-base relocation. This establishes source token byte fidelity for
the covered native formats, not development admission, execution or lifecycle.
