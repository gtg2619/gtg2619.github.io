---
title: "Arithmetic Circuits"
date: 2024-03-10T00:00:00+08:00
---

### Arithmetic Circuits

Zk circuits form a set of constraints that if satisfied, prove a computation was carried out correctly. Zk circuits are sometimes called arithmetic circuits because the “gates” in the circuit are addition and multiplication over a finite field. We are only allowed to use these two operators as a [finite field](https://www.rareskills.io/post/rings-and-fields) only has these two operations.

### prove a inverse

```python
field_size = 29 # some prime number

## Prover
def compute_inverse(a):
    return pow(a, -1, field_size)

a = 22
b = compute_inverse(a)

## Verifier
assert (a * b) % field_size == 1
```

### Proving a binary transformation

constrain 1

```python
b1 * (1 - b1) == 0
b2 * (1 - b2) == 0
b3 * (1 - b3) == 0
b4 * (1 - b4) == 0
```

constrain 2

```python
(8 * b1) + (4 * b2) + (2 * b3) + (1 * b4) == GIVEN_VALUE
```

### Proving a > b

Due to something like overflow or underflow in finite field, we could not simply check `a - b` or `b -a` to prove it.

but it could easily be done in curcuits since we could convert it into a comparison at the bit level.

Expand it:

1. Proving x is the maximum element in a list of elements: we could use it to check a list was properly sorted.

2. Proving a list contains no duplicates: we can ask the prover to sort the list (called **auxiliary computations**), verify it is sorted using the methodology from earlier, then check each element of the array to see if the entry next to it is equal.

### hash functions

If each step in the hash function can be proven to have been executed correctly, then the entire hash function can be proven to have been executed correctly, ***without executing the hash function***.

Proving each step of something like sha256 as a circuit is extremely non-trivial: it requires tens of thousands of constraints to prove every stage of this hash function.