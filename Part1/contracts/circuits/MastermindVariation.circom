pragma circom 2.0.0;

// [assignment] implement a variation of mastermind from https://en.wikipedia.org/wiki/Mastermind_(board_game)#Variation as a circuit

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

// Number mastermind variation
// - code is 4 long with digits from 1 to 6 (parameterizable)
// - code maker also provides the sum of the digits

template MastermindVariation(digits, maxDigit) {
    assert(maxDigit <= 9);

    // public inputs
    signal input guessNumbers[digits];

    // private inputs
    signal input codeNumbers[digits];
    signal input codeSalt;

    // outputs
    signal output codeHash;
    signal output codeSum;
    signal output exactMatches;
    signal output partialMatches;

    // check code and guess digits are valid
    component codeNumbersInRange[digits];
    component guessNumbersInRange[digits];
    component codeNumbersDistinct = IsDistinct(digits, 4);
    component guessNumbersDistinct = IsDistinct(digits, 4);
    for (var i = 0; i < digits; i++) {
        codeNumbersInRange[i] = IsInClosedRange(4);
        codeNumbersInRange[i].a <== 1;
        codeNumbersInRange[i].b <== maxDigit;
        codeNumbersInRange[i].x <== codeNumbers[i];
        codeNumbersInRange[i].out === 1;

        guessNumbersInRange[i] = IsInClosedRange(4);
        guessNumbersInRange[i].a <== 1;
        guessNumbersInRange[i].b <== maxDigit;
        guessNumbersInRange[i].x <== guessNumbers[i];
        guessNumbersInRange[i].out === 1;

        codeNumbersDistinct.in[i] <== codeNumbers[i];
        guessNumbersDistinct.in[i] <== guessNumbers[i];
    }
    codeNumbersDistinct.out === 1;
    guessNumbersDistinct.out === 1;

    // calculate code hash
    component codeHashPoseidon = Poseidon(digits + 1);
    for (var i = 0; i < digits; i++) {
        codeHashPoseidon.inputs[i] <== codeNumbers[i];
    }
    codeHashPoseidon.inputs[digits] <== codeSalt;
    codeHash <== codeHashPoseidon.out;

    // calculate code sum
    var codeSumAccumulator = 0;
    for (var i = 0; i < digits; i++) {
        codeSumAccumulator += codeNumbers[i];
    }
    codeSum <== codeSumAccumulator;

    // guess and code equality checks
    component guessCodeEqual[digits];
    component guessCodeEqualAny[digits];
    for (var guessIndex = 0; guessIndex < digits; guessIndex++) {
        guessCodeEqual[guessIndex] = IsEqual();
        guessCodeEqual[guessIndex].in[0] <== guessNumbers[guessIndex];

        guessCodeEqualAny[guessIndex] = IsEqualAny(digits);
        guessCodeEqualAny[guessIndex].a <== guessNumbers[guessIndex];

        for (var codeIndex = 0; codeIndex < digits; codeIndex++) {
            if (guessIndex == codeIndex) {
                guessCodeEqual[guessIndex].in[1] <== codeNumbers[codeIndex];
            }
            guessCodeEqualAny[guessIndex].b[codeIndex] <== codeNumbers[codeIndex];
        }
    }

    // calculate correct and partial matches
    var partialMatchesAccumulator = 0;
    var exactMatchesAccumulator = 0;
    for (var guessIndex = 0; guessIndex < digits; guessIndex++) {
        exactMatchesAccumulator += guessCodeEqual[guessIndex].out;
        partialMatchesAccumulator += guessCodeEqualAny[guessIndex].out - guessCodeEqual[guessIndex].out;
    }
    exactMatches <== exactMatchesAccumulator;
    partialMatches <== partialMatchesAccumulator;
}

/*
    Checks whether the input array contains distinct values
    size: the size of the input array
    bits: the maximum bits of the elements
*/
template IsDistinct(size, bits) {
    assert(size >= 2);

    signal input in[size];
    signal output out;

    // the total number of checks is the summation of size-1, ie 1 + 2 + 3 + ... + size-1
    // summation formula is (n**2 + n) / 2
    var equalsSize = ((size - 1) ** 2 + size - 1) / 2;
    component equals[equalsSize];

    // iterate from first to second last element
    var equalsIndex = 0;
    for (var i = 0; i < size - 1; i++) {
        // iterate from next to last element
        for (var j = i + 1; j < size; j++) {
            equals[equalsIndex] = IsEqual();
            equals[equalsIndex].in[0] <== in[i];
            equals[equalsIndex].in[1] <== in[j];
            equalsIndex++;
        }
    }

    component anyEqual = MultiOR(equalsSize);
    for (var i = 0; i < equalsSize; i++) {
        anyEqual.inputs[i] <== equals[i].out;
    }

    out <== 1 - anyEqual.out;
}

/*
    Checks whether input x falls in the closed range [a,b]: a <= x <= b
    n: the maximum number of bits for values a, b and x
*/
template IsInClosedRange(n) {
    signal input a;
    signal input b;
    signal input x;
    signal output out;

    component xGreaterEqA = GreaterEqThan(n);
    xGreaterEqA.in[0] <== x;
    xGreaterEqA.in[1] <== a;

    component xLessEqB = LessEqThan(n);
    xLessEqB.in[0] <== x;
    xLessEqB.in[1] <== b;

    component xInRangeAB = AND();
    xInRangeAB.a <== xGreaterEqA.out;
    xInRangeAB.b <== xLessEqB.out;

    out <== xInRangeAB.out;
}

template IsEqualAny(n) {
    assert(n > 2);

    signal input a;
    signal input b[n];
    signal output out;

    component abEquals[n];
    component abEqualsOR = MultiOR(n);

    for (var i = 0; i < n; i++) {
        abEquals[i] = IsEqual();
        abEquals[i].in[0] <== a;
        abEquals[i].in[1] <== b[i];
        abEqualsOR.inputs[i] <== abEquals[i].out;
    }

    out <== abEqualsOR.out;
}

template MultiOR(n) {
    assert(n > 2);

    signal input inputs[n];
    signal output out;

    component inputOR[n - 1];

    inputOR[0] = OR();
    inputOR[0].a <== inputs[0];
    inputOR[0].b <== inputs[1];

    for (var i = 1; i < n - 1; i++) {
        inputOR[i] = OR();
        inputOR[i].a <== inputOR[i - 1].out;
        inputOR[i].b <== inputs[i + 1];
    }

    out <== inputOR[n - 2].out;
}

component main { public [guessNumbers] } = MastermindVariation(4, 6);