structure Veri7vn_Checker : sig
  type num
  type int
  datatype scalar = Integer of int | Rational of int * int | Pi
  datatype opcode = Add | Multiply | Divide | SquareRoot
  type nat
  datatype expr = Input of nat | Literal of scalar | Unary of opcode * expr |
    Binary of opcode * expr * expr
  datatype instruction = Load of nat | Constant of scalar |
    Apply1 of opcode * nat | Apply2 of opcode * nat * nat
  val symbolic_run : instruction list -> (expr option) list
  val check_dag : expr -> instruction list -> nat -> bool
  val nat_of_integer : IntInf.int -> nat
  val int_of_integer : IntInf.int -> int
end = struct

datatype num = One | Bit0 of num | Bit1 of num;

fun equal_num (Bit0 x2) (Bit1 x3) = false
  | equal_num (Bit1 x3) (Bit0 x2) = false
  | equal_num One (Bit1 x3) = false
  | equal_num (Bit1 x3) One = false
  | equal_num One (Bit0 x2) = false
  | equal_num (Bit0 x2) One = false
  | equal_num (Bit1 x3) (Bit1 y3) = equal_num x3 y3
  | equal_num (Bit0 x2) (Bit0 y2) = equal_num x2 y2
  | equal_num One One = true;

datatype int = Zero_int | Pos of num | Neg of num;

fun equal_int Zero_int Zero_int = true
  | equal_int Zero_int (Pos l) = false
  | equal_int Zero_int (Neg l) = false
  | equal_int (Pos k) Zero_int = false
  | equal_int (Pos k) (Pos l) = equal_num k l
  | equal_int (Pos k) (Neg l) = false
  | equal_int (Neg k) Zero_int = false
  | equal_int (Neg k) (Pos l) = false
  | equal_int (Neg k) (Neg l) = equal_num k l;

datatype scalar = Integer of int | Rational of int * int | Pi;

fun equal_scalar (Rational (x21, x22)) Pi = false
  | equal_scalar Pi (Rational (x21, x22)) = false
  | equal_scalar (Integer x1) Pi = false
  | equal_scalar Pi (Integer x1) = false
  | equal_scalar (Integer x1) (Rational (x21, x22)) = false
  | equal_scalar (Rational (x21, x22)) (Integer x1) = false
  | equal_scalar (Rational (x21, x22)) (Rational (y21, y22)) =
    equal_int x21 y21 andalso equal_int x22 y22
  | equal_scalar (Integer x1) (Integer y1) = equal_int x1 y1
  | equal_scalar Pi Pi = true;

datatype opcode = Add | Multiply | Divide | SquareRoot;

fun equal_opcode Divide SquareRoot = false
  | equal_opcode SquareRoot Divide = false
  | equal_opcode Multiply SquareRoot = false
  | equal_opcode SquareRoot Multiply = false
  | equal_opcode Multiply Divide = false
  | equal_opcode Divide Multiply = false
  | equal_opcode Add SquareRoot = false
  | equal_opcode SquareRoot Add = false
  | equal_opcode Add Divide = false
  | equal_opcode Divide Add = false
  | equal_opcode Add Multiply = false
  | equal_opcode Multiply Add = false
  | equal_opcode SquareRoot SquareRoot = true
  | equal_opcode Divide Divide = true
  | equal_opcode Multiply Multiply = true
  | equal_opcode Add Add = true;

datatype nat = Zero_nat | Suc of nat;

fun equal_nat Zero_nat (Suc x2) = false
  | equal_nat (Suc x2) Zero_nat = false
  | equal_nat (Suc x2) (Suc y2) = equal_nat x2 y2
  | equal_nat Zero_nat Zero_nat = true;

datatype expr = Input of nat | Literal of scalar | Unary of opcode * expr |
  Binary of opcode * expr * expr;

fun equal_expra (Unary (x31, x32)) (Binary (x41, x42, x43)) = false
  | equal_expra (Binary (x41, x42, x43)) (Unary (x31, x32)) = false
  | equal_expra (Literal x2) (Binary (x41, x42, x43)) = false
  | equal_expra (Binary (x41, x42, x43)) (Literal x2) = false
  | equal_expra (Literal x2) (Unary (x31, x32)) = false
  | equal_expra (Unary (x31, x32)) (Literal x2) = false
  | equal_expra (Input x1) (Binary (x41, x42, x43)) = false
  | equal_expra (Binary (x41, x42, x43)) (Input x1) = false
  | equal_expra (Input x1) (Unary (x31, x32)) = false
  | equal_expra (Unary (x31, x32)) (Input x1) = false
  | equal_expra (Input x1) (Literal x2) = false
  | equal_expra (Literal x2) (Input x1) = false
  | equal_expra (Binary (x41, x42, x43)) (Binary (y41, y42, y43)) =
    equal_opcode x41 y41 andalso
      (equal_expra x42 y42 andalso equal_expra x43 y43)
  | equal_expra (Unary (x31, x32)) (Unary (y31, y32)) =
    equal_opcode x31 y31 andalso equal_expra x32 y32
  | equal_expra (Literal x2) (Literal y2) = equal_scalar x2 y2
  | equal_expra (Input x1) (Input y1) = equal_nat x1 y1;

type 'a equal = {equal : 'a -> 'a -> bool};
val equal = #equal : 'a equal -> 'a -> 'a -> bool;

val equal_expr = {equal = equal_expra} : expr equal;

datatype instruction = Load of nat | Constant of scalar | Apply1 of opcode * nat
  | Apply2 of opcode * nat * nat;

fun eq A_ a b = equal A_ a b;

fun dup Zero_int = Zero_int
  | dup (Pos n) = Pos (Bit0 n)
  | dup (Neg n) = Neg (Bit0 n);

fun uminus_int Zero_int = Zero_int
  | uminus_int (Pos m) = Neg m
  | uminus_int (Neg m) = Pos m;

fun plus_num One One = Bit0 One
  | plus_num One (Bit0 n) = Bit1 n
  | plus_num One (Bit1 n) = Bit0 (plus_num n One)
  | plus_num (Bit0 m) One = Bit1 m
  | plus_num (Bit0 m) (Bit0 n) = Bit0 (plus_num m n)
  | plus_num (Bit0 m) (Bit1 n) = Bit1 (plus_num m n)
  | plus_num (Bit1 m) One = Bit0 (plus_num m One)
  | plus_num (Bit1 m) (Bit0 n) = Bit1 (plus_num m n)
  | plus_num (Bit1 m) (Bit1 n) = Bit0 (plus_num (plus_num m n) One);

val one_int : int = Pos One;

fun bitM One = One
  | bitM (Bit0 n) = Bit1 (bitM n)
  | bitM (Bit1 n) = Bit1 (Bit0 n);

fun sub One One = Zero_int
  | sub (Bit0 m) One = Pos (bitM m)
  | sub (Bit1 m) One = Pos (Bit0 m)
  | sub One (Bit0 n) = Neg (bitM n)
  | sub One (Bit1 n) = Neg (Bit0 n)
  | sub (Bit0 m) (Bit0 n) = dup (sub m n)
  | sub (Bit1 m) (Bit1 n) = dup (sub m n)
  | sub (Bit1 m) (Bit0 n) = plus_int (dup (sub m n)) one_int
  | sub (Bit0 m) (Bit1 n) = minus_int (dup (sub m n)) one_int
and plus_int k Zero_int = k
  | plus_int Zero_int l = l
  | plus_int (Pos m) (Pos n) = Pos (plus_num m n)
  | plus_int (Pos m) (Neg n) = sub m n
  | plus_int (Neg m) (Pos n) = sub n m
  | plus_int (Neg m) (Neg n) = Neg (plus_num m n)
and minus_int k Zero_int = k
  | minus_int Zero_int l = uminus_int l
  | minus_int (Pos m) (Pos n) = sub m n
  | minus_int (Pos m) (Neg n) = Pos (plus_num m n)
  | minus_int (Neg m) (Pos n) = Neg (plus_num m n)
  | minus_int (Neg m) (Neg n) = sub n m;

fun nth (x :: xs) Zero_nat = x
  | nth (x :: xs) (Suc n) = nth xs n;

fun foldl f a [] = a
  | foldl f a (x :: xs) = foldl f (f a x) xs;

fun length_tailrec [] n = n
  | length_tailrec (x :: xs) n = length_tailrec xs (Suc n);

fun size_list xs = length_tailrec xs Zero_nat;

fun less_nat n Zero_nat = false
  | less_nat m (Suc n) = less_eq_nat m n
and less_eq_nat Zero_nat n = true
  | less_eq_nat (Suc m) n = less_nat m n;

fun at xs i = (if less_nat i (size_list xs) then nth xs i else NONE);

fun lift2 f NONE y = NONE
  | lift2 f (SOME x) NONE = NONE
  | lift2 f (SOME x) (SOME y) = f x y;

fun apsnd f (x, y) = (x, f y);

fun equal_option A_ NONE (SOME x2) = false
  | equal_option A_ (SOME x2) NONE = false
  | equal_option A_ (SOME x2) (SOME y2) = eq A_ x2 y2
  | equal_option A_ NONE NONE = true;

fun map_option f NONE = NONE
  | map_option f (SOME x2) = SOME (f x2);

fun symbolic_step es (Load i) = SOME (Input i)
  | symbolic_step es (Constant c) = SOME (Literal c)
  | symbolic_step es (Apply1 (opa, i)) =
    map_option (fn a => Unary (opa, a)) (at es i)
  | symbolic_step es (Apply2 (opa, i, j)) =
    lift2 (fn a => fn b => SOME (Binary (opa, a, b))) (at es i) (at es j);

fun symbolic_run code =
  foldl (fn es => fn ins => es @ [symbolic_step es ins]) [] code;

fun check_dag source code output =
  equal_option equal_expr (at (symbolic_run code) output) (SOME source);

val one_nat : nat = Suc Zero_nat;

fun plus_nat Zero_nat n = n
  | plus_nat (Suc m) n = plus_nat m (Suc n);

fun divmod_integer k l =
  (if ((k : IntInf.int) = (0 : IntInf.int))
    then ((0 : IntInf.int), (0 : IntInf.int))
    else (if IntInf.< ((0 : IntInf.int), l)
           then (if IntInf.< ((0 : IntInf.int), k)
                  then IntInf.divMod (IntInf.abs k, IntInf.abs l)
                  else let
                         val (r, s) =
                           IntInf.divMod (IntInf.abs k, IntInf.abs l);
                       in
                         (if ((s : IntInf.int) = (0 : IntInf.int))
                           then (IntInf.~ r, (0 : IntInf.int))
                           else (IntInf.- (IntInf.~ r, (1 : IntInf.int)),
                                  IntInf.- (l, s)))
                       end)
           else (if ((l : IntInf.int) = (0 : IntInf.int))
                  then ((0 : IntInf.int), k)
                  else apsnd IntInf.~
                         (if IntInf.< (k, (0 : IntInf.int))
                           then IntInf.divMod (IntInf.abs k, IntInf.abs l)
                           else let
                                  val (r, s) =
                                    IntInf.divMod (IntInf.abs k, IntInf.abs l);
                                in
                                  (if ((s : IntInf.int) = (0 : IntInf.int))
                                    then (IntInf.~ r, (0 : IntInf.int))
                                    else (IntInf.- (IntInf.~
              r, (1 : IntInf.int)),
   IntInf.- (IntInf.~ l, s)))
                                end))));

fun nat_of_integer k =
  (if IntInf.<= (k, (0 : IntInf.int)) then Zero_nat
    else let
           val (l, j) = divmod_integer k (2 : IntInf.int);
           val la = nat_of_integer l;
           val lb = plus_nat la la;
         in
           (if ((j : IntInf.int) = (0 : IntInf.int)) then lb
             else plus_nat lb one_nat)
         end);

fun times_num m One = m
  | times_num One n = n
  | times_num (Bit0 m) (Bit0 n) = Bit0 (Bit0 (times_num m n))
  | times_num (Bit0 m) (Bit1 n) = Bit0 (times_num m (Bit1 n))
  | times_num (Bit1 m) (Bit0 n) = Bit0 (times_num (Bit1 m) n)
  | times_num (Bit1 m) (Bit1 n) =
    Bit1 (plus_num (plus_num m n) (Bit0 (times_num m n)));

fun times_int k Zero_int = Zero_int
  | times_int Zero_int l = Zero_int
  | times_int (Pos m) (Pos n) = Pos (times_num m n)
  | times_int (Pos m) (Neg n) = Neg (times_num m n)
  | times_int (Neg m) (Pos n) = Neg (times_num m n)
  | times_int (Neg m) (Neg n) = Pos (times_num m n);

fun int_of_integer k =
  (if ((k : IntInf.int) = (0 : IntInf.int)) then Zero_int
    else (if ((k : IntInf.int) = (~1 : IntInf.int)) then uminus_int one_int
           else let
                  val (l, j) = divmod_integer k (2 : IntInf.int);
                  val la = times_int (Pos (Bit0 One)) (int_of_integer l);
                in
                  (if ((j : IntInf.int) = (0 : IntInf.int)) then la
                    else plus_int la one_int)
                end));

end; (*struct Veri7vn_Checker*)
