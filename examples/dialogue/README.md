# Exact-input resident dialogue

The fixed mathematics client starts with the existing resident service:

```scala
val dialogue = new veri7vn.runtime.service.DialogueClient(service.client)
val offer = dialogue.inspect("the sum of -2 and 3".getBytes(java.nio.charset.StandardCharsets.UTF_8))
// A singleton native reading may run. Multiple readings require an explicit choice.
val request = dialogue.select(offer.handle, offer.alternatives.head)
val result = service.client.mathematicsResult(request)
// While pending, poll the same request. Display only the returned licensed HTML.
dialogue.close()
```

This example expects `offer.status == "ready"`; a UI must handle `clarification`,
`literal`, `structure_blocked`, `budget` and `unrecognized` before selecting.
`select` consumes an inspection handle once and submits its retained original
bytes. Display text is never reparsed into an execution input. The client does
not adopt answer values into conversation state.

`tests/language/runtime/resident.scala` compiles the actual client and opens a fresh
resident workspace for this path, concurrent independent sum/product inputs,
invalid/consumed/discarded selections, literal failure, unsupported negative-root
input and native Forget. It must run through the shared `check-native` steward
after the native `inspect_routing` producer is built. Source/Domain routing and
dependent conversation adoption require their D46/native authority consumers;
this mathematics example does not claim those paths exist.
