// [bonus] unit test for bonus.circom
const {assert, expect} = require("chai");
const wasm_tester = require("circom_tester").wasm;

const F1Field = require("ffjavascript").F1Field;
const Scalar = require("ffjavascript").Scalar;
exports.p = Scalar.fromString("21888242871839275222246405745257275088548364400416034343698204186575808495617");
const Fr = new F1Field(exports.p);

describe("Duel circuit", function () {
  this.timeout(100000000);

  async function prove (input) {
    const circuit = await wasm_tester("contracts/circuits/bonus.circom");
    const witness = await circuit.calculateWitness(input, true);
    return {
      buildHash: Fr.e(witness[1]),
      attackDamage: Fr.e(witness[2]),
      attackSpeed: Fr.e(witness[3]),
      health: Fr.e(witness[4])
    }
  }

  it("Build is hashed with salt", async function () {
    const proofWithSalt0 = await prove({
      "incomingAttackDamage": "0",
      "incomingAttackSpeed": "0",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "0",
    })
    const proofWithSalt1 = await prove({
      "incomingAttackDamage": "0",
      "incomingAttackSpeed": "0",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "1",
    })

    assert(proofWithSalt0.buildHash !== proofWithSalt1.buildHash, 'build hash should be different when salt is different')
  });

  it("Regular attack has correct damage and speed and does not heal", async function () {
    const proof = await prove({
      "incomingAttackDamage": "0",
      "incomingAttackSpeed": "0",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "0"
    })

    assert.equal(proof.attackDamage, Fr.e(30), 'attackDamage should be 30');
    assert.equal(proof.attackSpeed, Fr.e(60), 'attackSpeed should be 60');
    assert.equal(proof.health, Fr.e(100), 'health should be 100');
  });

  it("Heavy attack has correct damage and speed and does not heal", async function () {
    const proof = await prove({
      "incomingAttackDamage": "0",
      "incomingAttackSpeed": "0",
      "preAttackHealth": "100",
      "move": "2",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "0"
    })

    assert.equal(proof.attackDamage, Fr.e(60), 'attackDamage should be 60');
    assert.equal(proof.attackSpeed, Fr.e(30), 'attackSpeed should be 30');
    assert.equal(proof.health, Fr.e(100), 'health should be 100');
  });

  it("Healing heals 20% of base health and does not attack", async function () {
    const proof = await prove({
      "incomingAttackDamage": "0",
      "incomingAttackSpeed": "0",
      "preAttackHealth": "100",
      "move": "3",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "0"
    })

    assert.equal(proof.health, Fr.e(180), 'health should be 180');
    assert.equal(proof.attackDamage, Fr.e(0), 'attackDamage should be 0');
    assert.equal(proof.attackSpeed, Fr.e(0), 'attackSpeed should be 0');
  });

  it("Incoming attack is absorbed with no evasion", async function () {
    const proof = await prove({
      "incomingAttackDamage": "60",
      "incomingAttackSpeed": "30",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "40",
      "strength": "30",
      "dexterity": "30",
      "salt": "0"
    })

    assert.equal(proof.health, Fr.e(40), 'health should be 40');
  });

  it("Incoming attack is absorbed with positive evasion", async function () {
    const proof = await prove({
      "incomingAttackDamage": "60",
      "incomingAttackSpeed": "30",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "30",
      "strength": "30",
      "dexterity": "40",
      "salt": "0"
    })

    assert.equal(proof.health, Fr.e(46), 'health should be 46');
  });

  it("Incoming attack is absorbed with negative evasion", async function () {
    const proof = await prove({
      "incomingAttackDamage": "60",
      "incomingAttackSpeed": "30",
      "preAttackHealth": "100",
      "move": "1",
      "vitality": "30",
      "strength": "40",
      "dexterity": "20",
      "salt": "0"
    })

    assert.equal(proof.health, Fr.e(34), 'health should be 34');
  });

  it("Healing is not possible if health reaches zero after an attack", async function () {
    try {
      await prove({
        "incomingAttackDamage": "60",
        "incomingAttackSpeed": "30",
        "preAttackHealth": "60",
        "move": "3",
        "vitality": "40",
        "strength": "30",
        "dexterity": "30",
        "salt": "0"
      })

      expect.fail('An error should be thrown when health reaches zero')
    } catch (e) {
    }
  });
});