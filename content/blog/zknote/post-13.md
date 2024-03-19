---
title: "Quadratic Arithmetic Programs over Elliptic Curves"
date: 2024-03-10T00:00:00+08:00
---

### Quadratic Arithmetic Programs over Elliptic Curves

For a formula with $n$ constraints and $m$ dimensional witness variables, the stardardized QAP:

$$
\sum_{i=0}^{m}a_iu_i\left(x\right)\sum_{i=0}^{m}a_iv_i\left(x\right) = \sum_{i=0}^{m}a_iw_i\left(x\right)+h\left(x\right)t\left(x\right)
$$

Calculate it just like the encryption of polynomial evaluation in the previous chapter, we need a trusted setup with agent doing the trusted setup picks a random value $\tau$ and for the generators $G_1$ and $G_2$ creates

$$
\left\langle [\tau^0G_1]_1,\ [\tau^1G_1]_1,\ ...,\ [\tau^{n-1}G_1]\right\rangle
$$

and apply it to every single subterm

$$
[u_i\left(\tau\right)]_1 = \sum_{j=0}^{m-1}u_{i,j}[\tau^jG_1]_1 = \left\langle u_{i,0},\ u_{i,1},\ ...u_{i,n-1}\right\rangle · \left\langle [\tau^0G_1]_1,\ [\tau^1G_1]_1,\ ...,\ [\tau^{n-1}G_1]\right\rangle
$$

*`·` notated hardmard product*

In the same way, we can also get

$$
[v_i\left(\tau\right)]_2 = \sum_{j=0}^{m-1}u_{i,j}[\tau^jG_2]_2 \\
[w_i\left(\tau\right)]_1 = \sum_{j=0}^{m-1}u_{i,j}[\tau^jG_1]_1
$$

and then evaluating $h\left(\tau\right)t\left(\tau\right)$ using the methods already introduced: $t(x)$ is interpolated through zero points, and $h(x)$ is obtained by division

We don’t want to multiply the encrypted evaluation of h and t, since an encrypted evaluation would results in an elliptic curve point, this would force us to introduce a pairing to evaluate the multiplication of $h(τ)$ and $t(τ)$

Because t(x) is known at the setup phase, and we know it has a power of $n$ (it’s part of the definition of the circuit), the setup agent can do the following:

$$
\left\langle[r^0t\left(\tau\right)G_1]_1,\ [r^1t\left(\tau\right)G_1]_1,...,[r^nt\left(\tau\right)G_1]_1\right\rangle \\
$$

after that we can compute 

$$
h\left(\tau\right)t\left(\tau\right) = \left\langle h_1, h2, ..., h_n\right\rangle · \left\langle[r^0t\left(\tau\right)G_1]_1,\ [r^1t\left(\tau\right)G_1]_1,...,[r^nt\left(\tau\right)G_1]_1\right\rangle
$$

We compute three elliptic curve points $[A]_1, [B]_2, [C]_1$ like in the chapter 10, and let prover do $pairing([A]₁,[B]₂) == pairing([C]₁,[G₂]₂)$, and accept if the equality is true.
