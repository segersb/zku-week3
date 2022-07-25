// [bonus] implement an example game from part d
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

template Duel() {
    // public inputs
    signal input incomingAttackDamage;
    signal input incomingAttackSpeed;
    signal input preAttackHealth;
    signal input move;

    // private inputs
    signal input vitality;
    signal input strength;
    signal input dexterity;
    signal input salt;

    // outputs
    signal output buildHash;
    signal output attackDamage;
    signal output attackSpeed;
    signal output health;

    component buildPoseidon = Poseidon(4);
    buildPoseidon.inputs[0] <== vitality;
    buildPoseidon.inputs[1] <== strength;
    buildPoseidon.inputs[2] <== dexterity;
    buildPoseidon.inputs[3] <== salt;
    buildHash <== buildPoseidon.out;

    var baseHealth = vitality * 10;
    var evasion = dexterity - incomingAttackSpeed;
    var incomingAttackDamageAfterEvasion = incomingAttackDamage - (incomingAttackDamage * evasion / 100);
    var postAttackHealth = preAttackHealth - incomingAttackDamageAfterEvasion;
    
    component postAttackHealthGreaterThanZero = GreaterThan(16);
    postAttackHealthGreaterThanZero.in[0] <== postAttackHealth;
    postAttackHealthGreaterThanZero.in[1] <== 0;
    postAttackHealthGreaterThanZero.out === 1;

    component attachDamageSwitch = Switch(2);
    attachDamageSwitch.expression <== move;
    attachDamageSwitch.cases[0] <== 1; // regular attack
    attachDamageSwitch.cases[1] <== 2; // heavy attack
    attachDamageSwitch.returns[0] <== strength;
    attachDamageSwitch.returns[1] <== strength * 2;
    attackDamage <== attachDamageSwitch.out;

    component attachSpeedSwitch = Switch(2);
    attachSpeedSwitch.expression <== move;
    attachSpeedSwitch.cases[0] <== 1; // regular attack
    attachSpeedSwitch.cases[1] <== 2; // heavy attack
    attachSpeedSwitch.returns[0] <== dexterity * 2;
    attachSpeedSwitch.returns[1] <== dexterity;
    attackSpeed <== attachSpeedSwitch.out;

    component healthRegenerationCondition = EqualityCondition();
    healthRegenerationCondition.a <== move;
    healthRegenerationCondition.b <== 3;
    healthRegenerationCondition.ifTrue <== postAttackHealth + (baseHealth * 20 / 100);
    healthRegenerationCondition.ifFalse <== postAttackHealth;

    component maxHealthCondition = GreaterThanCondition(16);
    maxHealthCondition.a <== healthRegenerationCondition.out;
    maxHealthCondition.b <== baseHealth;
    maxHealthCondition.ifTrue <== baseHealth;
    maxHealthCondition.ifFalse <== healthRegenerationCondition.out;

    health <== maxHealthCondition.out;
}

template Condition() {
    signal input condition;
    signal input ifTrue;
    signal input ifFalse;
    signal output out;

    out <== (ifTrue - ifFalse) * condition + ifFalse;
}

template EqualityCondition() {
    signal input a;
    signal input b;
    signal input ifTrue;
    signal input ifFalse;
    signal output out;

    component isEqual = IsEqual();
    isEqual.in[0] <== a;
    isEqual.in[1] <== b;

    component condition = Condition();
    condition.condition <== isEqual.out;
    condition.ifTrue <== ifTrue;
    condition.ifFalse <== ifFalse;

    out <== condition.out;
}

template GreaterThanCondition(bits) {
    signal input a;
    signal input b;
    signal input ifTrue;
    signal input ifFalse;
    signal output out;

    component greaterThan = GreaterThan(bits);
    greaterThan.in[0] <== a;
    greaterThan.in[1] <== b;

    component condition = Condition();
    condition.condition <== greaterThan.out;
    condition.ifTrue <== ifTrue;
    condition.ifFalse <== ifFalse;

    out <== condition.out;
}

template Switch(n) {
    signal input expression;
    signal input cases[n];
    signal input returns[n];
    signal output out;

    component caseConditions[n];
    var outputAccumulator = 0;

    for (var i = 0; i < n; i++) {
        caseConditions[i] = EqualityCondition();
        caseConditions[i].a <== expression;
        caseConditions[i].b <== cases[i];
        caseConditions[i].ifTrue <== returns[i];
        caseConditions[i].ifFalse <== 0;
        outputAccumulator += caseConditions[i].out;
    }

    out <== outputAccumulator;
}

component main { public [incomingAttackDamage, incomingAttackSpeed, preAttackHealth, move] } = Duel();