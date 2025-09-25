
import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("Reputation & Trust Registry Tests", () => {
  
  beforeEach(() => {
    // Reset simnet state before each test
  });

  describe("Contract Initialization", () => {
    it("should initialize with correct default values", () => {
      const settings = simnet.callReadOnlyFn("reputation", "get-contract-settings", [], deployer);
      expect(settings.result).toStrictEqual(Cl.tuple({
        owner: Cl.principal(deployer),
        "decay-rate": Cl.uint(5),
        "min-stake": Cl.uint(1000000),
        "next-badge-id": Cl.uint(1)
      }));
    });

    it("should not be paused initially", () => {
      const isPaused = simnet.callReadOnlyFn("reputation", "is-contract-paused", [], deployer);
      expect(isPaused.result).toBeBool(false);
    });
  });

  describe("Staking Functionality", () => {
    it("should allow user to stake minimum amount", () => {
      const stakeResult = simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
      expect(stakeResult.result).toBeOk(Cl.bool(true));

      const userStake = simnet.callReadOnlyFn("reputation", "get-stake", [Cl.principal(wallet1)], deployer);
      expect(userStake.result).toBeOk(Cl.uint(1000000));
    });

    it("should reject stake below minimum", () => {
      const stakeResult = simnet.callPublicFn("reputation", "stake", [Cl.uint(500000)], wallet1);
      expect(stakeResult.result).toBeErr(Cl.uint(403)); // ERR-INVALID-AMOUNT
    });

    it("should allow additional staking", () => {
      // First stake
      simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
      
      // Additional stake
      const additionalStake = simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
      expect(additionalStake.result).toBeOk(Cl.bool(true));

      const userStake = simnet.callReadOnlyFn("reputation", "get-stake", [Cl.principal(wallet1)], deployer);
      expect(userStake.result).toBeOk(Cl.uint(2000000));
    });
  });

  describe("Unstaking Functionality", () => {
    beforeEach(() => {
      simnet.callPublicFn("reputation", "stake", [Cl.uint(2000000)], wallet1);
    });

    it("should allow full unstaking", () => {
      const unstakeResult = simnet.callPublicFn("reputation", "unstake", [], wallet1);
      expect(unstakeResult.result).toBeOk(Cl.uint(2000000));

      const userStake = simnet.callReadOnlyFn("reputation", "get-stake", [Cl.principal(wallet1)], deployer);
      expect(userStake.result).toBeOk(Cl.uint(0));
    });

    it("should allow partial unstaking", () => {
      const partialUnstake = simnet.callPublicFn("reputation", "partial-unstake", [Cl.uint(500000)], wallet1);
      expect(partialUnstake.result).toBeOk(Cl.uint(1500000));

      const userStake = simnet.callReadOnlyFn("reputation", "get-stake", [Cl.principal(wallet1)], deployer);
      expect(userStake.result).toBeOk(Cl.uint(1500000));
    });

    it("should reject partial unstaking below minimum", () => {
      const partialUnstake = simnet.callPublicFn("reputation", "partial-unstake", [Cl.uint(1500000)], wallet1);
      expect(partialUnstake.result).toBeErr(Cl.uint(402)); // ERR-INSUFFICIENT-STAKE
    });
  });

  describe("Reputation Management", () => {
    beforeEach(() => {
      simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
    });

    it("should allow owner to increment reputation", () => {
      const incrementResult = simnet.callPublicFn("reputation", "increment-reputation", 
        [Cl.principal(wallet1), Cl.uint(50)], deployer);
      expect(incrementResult.result).toBeOk(Cl.uint(50));

      const userRep = simnet.callReadOnlyFn("reputation", "get-reputation", [Cl.principal(wallet1)], deployer);
      expect(userRep.result).toBeOk(Cl.uint(50));
    });

    it("should reject reputation changes for unstaked users", () => {
      const incrementResult = simnet.callPublicFn("reputation", "increment-reputation", 
        [Cl.principal(wallet2), Cl.uint(50)], deployer);
      expect(incrementResult.result).toBeErr(Cl.uint(404)); // ERR-USER-NOT-FOUND
    });

    it("should allow authorized contracts to manage reputation", () => {
      // First authorize wallet2 as a contract
      simnet.callPublicFn("reputation", "authorize-contract", [Cl.principal(wallet2)], deployer);
      
      const incrementResult = simnet.callPublicFn("reputation", "increment-reputation", 
        [Cl.principal(wallet1), Cl.uint(25)], wallet2);
      expect(incrementResult.result).toBeOk(Cl.uint(25));
    });
  });

  describe("Badge System", () => {
    beforeEach(() => {
      simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
      simnet.callPublicFn("reputation", "increment-reputation", [Cl.principal(wallet1), Cl.uint(150)], deployer);
    });

    it("should mint badge for user with sufficient reputation", () => {
      const mintResult = simnet.callPublicFn("reputation", "mint-badge", 
        [Cl.principal(wallet1), Cl.stringAscii("Hero"), Cl.stringAscii("Heroic achievements")], deployer);
      expect(mintResult.result).toBeOk(Cl.uint(1));

      const badgeOwner = simnet.callReadOnlyFn("reputation", "get-badge-owner", [Cl.uint(1)], deployer);
      expect(badgeOwner.result).toBeSome(Cl.principal(wallet1));
    });

    it("should reject badge minting for insufficient reputation", () => {
      simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet2);
      simnet.callPublicFn("reputation", "increment-reputation", [Cl.principal(wallet2), Cl.uint(50)], deployer);
      
      const mintResult = simnet.callPublicFn("reputation", "mint-badge", 
        [Cl.principal(wallet2), Cl.stringAscii("Hero"), Cl.stringAscii("Heroic achievements")], deployer);
      expect(mintResult.result).toBeErr(Cl.uint(407)); // ERR-INSUFFICIENT-REPUTATION
    });

    it("should allow badge transfer between users", () => {
      simnet.callPublicFn("reputation", "mint-badge", 
        [Cl.principal(wallet1), Cl.stringAscii("Hero"), Cl.stringAscii("Heroic achievements")], deployer);
      
      const transferResult = simnet.callPublicFn("reputation", "transfer-badge", 
        [Cl.principal(wallet1), Cl.principal(wallet2), Cl.uint(1)], wallet1);
      expect(transferResult.result).toBeOk(Cl.bool(true));

      const badgeOwner = simnet.callReadOnlyFn("reputation", "get-badge-owner", [Cl.uint(1)], deployer);
      expect(badgeOwner.result).toBeSome(Cl.principal(wallet2));
    });
  });

  describe("Admin Functions", () => {
    it("should allow owner to pause contract", () => {
      const pauseResult = simnet.callPublicFn("reputation", "pause-contract", [], deployer);
      expect(pauseResult.result).toBeOk(Cl.bool(true));

      const isPaused = simnet.callReadOnlyFn("reputation", "is-contract-paused", [], deployer);
      expect(isPaused.result).toBeBool(true);
    });

    it("should reject non-owner pause attempts", () => {
      const pauseResult = simnet.callPublicFn("reputation", "pause-contract", [], wallet1);
      expect(pauseResult.result).toBeErr(Cl.uint(401)); // ERR-UNAUTHORIZED
    });

    it("should allow owner to update decay rate", () => {
      const updateResult = simnet.callPublicFn("reputation", "set-decay-rate", [Cl.uint(10)], deployer);
      expect(updateResult.result).toBeOk(Cl.bool(true));

      const settings = simnet.callReadOnlyFn("reputation", "get-contract-settings", [], deployer);
      expect(settings.result).toStrictEqual(Cl.tuple({
        owner: Cl.principal(deployer),
        "decay-rate": Cl.uint(10),
        "min-stake": Cl.uint(1000000),
        "next-badge-id": Cl.uint(1)
      }));
    });
  });

  describe("Reputation Decay", () => {
    beforeEach(() => {
      simnet.callPublicFn("reputation", "stake", [Cl.uint(1000000)], wallet1);
      simnet.callPublicFn("reputation", "increment-reputation", [Cl.principal(wallet1), Cl.uint(100)], deployer);
    });

    it("should apply decay to user reputation", () => {
      const decayResult = simnet.callPublicFn("reputation", "decay-reputation", [Cl.principal(wallet1)], deployer);
      expect(decayResult.result).toBeOk(Cl.uint(95)); // 100 - 5% = 95

      const userRep = simnet.callReadOnlyFn("reputation", "get-reputation", [Cl.principal(wallet1)], deployer);
      expect(userRep.result).toBeOk(Cl.uint(95));
    });
  });
});
