---
title: "Zero Knowledge Proofs with Rank 1 Contraint Systems"
date: 2024-03-10T00:00:00+08:00
---

### Zero Knowledge Proofs with Rank 1 Constraint Systems

Last episode we write r1cs as the following:
$$
Cm = Am * Bm\\
or\\
Am * Bm -Cm = 0
$$
but here we write it as
$$
Ls⊙Rs=Os
$$
while ⊙ is the paring function(Hadamard product). nothing different bertween them.

If we “encrypt” the witness vector by multiplying each entry with G₁ or G₂, the math will still work properly.



**For a given verification process, the matrices L, R, and O used for verification are common to both parties in the communication.**

### Prover steps

compute $Ls$ and $Rs$ in two different EC group(paring friendly)
$$
Ls = L * s * G_1 \\
Rs = R * s * G_2
$$
then hand the results and the G1, G2 to `Verifier`

### Verification step

Verify if $pairing(Ls, Rs) = pairing(Os, 1)$. For reduce the difficulty of calculation, we do not use $G_{12}$ to  directly encrypt $Os$ , because $G_{12}$ is a massive point.

And $pairing(Os, 1)$ could be $paring\left(O * s * G_1), G_2\right)$ or $paring\left(O * s * G_2), G_1\right)$ . The results are equivalent

### Public inputs

some of our variable could be public (not encrypted on EC), like if we wants to prove $x³ + 5x + 5 = 155$, the $1$ and $out$ in the possible witness vector $[1, out, x, v]$ could be public.

