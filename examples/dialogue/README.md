# Resident exact-input dialogue

```scala
val dialogue = new veri7vn.runtime.service.DialogueClient(service.client)
val offer = dialogue.inspect("the sum of -2 and 3".getBytes(java.nio.charset.StandardCharsets.UTF_8))
val request = dialogue.select(offer.handle, offer.alternatives.head) // ready singleton only
val result = service.client.mathematicsResult(request)
dialogue.close()
```

Handle clarification/literal/structure_blocked/budget/unrecognized before selection. select consumes retained original bytes once; pending results poll the same request and display licensed HTML only. No prose reparsing/adoption.

Steward target tests/language/runtime/resident.scala exercises real native inspection, concurrent requests, invalid/consumed selections and Forget. Source/Domain/multipart adoption need separate D46 consumers.
