---
title: "Rank 1 Contraint Systems"
date: 2024-03-10T00:00:00+08:00
---

### Rank 1 Constraint Systems

### Witness vector

A witness means we don’t just know every input parameter, we must know every intermediate variable in this expanded form. 

For completeness of calculation, the witness vector starts with 1, followed by input, output and process variables

> It's based on the last episode `Arthimetic circuit`: If each step in the hash function can be proven to have been executed correctly, then the entire hash function can be proven to have been executed correctly, ***without executing the hash function***. Similar situation here.

### Polynomial transformation

Each row of our computation can only have one multiplication, so we must break up our equation as follows:

$$
out + (constants) = a\space*\space b\\
or\\
a\space*\space b - out + (constants) = 0
$$

and transform it to polynomial multiplication

$$
Cm = Am * Bm\\
or\\
Am * Bm -Cm = 0
$$

What needs to be done in the transformation is to configure appropriate parameters in the three vectors A, B, and C to comply with the constraints of the original polynomial.

### Example

5 example:


$$
(1)\space out=x*y\\
(2)\space out=x*y*z*u\\
(3)\space out=x*y+2\\
(4)\space out=2x^2+y\\
(5)\space out=3x^2y+5xy-x-2y+3
$$


The number of constraints(the number of occurrences of multiplication) is the minimum formula we need. More can be constructed by multiplying by one


$$
(1)\space out=x*y\space(1\space constraints)\\
(2)\space out=x*y*z*u\space(3\space constraints)\\
(3)\space out=x*y+2\space(1\space constraints)\\
(4)\space out=2x^2+y\space(1\space constraints)\\
(5)\space out=3x^2y+5xy-x-2y+3\space(3\space constraints)
$$


and then break up it (only write the fifth one)


$$
out=3x^2y+5xy-x-2y+3\\
=>\space\begin{equation}  
\left\{
             \begin{array}{**lr**}
             v_1=3x * x, &\\
             v_2=v_1 * y, &\\
             -v_2 + x + 2y -3 + out = 5xy
             \end{array}
\right.
\end{equation}
$$


Finally, we should constructed matrix for the constructed system of equations

we let witness be  $w=[1\space out\space x\space y\space v_1\space v_2]$

and then construct as following:


$$
A = \begin{bmatrix}
    0 & 0 & 3 & 0 & 0 & 0 \\
    0 & 0 & 0 & 0 & 1 & 0 \\
    0 & 0 & 5 & 0 & 0 & 0 
    \end{bmatrix}\\\\
B = \begin{bmatrix}
    0 & 0 & 1 & 0 & 0 & 0 \\
    0 & 0 & 0 & 1 & 0 & 0 \\
    0 & 0 & 0 & 1 & 0 & 0 
    \end{bmatrix}\\\\
C = \begin{bmatrix}
    0 & 0 & 0 & 0 & 1 & 0 \\
    0 & 0 & 0 & 0 & 0 & 1 \\
    -3 & 1 & 1 & 2 & 0 & -1 
    \end{bmatrix}\\
$$


Substituting it into the formula($Cm = Am * Bm\newline$) and perform matrix multiplication could obtain the above system of equations

### Circom implementation

In Circom (and many other frameworks), math is done modulo `21888242871839275222246405745257275088548364400416034343698204186575808495617`.

and the above work can be completed through circom

