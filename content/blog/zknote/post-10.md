---
title: "Quadratic Arithmetic Programs"
date: 2024-03-10T00:00:00+08:00
---

### Quadratic Arithmetic Programs

A Quadratic Arithmetic Program (QAP) is a system of equations where the coefficients are monovariate polynomials and a valid solution results in a single polynomial equality. They are quadratic because they have exactly one polynomial multiplication.



### homomorphic between vector and lagrange polynomial

binary operator equivalence between vectors and interpolating polynomials, including adding and `Hadamard product` between two vector and multiply a vector with a scalar.



### Schwartz-Zippel Lemma

The Schwartz-Zippel Lemma states that if two polynomials are randomly evaluated at the same x value, and their y value is the same, then one can be nearly certain that they are the same polynomial.



### Convert matrix computing in R1CS to polynomial computing

Original R1CS:
$$
\left(U · a\right)(V · a) = W · a
$$
For each colomns in $U\ V\ W\ $and$\ a$ matrix perform Lagrangian interpolation transformation we could get
$$
\sum_{i=0}^{m}a_iu_i\sum_{i=0}^{m}a_iv_i = \sum_{i=0}^{m}a_iw_i
$$
In this formula, $a_i$ and $u_i$ take out the column numbered i as a vector, and $m$ is the columns count of $U\ V\ W\ a$.

Then according to the lemma mentioned above, polynomial comparison can be performed by setting the parameters of the polynomial.
$$
\sum_{i=0}^{m}a_iu_i\left(x\right)\sum_{i=0}^{m}a_iv_i\left(x\right) = \sum_{i=0}^{m}a_iw_i\left(x\right)
$$

### the above QAP is imbalanced

xxxxxxxxxx assert term_1 * term_2 == term_3 + h * t, "division has a remainder"python

If we add a zero vector, we aren’t changing the equality, but if the zero vector is transformed to a polynomial degree four (which interpolates y = 0 at x = {1, 2, 3, 4}), then we can have the right-hand side be a degree four polynomial, and the left-hand-side have a degree four polynomial, making it possible for them to be equal everywhere. 

now we let the zero vector to be `t(x) · h(x)`.



### get t(x) and h(x)

`t(x)` could easily get by lagrange interpolation `[0, 0, 0 ...]`. 

It should be obvious that although t(x) represents the zero vector (it has roots at x = 1,2,3…), it won’t necessarily balance the equation $(U·a)(V·a) = (W·a) + t(x)$. We need to multiply it by yet another polynomial that interpolates zero and balances out the equation.

When two non-zero polynomials are multiplied, the roots of the product is the union of the roots of the individual polynomials.

Therefore, we can multiply t(x) by anything except zero, and it will still correspond to a zero vector in vector land.
$$
(U·a)(V·a) - (W·a) = 0\\
(U·a)(V·a) - (W·a) = h(x)t(x)\\
\frac{(U·a)(V·a) - (W·a)}{t(x)} = h(x)
$$
then we could write the final calculation to be 
$$
\sum_{i=0}^{m}a_iu_i\left(x\right)\sum_{i=0}^{m}a_iv_i\left(x\right) = \sum_{i=0}^{m}a_iw_i\left(x\right)+h\left(x\right)t\left(x\right)
$$

### encrypted polynomial evaluation

Neither the prover nor the verifier should know the random point the polynomials are being evaluated at, otherwise the prover can cheat.

So the trusted setup computes
$$
[xG], [x^2G], [x^3G]\ ...
$$
And the prover computes the polynomials (U·a), (V·a), (W·a), and h(x) by multiplying those elliptic curve points with their polynomial coefficients.

The prover just need to check `pairing([A], [B]) = [C'] + [HT]` where A, B, C' are respectively the calculated elliptic curve points.
