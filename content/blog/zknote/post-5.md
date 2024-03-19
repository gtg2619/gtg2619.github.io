---
title: "Elliptic Curve over Finite Field"
date: 2024-03-10T00:00:00+08:00
---

### bn128 formula

The bn128 curve, which is used by the [Ethereum precompiles](https://www.rareskills.io/post/solidity-precompiles) to verify zk proofs, is specified as follows:

$$
y^2 = x^3 + 3\space\left(mod\space21888242871839275222246405745257275088696311157297823662689037894645226208583\right)
$$

The field_modulus should not be confused with the curve order, which is the number of points on the curve.



use the [Tonelli Shanks Algorithm](https://en.wikipedia.org/wiki/Tonelli–Shanks_algorithm) to compute modular square roots - you can treat it as a black box that computes the mathematical square root of a field element over a modulus, or lets you know if the square root does not exist.

use libnum to compute this

```python
from libnum import has_sqrtmod_prime_power, has_sqrtmod_prime_power, sqrtmod_prime_power

# the functions take arguments# has_sqrtmod_prime_power(n, field_mod, k), where n**k,
# but we aren't interested in powers in modular fields, so we set k = 1
# check if sqrt(8) mod 11 exists
print(has_sqrtmod_prime_power(8, 11, 1))
# False

# check if sqrt(5) mod 11 exists
print(has_sqrtmod_prime_power(5, 11, 1))
# True

# compute sqrt(5) mod 11
print(list(sqrtmod_prime_power(5, 11, 1)))
# [4, 7]

assert (4 ** 2) % 11 == 5
assert (7 ** 2) % 11 == 5

# we expect 4 and 7 to be inverses of each other, because in "regular" math, the two solutions to a square root are sqrt and -sqrt
assert (4 + 7) % 11 == 0
```

### Generating elliptic curve cyclic group y² = x³ + 3 (mod 11)

```python
import libnum
import matplotlib.pyplot as plt

def generate_points(mod):
    xs = []
    ys = []
    def y_squared(x):
        return (x**3 + 3) % mod

    for x in range(0, mod):
        if libnum.has_sqrtmod_prime_power(y_squared(x), mod, 1):
            square_roots = libnum.sqrtmod_prime_power(y_squared(x), mod, 1)

            # we might have two solutions
            for sr in square_roots:
                ys.append(sr)
                xs.append(x)
    return xs, ys


xs, ys = generate_points(11)
fig, (ax1) = plt.subplots(1, 1);
fig.suptitle('y^2 = x^3 + 3 (mod p)');
fig.set_size_inches(6, 6);
ax1.set_xticks(range(0,11));
ax1.set_yticks(range(0,11));
plt.grid()
plt.scatter(xs, ys)
plt.show()
```

- Just like the real-valued plot, the modular one “appears symmetric”

The order is not the modulus

### Python bn128 library

The library the EVM implementation [pyEVM](https://github.com/ethereum/py-evm) uses for the elliptic curve precompiles is [py ecc](https://github.com/ethereum/py_ecc).

```python
from py_ecc.bn128 import G1, multiply, add, eq, neg

print(G1)
# (1, 2)

print(add(G1, G1))
# (1368015179489954701390400359078579693043519447331113978918064868415326638035, 9918110051302171585080402603319702774565515993150576347155970296011118125764)

print(multiply(G1, 2))
#(1368015179489954701390400359078579693043519447331113978918064868415326638035, 9918110051302171585080402603319702774565515993150576347155970296011118125764)

# 10G + 11G = 21G
assert eq(add(multiply(G1, 10), multiply(G1, 11)), multiply(G1, 21))
```

generate one thousand point in front

```python
import matplotlib.pyplot as plt
from py_ecc.bn128 import G1, multiply, neg
import math
import numpy as np
xs = []
ys = []
for i in range(1,1000):
    xs.append(i)
    ys.append(int(multiply(G1, i)[1]))
    xs.append(i)
    ys.append(int(neg(multiply(G1, i))[1]))
plt.scatter(xs, ys, marker='.')
plt.show()
```

Addition in a finite field is homomorphic to addition among elliptic curve points (when their order is equal). Because of the discrete logarithm, another party can add elliptic curve points together without knowing which field elements generated those points.



The **field modulus** is the modulo we do the curve over. The **curve order** is the number of points on the curve.

If you start with a point r and add the curve order o, you will get r back.

```python
from py_ecc.bn128 import curve_order, field_modulus, G1, multiply, eq

x = 5 # chosen randomly
# This passes
assert eq(multiply(G1, x), multiply(G1, x + curve_order))

# This fails
assert eq(multiply(G1, x), multiply(G1, x + field_modulus))
```

The implication of this is that (x + y) mod curve_order == xG + yG.

```python
x = 2 ** 300 + 21
y = 3 ** 50 + 11

# (x + y) == xG + yG
assert eq(multiply(G1, (x + y)), add(multiply(G1, x), multiply(G1, y)))
assert eq(multiply(G1, (x + y) % curve_order), add(multiply(G1, x), multiply(G1, y)))
```

Even though the x + y operation will clearly “overflow” over the curve order, this doesn’t matter. The elliptic curve multiplication is implicitly executing the same operation as taking the modulus before doing the multiplication.

- Encoding rational numbers: we cannot compute `multiply(G1, 1 / 2)` but in a finite field, $1 / 2$ can be meaningfully computed as the multiplicative inverse of 2. Transfer `1 / 2 ` to `pow(1,2,curve_order)` allow us to compute this. 

### *Details of computing the modulus of a fraction

For the fraction $\frac{a}{b}$ saitisfied $\gcd(a,b)=1 $ , existing a  $c = \frac{a}{b}\ mod\ x$ 

According to Fermat's little theorem $a^{p-1} = 1(mod \ p)$ we could know

$$
a^{p-2}(mod\ p) = (a^{p-1}(mod\ p)*a^{-1}(mod\ p))(mod\ p) \ = a^{-1}(mod\ p)
$$

It can be further derived that

$$
\frac{a}{b} (mod\ p) = (a  b^{-1})(mod\ p) \ = (a (mod\ p) * b^{-1} (mod\ p))(mod\ p) \ = (a (mod\ p) * b^{p-2} (mod\ p))(mod\ p)
$$

### Every element has an inverse

The `py_ecc` library supplies us with the neg function which will provide the inverse of a given element. The library encodes the “point at infinity” as a python None.

```python
from py_ecc.bn128 import G1, multiply, neg, is_inf, Z1, add, eq

# pick a field element
x = 12345678# generate the point
p = multiply(G1, x)

# invert
p_inv = neg(p)

# every element added to its inverse produces the identity element
assert is_inf(add(p, p_inv))

# Z1 is just None, which is the point at infinity
assert Z1 is None

# special case: the inverse of the identity is itself
assert eq(neg(Z1), Z1)
```

### optimized_bn128

optimized_bn128 is faster while structures EC points as 3-tuples -- which are harder to interpret.

### Basic zero knowledge proofs with elliptic curves

Consider this rather trivial example:

Claim: “I know two values x and y such that x + y = 15”

Proof: I multiply x by G1 and y by G1 and give those to you as A and B.

Verifier: You multiply 15 by G1 and check that A + B == 15G1.

Here it is in python

```python
from py_ecc.bn128 import G1, multiply, add

# Prover
secret_x = 5
secret_y = 10

x = multiply(G1, 5)
y = multiply(G1, 10)

proof = (x, y, 15)

# verifier
if multiply(G1, proof[2]) == add(proof[0], proof[1]):
    print("statement is true")
else:
    print("statement is false")
```

### Security assumptions

The security of the elliptic curve encryption algorithm relies on the difficulty of the discrete logarithm problem, which means that it is hard to deduce the value of x from the point `(a, b)` generated by `multiply(G1, x)`.

There are mores sophisticated algorithms, like the [baby step giant step algorithm](https://en.wikipedia.org/wiki/Baby-step_giant-step) that can outperform brute force.

It is possible to engineer zero knowledge proofs using basic number theory rather than elliptic curves, but since every modern zero knowledge algorithm uses elliptic curves, they are worth learning.

### How ECDSA malleability attack works.

As we documented in our [smart contract security](https://www.rareskills.io/post/smart-contract-security) article, given a valid signature (r, s, v, hash(msg)), one can forge another valid signature for the same message by doing the following:

```
// create a fake s for (r, s, v), then flip v
bytes32 s2 = bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141) - uint256(s));
```

Where does this magic number come from? ECDSA uses the secp256k1 curve, which has the following parameters:

```
p = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f
y^2 = x^3 + 7 (mod p)
order = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141
```

Note that the order is the same as the magic number.

The hack relies on the following identity

```
multiply(G1, (order - x)) == neg(multiply(G1, x))
```

Here is the code to illustrate

```
# Test
order = 21888242871839275222246405745257275088548364400416034343698204186575808495617
x = 100 # chosen randomly
assert multiply(G1, order - x) == neg(multiply(G1, x))
```

Recall that neg(multiply(G1, x)) is simply the same x, but with the y value flipped.

```
x = 100 # chosen randomly
assert int(multiply(G1, x)[0]) == int(neg(multiply(G1, x))[0])
```





- Multiplying the curve order times the generator is the point at infinity.
