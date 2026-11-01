# Vision and Artist as appliance operations

Four operations now call the actual upstream code through a bounded adapter:

| Operation | What it does |
| --- | --- |
| `vision.describe` | Measures HOG, texture, colour and thumbnail features, then returns the upstream 2048-element HRR descriptor. Input is composited on white and resized to 32×32; this is measurement, not object recognition. |
| `vision.classify_examples` | Compares an image with one to eight caller-supplied labelled examples. Returns the neighbour indices, supplied citations, image hashes, vote shares and margin, or withholds on an insufficient margin. |
| `artist.parse_layout` | Parses supported object/count/colour/relation wording and returns every planned rectangle. |
| `artist.compose` | Calls Artist's renderer with supplied sprites and citations, checks the full 512×512 render, and returns a 128×128 palette preview with placement/citation evidence. |

The consumer is `VisualOperations(runtime, workspace)` in
`tools/oracle_components/visual.py`: `catalog()` and `invoke(id, arguments)`.
The appliance service integrates it under its existing journal, worker deadline
and serialized engine thread. Mini's existing admission path remains the caller;
this module adds no authority or external network/filesystem operation.

This lane has no new theorem statements or specialist-panel scores. Its image
fixtures do not reproduce the upstream published recognition or GenEval results.

## Source and repairs

Official Hugging Face origins were fetched into private working copies. Their
heads were unchanged from the survey:

- Vision: `271c1832780c25980253fd4816f8e812b064325c`.
- Artist: `df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8`.

Private copies are `var/u3-sibling-visual/{vision,artist}`. Original survey
snapshots, `upstream/`, and immutable appliance candidates were not edited. Both
components carry Apache-2.0 `LICENSE` files, which provisioning must retain.

Actual before/after source executions are retained in
`var/u3-sibling-visual/red-green.json`:

| Counterexample | Original | Repaired |
| --- | --- | --- |
| Three cats left of two dogs | One rectangle per group | Three and two rectangles; every pair preserves the requested ordering |
| Six cats | Silently parses as one cat | Refuses unsupported count |
| Request all neighbours from a two-example Vision store | `ValueError` from `argpartition(k)` | Returns both neighbours using `k - 1` |
| A one-class Vision vote | `IndexError` reading the second class | Returns the one-class vote margin |

Artist also now identifies each placed sprite's object group. Its verifier no
longer conflates two groups of the same class, and an absent relation group
fails its check instead of indexing an empty list. Unsupported prefixes such
as “not a cat” or “a striped cat” are refused rather than silently discarded.
The layout accepts at most two groups, each with one to five objects. Existing
single-object layout geometry is preserved. Vision validates finite vectors,
class labels, neighbour bounds and positive finite vote temperature.

Exported source patches:

- `deploy/appliance/patches/siblings/visual-vision.patch`:
  `bbd213525c872df039ee5555b83ae91600f58ab36cead2847f78a28adfef2008`.
- `deploy/appliance/patches/siblings/visual-artist.patch`:
  `6622cb5f8804971cb69e2ac91860645fd3a1dd5c010d1602964583bb64355798`.

Artist retains its upstream CRLF line endings. Use the scoped
`git -c core.whitespace=cr-at-eol diff --check` for its private source and patch;
ordinary whitespace diagnostics otherwise call those retained carriage returns
trailing whitespace. No repository-wide Git setting was changed.

## What is available and what is missing

The adapter requires `components/{vision,artist}/source/` and their source
receipts in `APPLIANCE.json`. Before importing, it checks the supported base
revision, exact fixed source root, every declared file size/hash, absence of
symlinks, and completeness of the Python file inventory. A substituted source
or a missing dependency disables only the affected component. Catalog metadata
then reports receipt-bound identity; the host still has to verify the signed
package containing the receipt. File agreement does not prove source truth.

The catalog explicitly marks these unavailable:

- Recognition against the published benchmark exemplar stores: the source
  release does not supply those 410–490 MB stores.
- OCR, chart QA and screen grounding: no pinned open-license font inventory or
  rendered glyph store is provisioned. These are not substitutes for a general
  vision model or a UI automation authority.
- COCO-library rendering: the published 2,673-sprite index/library is absent.
  The upstream recorded index hash is
  `4b1d83af4ab12424822ce58129fd044283fa77d216bac789784c80f062187f4d`.
- Building that library: requires explicit dataset import/build inputs and its
  own profile. The query service does not run a downloader or installer.

Supplied labels and citations are claims by the caller. Neither nearest-neighbour
voting nor Artist's own pixel/layout checks independently establishes them.
The same source sprite may be copied more than once to meet a requested count;
all placements retain its citation and image digest.

## Bounds and evidence

Only strict base64 single-frame PNG/JPEG inputs are accepted. Each image is at
most 256 KiB, 65,536 pixels and 512 pixels on either side. The combined image
base64 is at most 1 MiB. The host's configured request limit still applies:
Mini's current 64 KiB body profile cannot carry the maximum intrinsic image size.
Small supplied images work through that profile; larger images need an explicit
larger profile or a future artifact-input capability, not a client-selected path.

Each operation reply is at most 60 KiB. Artist returns a PNG preview at most
24 KiB; coordinates and self-checks explicitly refer to its original 512×512
render. The preview is resized with Lanczos and quantized to 256 colours. The
full render's PNG digest is returned, but no full image file is retained or
claimed to be downloadable. Full-resolution artifact delivery remains work.

Measured local examples:

- `vision.describe`: 44,004 JSON bytes.
- `artist.compose`: 16,855 JSON bytes, including an 11,392-byte PNG preview.
- Ten catalog entries: four live direct operations and six unavailable entries.

The default Mini model-text projection can truncate the descriptor-vector display;
this is distinct from retaining the complete response at the transport layer.
No artificial artifact link is returned to hide that limitation.

Twelve scoped tests passed against the repaired upstream code, including actual
Pillow decoding/rendering, all-neighbour and one-class votes, tied-label refusal,
all four spatial relations with multiple instances, same-class colour groups,
invalid/oversized images, path/URL rejection, missing sprites, and source-receipt
substitution. Exact log: `var/u3-sibling-visual/tests.log`.

```sh
PYTHONPATH=.venv/lib/python3.12/site-packages \
  var/u3-sibling-visual/venv/bin/python -B -m unittest discover \
  -s tests/oracle_components -p test_visual.py -v
```

The owned test environment adds Pillow 11.3.0 to the repository's NumPy/SciPy
inputs. Packaging supplies the separately pinned Linux Pillow wheel. These four
operations require NumPy and Pillow; the other shipped Vision modules also
require SciPy. No large data assets, external models, remote services, or published
benchmark suites were invoked. Full service/Mini qualification belongs to root's
combined candidate run.

Changed tracked paths are the adapter, `tests/oracle_components/test_visual.py`,
the two source patches, and this report. Root owns commit, package construction
and upstream contribution; no messages were sent to upstream authors.
