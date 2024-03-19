---
title: "Encrypted Polynomial Evalution"
date: 2024-03-10T00:00:00+08:00
---

### Encrypted Polynomial Evaluation

### Encrypted Exponentiation

Known pairing mappings satisfy the requirement for single-multiplication homomorphisms (Further pairings lead to huge dimensions, which is unacceptable for concise zkp), but we still need to do homomorphic encryption for exponents.

For that purpose, we could let prover computes the encrypted value of $x$, $x^2$, and $x_3$ and gives those the verifier separately. The supplied cryptographic parameters are still valid for the verifier because the supplied cryptographic parameters are within a computable (given) elliptic curve group.

```python
from py_ecc.bn128 import G1, multiply, add, neg, eq

# Prover
x = 5

X3 = multiply(G1, 5**3)
X2 = multiply(G1, 5**2)
X = multiply(G1, 5)

# Verifier
left_hand_side = multiply(G1, 39)
right_hand_side = add(add(add(multiply(X3, 1),
                              multiply(neg(X2), 4)),
                              multiply(X, 3)),
                              multiply(neg(G1), 1))

assert eq(left_hand_side, right_hand_side), "lhs ≠ rhs"
```

### Trusted Setup

Counterintuitively, we typically use the above construction in reverse.

For evaluation of the polynomial

$$
result = \sum_{i=0}^{d}c_i x^i
$$

we have a trusted third party generate a secret $\tau$ value and encrypt it as

$$
\tau[G],\ \tau^2[G],\ \tau^3[G]\ ...\ \tau^d[G]
$$

And the prover will plug this into their polynomial with coefficients $c_i$

$$
[result] = c_0[G]+c_1[\tau G]+c_2[\tau^2 G]+...+c_d[\tau^d G]
$$

The `[result]` is the same value as if we had evaluated the polynomial directly:

$$
[result] = c_0[G]+c_1\tau [G]+c_2\tau^2 [G]+...+c_d\tau^d [G]
$$

The important point here is that we can evaluate polynomials using elliptic curve points and get a valid output, but without knowing the point we evaluated the polynomial at.

### polynomials over finite fields

```python
from py_ecc.bn128 import G1, multiply, add, curve_order, eq, Z1
from functools import reduce
import galois

print("initializing a large field, this may take a while...")
GF = galois.GF(curve_order)

def inner_product(ec_points, coeffs):
    return reduce(add, (multiply(point, int(coeff)) for point, coeff in zip(ec_points, coeffs)), Z1)

def generate_powers_of_tau(tau, degree):
    return [multiply(G1, int(tau ** i)) for i in range(degree + 1)]

# p = (x - 4) * (x + 2)
p = galois.Poly([1, -4], field=GF) * galois.Poly([1, 2], field=GF)

# evaluate at 8
tau = GF(8)

# evaluate then convert
powers_of_tau = generate_powers_of_tau(tau, p.degree)
evaluate_then_convert_to_ec = multiply(G1, int(p(tau)))

# evaluate via encrypted evaluation# coefficients need to be reversed to match the powers
evaluate_on_ec = inner_product(powers_of_tau, p.coeffs[::-1])

if eq(evaluate_then_convert_to_ec, evaluate_on_ec):
    print("elliptic curve points are equal")
```

### xxxxxxxxxx assert term_1 * term_2 == term_3 + h * t, "division has a remainder"python

_Pure copying. I think I need to understand it later_

The Schwartz-Zippel Lemma says that two unequal polynomials almost never overlap except at a number of points constrained by the degree. In a big prime finite field (i.e. a prime number with a couple hundred bits), the degree is going to be vanishingly small compared to the order of the field. So if we evaluate two different polynomials at a random point x and they evaluate to the same value, then we can be almost perfectly certain the two polynomials are the same *even if we don’t know the polynomials*.

As it is, we have enough tooling for a prover to prove to the verifier that they have four polynomials 𝓐(x), 𝓑(x), 𝓒(x), and 𝓓(x) such that 𝓐𝓑 = 𝓒𝓓, and the verifier can certify this fact without learning the polynomials.

The prover will execute the encrypted evaluation of all four polynomials to obtain scalars A, B, C, and D and give that to the verifier. The verifier can then carry out AB = CD to see the prover’s claim is true. The prover doesn’t know what point they are evaluating at so they can’t architect polynomials that intersect at the point the third party setup chose (assuming no collusion).

Okay, we have AB = CD, but how is that useful?

This starts to get interesting when the verifier can require the prover to use a known polynomial for D. This is not enough for the verifier to learn A, B, or C, but it puts known constraints on what polynomials the prover can use for A, B, and C.

For example, one important feature is that the verifier now knows AB has the same roots (and possible others) as D because when polynomials are multiplied by a non-zero polynomial, the roots of the product polynomial is the union of the roots of the constituent polynomials. Therefore, the roots of polynomial 𝓓 must be a subset of the roots of 𝓐𝓑.

Another subtle way to constrain the verifier is to only supply them encrypted powers of x up to a limited power. This constrains the degree of the polynomial 𝓐𝓑.

A unknown polynomial with a known upper bound on the degree and a known set of roots is not unique, but nonetheless “says something” and can be used to encode information with some clever transformations. This should start to give you a foggy idea of how succinct zero knowledge proofs are possible.

Another teaser is that the setup ceremony “powers of tau” derives its name from creating a lot of powers of a hidden value so encrypted polynomials can be calculated from it, similar to what we described in this section.

The purpose of this article is only to introduce the concept of a trusted setup and encrypted polynomial evaluation, so we must stop here. But now that we know how to handle addition, multiplication, and exponentiation in an encrypted manner, we are ready to encode and encrypt arbitrary calculations, with the added bonus that we have a vague idea of how to make them succinct.
