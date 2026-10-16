package veri7vn.packages.intake

/** Single host journal adapter. It publishes only inert source-head locators.
  * SourceObjects remains private to the host service; raw locators are not read capabilities.
  */
final class HostDraftJournal(store: veri7vn.runtime.host.WorkspaceStore) extends DraftJournal {
  override def head(draft: String): Option[String] = store.head(draft)
  override def withHead[A](draft: String)(materialize: String => A): Option[A] =
    store.withSourceHead(draft)(materialize)
  override def compareAndAppend(draft: String, expected: Option[String], next: String): Boolean =
    store.compareAndAppend(draft,expected,next)
}
