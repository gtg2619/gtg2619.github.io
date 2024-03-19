---
title: "Set Theory"
date: 2024-03-10T00:00:00+08:00
---

### Set

Cartesian product: a set such that every element from one set is one part of an ordered pair with an element from another set

function is a subset of the cartesian product

reversed subset: superset

A subset need not be strictly smaller than the set it is a part of

Cardinality means the count of elements in a finite set



union: 并集

intersection: 交集



### mapping/fuction

mapping between sets comes about by taking a subset of their cartesian product

[axiom of choice](https://en.wikipedia.org/wiki/Axiom_of_choice): The cartesian product of a collection of non-empty sets is non-empty.

The floor function simply removes the decimal portion of a number.

When defining a function with a cartesian product, the same domain element cannot map to two different co-domain elements.



### Injective, Surjective, and Bijective functions

An injective function means the elements in the codomain have *at most* one preimage. If one of the elements does not have a preimage, that is okay, but if more than one element in the domain maps to the same element, it is not injective. We can also say that if an output element has a preimage, then it is unique.

A surjective function means the elements in the codomain has *at least* one preimage. If an element in the codomain does not have a preimage, the function is not surjective.

A function is bijective if and only if it is injective and surjective.



### Properties of binary operators over sets

Magma: A magma is a set with a closed binary operator.

Semigroup: A semigroup is a magma where the binary operator must be associative.

Monoid: A monoid is a semigroup with an identity element. (An identity element means you do a binary operator with the identity element and another element a, you get a. In the example of addition 8 + 0 = 8, where 0 is the identity element)

Group: A group is a monoid where each element has an inverse.Or to be explicit, it is a set with three properties

- a closed and associative binary operator (a semigroup)

- an identity element (a monoid)

- every element has an inverse. That is, there exists an inverse element of the set such that the binary operator of an element and its inverse produces the identity element.

Abelian Group: an abelian group, also called a commutative group, is a group in which the result of applying the group operation to two group elements does not depend on the order in which they are written. That is, the group operation is commutative. With addition as an operation, the integers and the real numbers form abelian groups, and the concept of an abelian group may be viewed as a generalization of these examples.

