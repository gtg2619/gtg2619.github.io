---
title: "Bilinear Pairings"
date: 2024-03-10T00:00:00+08:00
---

### Bilinear Pairings

Bilinear parings allow us to take three numbers, $a$, $b$, and $c$, where $ab = c$, encrypt them to become $E(a), E(b), E(c)$, where $E$ is an encryption function, then send the three encrypted values to a verifier who can verify $E(a)E(b) = E(c)$ but not know the original values. We can use bilinear pairings to prove that a 3rd number is the product of the first two without knowing the original numbers.

The feature of bilinear pairings that we care about is as follows ( $e$ is the bilinear pairing fuction/mapping):

$$
e: G × G → G_T\newline
e\left(aG,bG\right) = e\left(abG,G\right) = e\left(G,abG\right)
$$

The essential property of bilinear pairings is that if you plug in two points that are multiples of the generator point (aG and bG), the result is equal to plugging in the product of those two numbers times the generator point (abG) and the generator point itself (G).

In practice however, it turns out to be easier to create bilinear pairings when a different group is different for both of the arguments and the output result. 

Specifically, we say

$$
e\left(a, b\right) \rightarrow c, a \in G, b \in G^{′}, c \in G^{′′}
$$

which still statisfied $e\left(aG,bG^{′}\right) = e\left(abG,G^{′}\right) = e\left(G,abG^{′}\right)$ 

This is an asymmetric pairing, whereas the previous formula within the same domain is a symmetric pairing.

### Field Extensions

Ethereum’s bilinear pairing of choice uses elliptic curves *with field extensions*, which have higher dimensional, and still have the properties of cyclic groups that you care about

- closed under addition, which is associative
- has an identity element
- each element has an inverse
- the group has a generator

The bilinearity property is hard to come by. -- Its difficult for three randomly chosen elliptic curve groups to satisfied $e\left(aG,bG^{′}\right) = e\left(abG,G^{′}\right) = e\left(G,abG^{′}\right)$ 

### Bilinear Pairings in python

```python
from py_ecc.bn128 import G1, G2, pairing, add, multiply, eq

print(G1)
# (1, 2)
print(G2)
# ((10857046999023057135944570762232829481370756359578518086990519993285655852781, 11559732032986387107991004021392285783925812861821192530917403151452391805634), (8495653923123431417604973247489272438418190587263600148770280649306958101930, 4082367875863433681332203403145435568316851327593401208105741076214120093531))

# operator overloading
print(G1 + G1 + G1 == G1*3)
# True
# The above is the same as this:
eq(add(add(G1, G1), G1), multiply(G1, 3))

# pairing
A = multiply(G2, 5)
B = multiply(G1, 6)
print(pairing(A, B))
# (2737733771970589720147436295258995541017562764748775046990018238171083065584, 7355949162177082646197064865377481127039528955264110892670278171102027012957, 1389120597320745437757553030085914762401499323567753964656133081964131780715, 4070774491543958907062047566637569178763974576144707726129772744684275725184, 10823414137019623021013733227099721415368303324105358213304652659949682568395, 12697986880222911287030392175914090722292212037466224705879408804162602333706, 17697943997237703208660786428217562403504798830995307420075922564993565300645, 2702065915136914071855531840006964465333491722231468583849464437921405019853, 6762652910450025398171695126080749677225757293012137750262928324249233167133, 9495821522287762858490254871883860235240788822777455638443279749602676973720, 17813117134675140440034537765301248350834713246854720915775731738875700896539, 21027635025043266481235488683404016989778194881701554135606154029160033599034)

pairing(A, B) == pairing(C, G1)
```

### Bilinear Pairings in Ethereum

The [py_ecc library](https://github.com/ethereum/py_ecc) is actually maintained by the [Ethereum Foundation](https://ethereum.org/), and it is what powers the precompile at address 0x8 in the [PyEVM](https://github.com/ethereum/py-evm) implementation.

The specification of this precompile will seem a little weird at first. It takes in a list of G1 and G2 points laid out as follows:

$$
A_1B_1A_2B_2...A_nB_n : A_i \in G1, B_i \in G2
$$

These were originally created as

$$
A_1 = a_1G1\newline
B_1 = b_1G2\newline
A_2 = a_2G1\newline
B_2 = b_2G2\newline
...\newline
A_n = a_nG1\newline
B_n = b_nG2
$$

The precompile returns 1 if the following is true

$$
a_1b_1 + a_2b_2 + ... + a_nb_n = 0
$$

and zero otherwise.

It's used by [tornado cash](https://www.rareskills.io/post/how-does-tornado-cash-work) ,with verification formula:

$$
e\left(A_1, B_2\right) = e\left(\alpha_1, \beta_2\right) + e\left(L_1, \gamma_2\right) + e\left(C_1, \delta_2\right)
$$

### Sum of preimages

The key insight here is that if

$$
ab + cd = 0
$$

Then it must also be true that

$$
A_1B_2 + C_1D_2 = 0_{12} \space\space\space\space\space A_1,C_1 \in G1, B_2,D_2 \in G2
$$

### End to End Solidity Example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
contract Pairings {
    /** 
     *  returns true if == 0,
     *  returns false if != 0,
     *  reverts with "Wrong pairing" if invalid pairing
     */
     function run(uint256[12] memory input) public view returns (bool) {
        assembly {
            let success := staticcall(gas(), 0x08, input, 0x0180, input, 0x20)
            if success {
                return(input, 0x20)
            }
        }
        revert("Wrong pairing");
    }
}
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/Pairings.sol";

contract PairingsTest is Test {
    Pairings public pairings;

    function setUp() public {
        pairings = new Pairings();
    }

    function testPairings() public view {
        uint256 aG1_x = 3010198690406615200373504922352659861758983907867017329644089018310584441462;
        uint256 aG1_y = 17861058253836152797273815394432013122766662423622084931972383889279925210507;

        uint256 bG2_x1 = 2725019753478801796453339367788033689375851816420509565303521482350756874229;
        uint256 bG2_x2 = 7273165102799931111715871471550377909735733521218303035754523677688038059653;
        uint256 bG2_y1 = 2512659008974376214222774206987427162027254181373325676825515531566330959255;
        uint256 bG2_y2 = 957874124722006818841961785324909313781880061366718538693995380805373202866;

        uint256 cG1_x = 4503322228978077916651710446042370109107355802721800704639343137502100212473;
        uint256 cG1_y = 6132642251294427119375180147349983541569387941788025780665104001559216576968;

        uint256 dG2_x1 = 18029695676650738226693292988307914797657423701064905010927197838374790804409;
        uint256 dG2_x2 = 14583779054894525174450323658765874724019480979794335525732096752006891875705;
        uint256 dG2_y1 = 2140229616977736810657479771656733941598412651537078903776637920509952744750;
        uint256 dG2_y2 = 11474861747383700316476719153975578001603231366361248090558603872215261634898;

        uint256[12] memory points = [
            aG1_x,
            aG1_y,
            bG2_x2,
            bG2_x1,
            bG2_y2,
            bG2_y1,
            cG1_x,
            cG1_y,
            dG2_x2,
            dG2_x1,
            dG2_y2,
            dG2_y1
        ];

        bool x = pairings.run(points);
        console2.log("result:", x);
    }
}
```

Its important to note that the ecPairing precompile does not expect or require an array and that our choice of using one with inline-assembly is simply optional.

