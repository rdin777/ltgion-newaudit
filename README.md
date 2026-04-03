Markdown
# Legion Protocol Security Audit (Research Edition) 🛡️

This repository contains security research, audit artifacts, and Proof-of-Concepts (PoC) for the Legion Protocol smart contracts.

## 📊 Audit Overview
- **Framework:** Foundry
- **Scope:** Vesting, Sales, and Core Protocol Logic
- **Total Tests:** 595 [PASS]

---

## 🚨 Critical Finding: Broken Epoch Vesting Logic
**Severity:** Critical  
**Contract:** `LegionLinearEpochVesting.sol`  
**Vulnerability Type:** Logic Error / State Dependency / Precision Loss

### 📝 Description
The implementation of `_vestingSchedule` contains a fundamental flaw in how it calculates vested amounts. Instead of being a pure function of time, it depends on the mutable state variable `s_lastClaimedEpoch`.

```solidity
if (currentEpoch > s_lastClaimedEpoch) {
    amountVested = ((currentEpoch - 1) * _totalAllocation) / s_numberOfEpochs;
}
💥 Impact
Double-Claim Denial: If a user or a bot calls release() twice within the same epoch, the second call returns amountVested = 0, potentially locking legitimate funds.

Precision Loss (Dust): The use of a fixed 1e18 denominator (from Constants.sol) without scaling for low-decimal tokens (e.g., USDC, USDT) leads to permanent rounding errors where the "dust" remains stuck in the contract forever.

🛠️ Proof of Concept (PoC)
To run the reproduction test:

Bash
forge test --match-path test/poc/LegionEpochBreaker.t.sol -vvvv
🛠️ How to Run Tests
Clone the repo:

Bash
git clone [https://github.com/rdin777/ltgion-newaudit.git](https://github.com/rdin777/ltgion-newaudit.git)
cd ltgion-newaudit
Install dependencies:

Bash
forge install
Run full suite:

Bash
forge test
👨‍💻 Author
RimDinov (rdin777) Smart Contract Auditor & Security Researcher
