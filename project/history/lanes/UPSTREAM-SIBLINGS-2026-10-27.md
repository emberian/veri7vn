# Sibling repairs published upstream — 27 October 2026

All five reviewed sibling repairs were submitted as separate Hugging Face pull requests under the user’s explicit publishing authorization. Each PR is open, contains one repaired source file and a portable regression file, and had no reported conflicts when checked. Nothing remains unsent in this contribution batch. Upstream acceptance/merge is still pending.

Before submission, the official main heads matched the reviewed bases below and all five repositories had no existing discussions or PRs. Each API commit used that exact parent revision. Fresh contribution clones live under `var/upstream-siblings-20261027/`; the original survey, appliance candidates, source patches and adapters were not modified.

| Component and PR | Repair | Portable tests |
| --- | --- | --- |
| [trafficcop](https://huggingface.co/psiloceyeben/oracle7-trafficcop/discussions/1) | Ambiguous bindings abstain; duplicate option IDs refuse; full-request receipts; no fabricated option probabilities | 3 passing |
| [deepspace](https://huggingface.co/psiloceyeben/oracle7-deepspace/discussions/1) | Require the correct action targets and response at or after fault onset | 2 passing |
| [infrastructure](https://huggingface.co/psiloceyeben/oracle7-infrastructure/discussions/1) | Pair forecast methods with comparable naive events; exclude duplicates and perfect ties; preserve epoch zero | 4 passing |
| [vision](https://huggingface.co/psiloceyeben/oracle7-vision/discussions/1) | Full-store nearest-neighbour requests, single-class voting, and input guards | 3 passing |
| [artist](https://huggingface.co/psiloceyeben/oracle7-artist/discussions/1) | Requested counts and spatial relations; exact supported wording; separate same-class groups | 3 passing |

## Source and immutable contribution revisions

| Component | Checked upstream base | Published commit |
| --- | --- | --- |
| trafficcop | `08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0` | [73f16660b9d20db3675115c13cc615ecf385e0e6](https://huggingface.co/psiloceyeben/oracle7-trafficcop/commit/73f16660b9d20db3675115c13cc615ecf385e0e6) |
| deepspace | `3538060dbb55f287d060820f7b7c42fe3487632d` | [220876fc49adaf73776706329d523b8a92635bf6](https://huggingface.co/psiloceyeben/oracle7-deepspace/commit/220876fc49adaf73776706329d523b8a92635bf6) |
| infrastructure | `74456ba7db9172f5822433308943647ecd67cdf0` | [e1f567c963e379a186f38310d77ad04289f25b68](https://huggingface.co/psiloceyeben/oracle7-infrastructure/commit/e1f567c963e379a186f38310d77ad04289f25b68) |
| vision | `271c1832780c25980253fd4816f8e812b064325c` | [b2af7801b3ffa50c59d9beb3efa0456b35a3a70b](https://huggingface.co/psiloceyeben/oracle7-vision/commit/b2af7801b3ffa50c59d9beb3efa0456b35a3a70b) |
| artist | `df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8` | [fb553371a4c69b570def36994fcf33781b2e627e](https://huggingface.co/psiloceyeben/oracle7-artist/commit/fb553371a4c69b570def36994fcf33781b2e627e) |

## Checks and scope

All 15 portable test methods fail against their original upstream sources and pass against the submitted repairs. The decision tests were already included in the reviewed patches; the Vision and Artist submissions add standalone upstream-only regressions alongside the unchanged reviewed source repairs. Tests require the standard library for the three decision repositories, NumPy for Vision, and NumPy/Pillow for Artist. Artist uses clearly labelled synthetic cutouts to test actual rendering and group verification, not recognition quality.

From each corresponding repository:

```sh
python -B -m unittest test_decision_contract -v  # Trafficcop, DeepSpace, Infrastructure
python -B -m unittest test_exemplar_contract -v  # Vision
python -B -m unittest test_layout_contract -v    # Artist
```

For local execution, the existing visual lane Python environment supplied Pillow, with the repository’s NumPy site-packages on PYTHONPATH. Exact red/green logs and JSON receipts are retained in the ignored contribution workspace. The public tests themselves need no Mini adapters, data assets, account credentials, host access or private evidence.

After publishing, each PR was retrieved through the official API and confirmed open with no conflicts and its full description present. Every source/test file was retrieved anonymously by its immutable commit URL and compared byte-for-byte with the tested local file. Fetching each `refs/pr/1` and checking the Git diff confirmed exactly the two intended files, with no additional assets or transcripts. Existing licenses and attribution remain in their repositories.

The Codex `attach_artifact` call was attempted for each PR. All five returned “attach_artifact requires a supported artifact type and valid pull request URL.” Hugging Face PRs therefore remain linked here rather than attached in the app; this did not block publication.

No theorem statements changed and no new Oracle7 specialist-panel or whole-system score is claimed. The PRs explicitly state their bounds: Trafficcop changes probability-field semantics; DeepSpace tests scorer contracts rather than rerunning its published simulation benchmark; Infrastructure trusts observations and does not prove future performance or cross-method cohort equivalence; visual tests do not establish recognition/GenEval scores.

Publication used the authenticated official Hugging Face client and its documented `create_commit(create_pr=True, parent_commit=...)` flow: [community/PR guide](https://huggingface.co/docs/huggingface_hub/guides/community). The only public material is sibling source repairs, portable regressions, and their technical descriptions.
