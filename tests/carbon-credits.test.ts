import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;

describe("Carbon Credit Tracking", () => {
  it("should allow contract owner to authorize verifiers", () => {
    const response = simnet.callPublicFn(
      "renewable-project-manager",
      "authorize-verifier",
      [Cl.principal(wallet_1), Cl.uint(2)],
      deployer
    );

    expect(response.result).toBeOk(Cl.bool(true));
  });

  it("should verify carbon credit functionality is available", () => {
    const nextId = simnet.callReadOnlyFn(
      "renewable-project-manager",
      "get-next-credit-id",
      [],
      deployer
    );

    expect(nextId.result).toBeUint(1);
  });

  it("should check if verifier is authorized", () => {
    // First authorize a verifier
    simnet.callPublicFn(
      "renewable-project-manager",
      "authorize-verifier",
      [Cl.principal(wallet_1), Cl.uint(3)],
      deployer
    );

    const isVerified = simnet.callReadOnlyFn(
      "renewable-project-manager",
      "is-verified-verifier",
      [Cl.principal(wallet_1)],
      deployer
    );

    expect(isVerified.result).toBeBool(true);

    const notVerified = simnet.callReadOnlyFn(
      "renewable-project-manager",
      "is-verified-verifier",
      [Cl.principal(wallet_2)],
      deployer
    );

    expect(notVerified.result).toBeBool(false);
  });

  it("should return none for non-existent credits", () => {
    const creditInfo = simnet.callReadOnlyFn(
      "renewable-project-manager",
      "get-carbon-credit",
      [Cl.uint(999)],
      deployer
    );

    expect(creditInfo.result).toBeNone();

    const ownerInfo = simnet.callReadOnlyFn(
      "renewable-project-manager",
      "get-credit-owner",
      [Cl.uint(999)],
      deployer
    );

    expect(ownerInfo.result).toBeNone();
  });
});
