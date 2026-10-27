# Ask about a small text file

Oracle7's current HTTP adapter takes text, not attachments. Its inline reading
format is `Passage: <text> Question: <question>`. Simple yes/no questions can
return a supporting quotation. This workflow prepares that format from a UTF-8
file and maps the returned quote back to the file's lines.

```sh
.venv/bin/python -B tools/usage/documents/prepare.py prepare \
  --document tools/usage/documents/archive.txt \
  --questions tools/usage/documents/questions.json \
  --conversation archive-demo \
  --out var/usage-20261026/documents/my-prepared

.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/documents/my-prepared/cases.json \
  --out var/usage-20261026/documents/my-run

.venv/bin/python -B tools/usage/documents/prepare.py inspect \
  --manifest var/usage-20261026/documents/my-prepared/manifest.json \
  --results var/usage-20261026/documents/my-run/results.jsonl
```

Use new output directories. Questions are a JSON array, for example:

```json
[{"id":"owner","question":"Is Nira Vale the director of the Lumen Archive?"}]
```

Every request repeats the complete source. This avoids relying on passage memory,
which failed in our experiment. The manifest retains the original text and its
SHA-256; the request normalizes whitespace just as the engine does. The tool
rejects oversized requests instead of dropping text to fit 16 KiB. It does not
read other documents, fetch sources, upload attachments, or invent answers.

Ask a direct question. Adding “Cite the supporting sentence” caused a supported
question to be withheld in the experiment; the successful plain question already
returned a quote. The inspector finds every occurrence, including quotes spanning
lines, and preserves the complete original Oracle reply. It checks request/source
identity and quotation occurrence, **not whether the quote proves the answer**.

Limits observed on the passing candidate:

- Open questions, summaries, timelines, and comparisons across sentences often
  failed despite facts being present. Unsupported question shapes are warned
  about, not rewritten into different questions.
- Contradictory versions could produce a wrong “Yes.” Keep versions explicit and
  inspect the whole source. A narrow proposed engine repair is supplied in
  `conflicting-passages.patch`; preparing requests does not apply that repair.
- A passage is temporary input, not persistent document ingestion. The runtime's
  internal `ingest_document` method is not an HTTP attachment API.
- Source facts are user-supplied. A hash and matching quote establish where text
  came from, not its real-world truth. No theorem or specialist-panel claim.

The independent task expectations and all 14 baseline prompts are beside this
README. `project/lanes/U1-documents.md` records results and exact limitations.
