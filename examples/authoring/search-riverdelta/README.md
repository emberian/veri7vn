# Search consumer rehearsal

Status: source implementation and actual-runtime test prepared; the native parent
must qualify before these commands are exposed by the installed client.

The original proposition is in `proposition.txt`. The fixed policy introduces an
implication, splits a conjunction and applies assumptions. The native receiver
parses the original bytes in an actual admitted context, charges the search and
checks the resulting consequence. A matching label or numeric artifact ID cannot
create that context.

The shared command consumer supports this sequence:

1. `search-contexts`: inspect actual native context IDs, semantic generations and
   labels. Select a returned context, including a newly admitted author context
   only when the native producer actually exposes it.
2. `search CONTEXT proposition.txt 100 100 2 5000`: submit the exact standalone
   proposition with expansion, frontier, successor and millisecond bounds. Keep
   the returned request ID; submission is separate from observing a result.
3. `search-status REQUEST`: inspect the exact proposition, receiver and fresh proof
   semantic generations, dependencies, trace and truncation. Budget exhaustion is
   unresolved, not a refutation. The proof metadata is not a portable theorem or
   an Isabelle proof script.
4. `search-cancel REQUEST`: revoke the active request. A retained consequence can
   remain accessible as historical evidence under history permissions.
5. Restart the resident, then use `search-requests` and `search-status REQUEST`.
   Reopening selects actual retained native associations; it does not replay search
   or reconstruct a handle from an arbitrary saved ID.
6. `search-forget REQUEST --confirm`: remove dependent retained material. Later
   status selection must fail rather than resurrect the proof. Physical cleanup
   follows the native ownership barrier.

`tests/workbench/assistance/search-resident.scala` rehearses this sequence against
the production supervisor, bridge, authority coordinator and native runtime. It
also exercises an actual one-expansion budget stop. It has no synthetic native
context, accepted result or callback granting authority. Execution is pending.

This standalone flow does not yet establish an atomic package-revision association
or extract logical propositions from failed declaration spans. Authored Build
artifacts must pass the separate native admission/context-publication junction
before they can supply an author context here. Repairing source remains an explicit
reviewed edit with a preserve/restrict/change meaning choice and fresh validation.
