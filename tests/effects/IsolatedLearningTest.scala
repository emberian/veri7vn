package veri7vn.runtime.effects

import scala.language.unsafeNulls
import java.nio.file.Files
object IsolatedLearningTest {
  def main(args: Array[String]): Unit = {
    val attempt=AttemptIdentity("workspace",1,2,3,"immutable-input")
    val receipt=ExecutorReceipt(attempt,"mock/1","receipt")
    assert(Executor.validateReconciliation(attempt,"mock/1",Reconciled.Confirmed(receipt)).isRight)
    assert(Executor.validateReconciliation(attempt.copy(request=4),"mock/1",Reconciled.Confirmed(receipt)).isLeft)
    assert(Executor.validateReconciliation(attempt,"mock/2",Reconciled.Failed(receipt)).isLeft)
    assert(Executor.validateReconciliation(attempt,"mock/1",Reconciled.Unknown)==Right(Reconciled.Unknown))
    val parent=Files.createTempDirectory("effects-isolation-")
    val budget=LearningBudget(7,10,100,100,10,64)
    val original=Array[Byte](1)
    val a=IsolatedLearning.fork(parent,Map("same" -> original),budget)
    val b=IsolatedLearning.fork(parent,Map("same" -> original),budget)
    try {
      original(0)=9
      a.learn("same",Array[Byte](2))
      assert(a.lookup("same").get.toVector==Vector[Byte](2))
      assert(b.lookup("same").get.toVector==Vector[Byte](1))
      val returned=b.lookup("same").get; returned(0)=8
      assert(b.lookup("same").get.toVector==Vector[Byte](1))
      b.learn("../../outside",Array[Byte](3))
      assert(a.lookup("../../outside").isEmpty)
    } finally {a.close(); b.close()}
    val c=IsolatedLearning.fork(parent,Map("same" -> Array[Byte](1)),budget)
    try assert(c.lookup("same").get.toVector==Vector[Byte](1)) finally c.close()
    assert(a.retainedPayloadBytes==0 && b.retainedPayloadBytes==0 && c.retainedPayloadBytes==0)
    def rejected(action: => Unit): Unit = {
      var rejected=false
      try action catch {case _: IllegalArgumentException => rejected=true}
      assert(rejected)
    }
    rejected { IsolatedLearning.fork(parent,Map("large" -> Array.fill[Byte](101)(0)),budget); () }
    rejected { a.lookup("closed"); () }
    val limited=IsolatedLearning.fork(parent,Map.empty,LearningBudget(8,1,8,4,2,64))
    try {
      rejected {limited.learn("x" * 65,Array[Byte](1))}
      limited.learn("one",Array[Byte](1,2))
      rejected {limited.learn("two",Array[Byte](3))}
      rejected {limited.learn("one",Array[Byte](1,2,3))}
      for (_ <- 1 to 20) limited.learn("one",Array[Byte](4,5))
      assert(limited.lookup("one").get.toVector==Vector[Byte](4,5))
    } finally limited.close()
    val partial=IsolatedLearning.forkWithWriter(parent,Map.empty,budget,(path,bytes) => {
      Files.write(path,bytes.take(1)); throw new java.io.IOException("partial write")
    })
    try {
      var failed=false
      try partial.learn("broken",Array[Byte](1,2)) catch {case _: java.io.IOException => failed=true}
      assert(failed && partial.lookup("broken").isEmpty && partial.retainedPayloadBytes==0)
    } finally partial.close()
    val remaining=Files.list(parent)
    try assert(remaining.count()==0) finally remaining.close()
    Files.delete(parent)
    println("VERI7VN_EFFECTS learning_isolation PASS")
  }
}
