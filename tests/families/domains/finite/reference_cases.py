"""Independent finite enumeration used to derive native regression targets.
This does not execute or qualify the Isabelle implementation.
"""
from fractions import Fraction
from itertools import product, permutations
from collections import Counter


def main():
    cards = tuple(range(4))
    good = {0, 1}
    replaced = list(product(cards, repeat=2))
    distinct = list(permutations(cards, 2))
    measure = lambda xs: Fraction(sum(all(c in good for c in row) for row in xs), len(xs))
    assert measure(replaced) == Fraction(1, 4)
    assert measure(distinct) == Fraction(1, 6)
    offspring = list(product("Aa", "Aa"))
    assert Fraction(offspring.count(("a", "a")), len(offspring)) == Fraction(1, 4)
    assert sum(7 in row for row in product(range(1, 7), repeat=2)) == 0
    xs = [Fraction(0), Fraction(2)]
    mean = sum(xs) / len(xs)
    squares = sum((x - mean) ** 2 for x in xs)
    assert squares / len(xs) == 1
    assert squares / (len(xs) - 1) == 2
    counts = Counter([1, 1, 2, 2, 3])
    assert {x for x, n in counts.items() if n == max(counts.values())} == {1, 2}
    print("finite independent enumeration: 7 targets passed; no native qualification claimed")


if __name__ == "__main__":
    main()
