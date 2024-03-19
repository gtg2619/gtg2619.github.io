---
title: "R1CS to QAP in Python"
date: 2024-03-10T00:00:00+08:00
---

### R1CS to QAP in Python 

For constraint

$$
out = x⁴ - 5y²x² \\
=> \space\begin{equation}  
\left\{
             \begin{array}{**lr**}
             v_1 = x*x \\
             v_2 = v_1*v_1 \\
             v_3 = -5y * y \\
             -v_2 + out = v_3 * v_1
             \end{array}
\right.
\end{equation}
$$


we have new matrices are

```python
L = np.array([
    [0, 0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 74, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 1],
])

R = np.array([
    [0, 0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 1, 0, 0],
])

O = np.array([
    [0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 0, 0, 1],
    [0, 1, 0, 0, 0, 78, 0],
])
```

### Finite Field Arithmetic in Python

We can convert them to field arrays simply by wrapping them with GF like the following:

```python
L_galois = GF(L)
R_galois = GF(R)
O_galois = GF(O)

x = GF(4)
y = GF(79-2) # we are using 79 as the field size, so 79 - 2 is -2
v1 = x * x
v2 = v1 * v1         # x^4
v3 = GF(79-5)*y * y
out = v3*v1 + v2    # -5y^2 * x^2

witness = GF(np.array([1, out, x, y, v1, v2, v3]))

assert all(np.equal(np.matmul(L_galois, witness) * np.matmul(R_galois, witness), np.matmul(O_galois, witness))), "not equal"
```

and then do the lagrange interpolation for our computation

### Polynomial interpolation in finite fields

```python
def interpolate_column(col):
    xs = GF(np.array([1,2,3,4]))
    return galois.lagrange_poly(xs, col)

# axis 0 is the columns. apply_along_axis is the same as doing a for loop over the columns and collecting the results in an array
U_polys = np.apply_along_axis(interpolate_column, 0, L_galois)
V_polys = np.apply_along_axis(interpolate_column, 0, R_galois)
W_polys = np.apply_along_axis(interpolate_column, 0, O_galois)
```

### Computing h(x)

t(x) will be (x - 1)(x - 2)(x - 3)(x - 4) by interpolation, since we've introduct this in the last episode.

Each of the terms is taking the inner product of the witness with the column-interpolating polynomials. That is, each of summation terms are effectively the inner product between <1, a₁, …, aₘ> and <u₀(x), u₁(x), ..., uₘ(x)>

```python
def inner_product_polynomials_with_witness(polys, witness):
    mul_ = lambda x, y: x * y
    sum_ = lambda x, y: x + y
    return reduce(sum_, map(mul_, polys, witness))

term_1 = inner_product_polynomials_with_witness(U_polys, witness)
term_2 = inner_product_polynomials_with_witness(V_polys, witness)
term_3 = inner_product_polynomials_with_witness(W_polys, witness)
```

Note that we cannot compute h(x) unless we have a valid witness, as we have combined the witness into our polynomials.

```python
# t = (x - 1)(x - 2)(x - 3)(x - 4)
t = galois.Poly([1, 78], field = GF) * galois.Poly([1, 77], field = GF) * galois.Poly([1, 76], field = GF) * galois.Poly([1, 75], field = GF)

h = (term_1 * term_2 - term_3) // t
```

Unlike poly1d from numpy, the galois library won’t indicate to us if there is a remainder, so we need to check if the QAP formula is still true.

```python
assert term_1 * term_2 == term_3 + h * t, "division has a remainder"
```
