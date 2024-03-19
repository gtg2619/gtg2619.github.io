---
title: "Elliptic Curve Addition"
date: 2024-03-10T00:00:00+08:00
---

### Elliptic Curve

Elliptic curves are a family of curves which have the formula: 

$$
y^2 = x^3 + ax + b
$$

Elliptic Curves form an abelian group under addition.

**Identity elements**: The identity elements of ellipric curves is the point at infinity.

as long as we do not pick a perfectly vertical line, if we intersect two points in an elliptic curve, then we will also intersect a 3rd point on the elliptic curve.

**Inverse**: The inverse of an elliptic curve point is the negative of the y value of the pair.

One can derive how to compute P₃ = (x₃, y₃) where P₃ = P₁ ⊕ P₂ using the following formula.

$$
\lambda = \frac{y_2-y_1}{x_2-x_1}
\newline
x_3 = \lambda^2-x_1-x_2;\space y_3=\lambda\left(x_1-x_2\right) -y_1
$$

It has associativity:

$$
\left(a+b\right)P +cP = aP+\left(b+c\right)P
$$

- a != $$\alpha$$
