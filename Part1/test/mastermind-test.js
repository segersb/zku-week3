//[assignment] write your own unit test to show that your Mastermind variation circuit is working as expected
const {expect, assert} = require("chai");
const wasm_tester = require("circom_tester").wasm;

const F1Field = require("ffjavascript").F1Field;
const Scalar = require("ffjavascript").Scalar;
exports.p = Scalar.fromString("21888242871839275222246405745257275088548364400416034343698204186575808495617");
const Fr = new F1Field(exports.p);

describe("Mastermind circuit", function () {
  this.timeout(100000000);

  async function prove (input) {
    const circuit = await wasm_tester("contracts/circuits/MastermindVariation.circom");
    const witness = await circuit.calculateWitness(input, true);
    return {
      codeHash: Fr.e(witness[1]),
      codeSum: Fr.e(witness[2]),
      exactMatches: Fr.e(witness[3]),
      partialMatches: Fr.e(witness[4])
    }
  }

  it("Code is hashed with salt", async function () {
    const proofWithSalt0 = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [1, 2, 3, 4],
      "codeSalt": "0"
    })
    const proofWithSalt1 = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [1, 2, 3, 4],
      "codeSalt": "1"
    })

    assert(proofWithSalt0.codeHash !== proofWithSalt1.codeHash, 'code hash should be different when salt is different')
  });

  it("Code numbers are summed correctly", async function () {
    const proof = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [1, 2, 3, 4],
      "codeSalt": "0"
    })

    assert.equal(proof.codeSum, Fr.e(10), 'code digits should sum up to 10')
  });

  it("Guess numbers are all right", async function () {
    const proof = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [1, 2, 3, 4],
      "codeSalt": "0"
    })

    assert.equal(proof.exactMatches, Fr.e(4), 'exactMatches should be 4');
    assert.equal(proof.partialMatches, Fr.e(0), 'partialMatches should be 0');
  });

  it("Guess numbers are all partial", async function () {
    const proof = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [4, 3, 2, 1],
      "codeSalt": "0"
    })

    assert.equal(proof.exactMatches, Fr.e(0), 'exactMatches should be 0')
    assert.equal(proof.partialMatches, Fr.e(4), 'partialMatches should be 4')
  });

  it("Guess numbers contain wrong digits", async function () {
    const proof = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [3, 4, 5, 6],
      "codeSalt": "0"
    })

    assert.equal(proof.exactMatches, Fr.e(0), 'exactMatches should be 0')
    assert.equal(proof.partialMatches, Fr.e(2), 'partialMatches should be 2')
  });

  it("Guess numbers contain correct and partial digits", async function () {
    const proof = await prove({
      "guessNumbers": [1, 2, 3, 4],
      "codeNumbers": [1, 2, 4, 3],
      "codeSalt": "0"
    })

    assert.equal(proof.exactMatches, Fr.e(2), 'exactMatches should be 2')
    assert.equal(proof.partialMatches, Fr.e(2), 'partialMatches should be 2')
  });

  it("Guess numbers contain invalid digits", async function () {
    try {
      await prove({
        "guessNumbers": [1, 2, 3, 9],
        "codeNumbers": [1, 2, 3, 4],
        "codeSalt": "0"
      })

      expect.fail('An error should be thrown when guess numbers are invalid')
    } catch (e) {
    }
  });

  it("Code numbers contain invalid digits", async function () {
    try {
      await prove({
        "guessNumbers": [1, 2, 3, 4],
        "codeNumbers": [1, 2, 3, 9],
        "codeSalt": "0"
      })

      expect.fail('An error should be thrown when guess numbers are invalid')
    } catch (e) {
    }
  });

  it("Guess numbers contain duplicate digits", async function () {
    try {
      await prove({
        "guessNumbers": [1, 2, 3, 3],
        "codeNumbers": [1, 2, 3, 4],
        "codeSalt": "0"
      })

      expect.fail('An error should be thrown when guess numbers are invalid')
    } catch (e) {
    }
  });

  it("Code numbers contain duplicate digits", async function () {
    try {
      await prove({
        "guessNumbers": [1, 2, 3, 4],
        "codeNumbers": [1, 2, 3, 3],
        "codeSalt": "0"
      })

      expect.fail('An error should be thrown when guess numbers are invalid')
    } catch (e) {
    }
  });
});