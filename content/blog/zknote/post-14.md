---
title: "Groth16 Explained"
date: 2024-03-10T00:00:00+08:00
---

### Groth16 Explained

The groth16 algorithm enables a quadratic arithmetic program to be computed by a prover over elliptic curve points derived in a trusted setup, and quickly checked by a verifier. It uses auxiliary elliptic curve points from the trusted setup to prevent forged proofs.



In our chapter on evaluating a Quadratic Arithmetic Program at a hidden point τ, we had a significant issue that the prover can simply invent values a, b, c where ab = c and present those as elliptic curve points to the verifier.

Thus, the verifier has no idea if elliptic curve points $[A]_1$, $[B]_2$, and $[C]_1$ were the result of a satisfied QAP or made up values.

### Preventing forgery using α and β

update $[A]_1$ and $[B]_2$
$$
[A]_1 \leftarrow [A]_1 + [\alpha]_1 \\
[B]_2 \leftarrow [B]_2 + [\beta]_2 \\
$$
Naturally, the formula used for verification also needs to be modified.

For the original formula we have
$$
\sum_{i=0}^{m}a_iu_i\left(x\right)\sum_{i=0}^{m}a_iv_i\left(x\right) = \sum_{i=0}^{m}a_iw_i\left(x\right)+h\left(x\right)t\left(x\right)
$$

Substitute it into the modified formula to replace

$$
\left(\sum_{i=0}^{m}a_iu_i\left(x\right)+\alpha\right)\left(\sum_{i=0}^{m}a_iv_i\left(x\right)+\beta\right) = \alpha\beta+\beta\sum_{i=0}^{m}a_iu_i\left(x\right)+\alpha\sum_{i=0}^{m}a_iv_i\left(x\right)+\sum_{i=0}^{m}a_iu_i\left(x\right)\sum_{i=0}^{m}a_iv_i\left(x\right)
$$

thus we have
$$
\left(\sum_{i=0}^{m}a_iu_i\left(x\right)+\alpha\right)\left(\sum_{i=0}^{m}a_iv_i\left(x\right)+\beta\right) = \alpha\beta+\sum_{i=0}^ma_i\left(\beta u_i(x)+\alpha v_i(x)+w_i(x)\right)+h(x)t(x)
$$
That is the verification process that verifier needs to do, $pairing([A]_1, [B]_2)= pairing([\alpha]_1,[\beta]_2)+pairing([C]_1,G_2)$

### separating public and private inputs with γ and δ

how we split the QAP into the portions computed by the verifier (the public inputs) and the prover (the private inputs):
$$
\sum_{i=0}^{m}a_iw_i(x) = \sum_{i=0}^{\vartheta}a_iw_i(x) + \sum_{i=\vartheta+1}^{m}a_iw_i(x)
$$


thus our proving formula would be optimized:
$$
pairing([A]_1, [B]_2) = \\
pairing([\alpha]_1,[\beta]_2)\\
+ pairing(\sum_{i=0}^{\vartheta}a_i\left(\beta u_i(x)+\alpha v_i(x)+w_i(x)\right),G_2) + \sum_{i=\vartheta+1}^ma_i\left[\beta u_i(x)+\alpha v_i(x)+w_i(x)\right]_1+[h(x)t(x)]_1
$$

### Preventing forgeries with public inputs

To prevent this, the trusted setup agent divides w₀(τ) and w₁(τ) by a secret variable γ the prover portion by a different variable δ. The encrypted versions of these variables [γ] and [δ] are made available so that the verifier and prover can cancel them out if they are honest.

Verification step with γ and δ:

Instead of pairing with G₂ at the verification step, we pair with [γ] and [δ], The [γ] and [δ] terms will cancel out if the prover truly used the polynomials from the trusted setup. The prover (and verifier) do not know the field element that corresponds to [δ], so they cannot cause the terms to cancel out unless they use the values from the trusted setup.

### Enforcing true zero knowledge: r and s

If an attacker is able to guess our witness vector (which is possible if there is only a small range of valid inputs, e.g. secret voting from privileged addresses), then they can verify their guess is correct by comparing their constructed proof to the original proof.

To do this, we introduce another random shift, but this time at the proving phase instead of the setup phase.





