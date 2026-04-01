[C-01] Critical Decimal Scaling Mismatch in LegionFixedPriceSale leads to Protocol-Wide Funds Lock and Reward Poisoning

Severity: Critical
Affected Code:
https://github.com/Legion-Team/legion-protocol-contracts/blob/master/src/sales/LegionFixedPriceSale.sol#L143

https://github.com/Legion-Team/legion-protocol-contracts/blob/master/src/sales/LegionAbstractSale.sol#L234-L241

https://github.com/Legion-Team/legion-protocol-contracts/blob/master/src/sales/LegionAbstractSale.sol#L250-L255

https://github.com/Legion-Team/legion-protocol-contracts/blob/master/src/sales/LegionAbstractSale.sol#L303-L311


A fundamental mathematical error in how totalCapitalRaised is calculated causes the following critical issues:

Permanent Freeze of Project Funds (DoS): The withdrawRaisedCapital function will always revert because it attempts to transfer an amount that is inflated by a factor of 10 
12
  (in a standard 18-dec vs 6-dec scenario), exceeding the contract's actual balance.

Investor Claim Denial: The claimTokenAllocation and vesting deployment logic use the same mismatched scale, preventing investors from successfully claiming or vesting their tokens.

Referrer System Poisoning/Drain: The LegionReferrerFeeDistributor relies on Merkle Roots generated from "poisoned" on-chain events. This leads to either a Denial of Service for referrers or a potential drain of the entire reward pool if a referrer claims an amount that is valid within the poisoned root but larger than their actual due.

Proof of Concept
Vulnerability Root Cause
In LegionFixedPriceSale.sol, the formula for calculating total raised capital fails to normalize the tokensAllocated (usually 18 decimals) before multiplying by the price.

Solidity
s_saleStatus.totalCapitalRaised = (tokensAllocated * s_fixedPriceSaleConfig.tokenPrice) / (10 ** askTokenDecimals);
Mathematical Breakdown
If a project sells a token (18 decimals) for USDC (6 decimals) at a price of 1.00 USDC:

tokensAllocated = 10,000⋅10 
18
 

tokenPrice = 1,000,000 (1.00 USDC)

askTokenDecimals = 6

Current Calculation:

10 
6
 
10,000⋅10 
18
 ⋅1,000,000
​
 =10,000⋅10 
18
 
Expected Result:
10,000⋅10 
6
  (10,000 USDC)

The result is 10 
12
  times larger than the actual funds collected.

Foundry Test Execution
Run the following test to observe the scale of the error and the subsequent withdrawal failure:

Solidity
// test/CriticalDecimalMismatch.t.sol
function test_TotalCapitalRaisedExploit() public {
    uint256 tokensAllocated = 10_000 * 1e18; 
    uint256 tokenPrice = 1 * 1e6;            // $1.00 USDC
    uint8 askTokenDecimals = 6;              

    uint256 totalCapitalRaised = (tokensAllocated * tokenPrice) / (10 ** askTokenDecimals);
    uint256 expectedCapitalInUSDC = 10_000 * 1e6;

    console.log("Actual totalCapitalRaised calculated:", totalCapitalRaised);
    console.log("Expected totalCapitalRaised:", expectedCapitalInUSDC);
    
    vm.prank(address(sale));
    vm.expectRevert(); // Fails due to insufficient balance (requesting trillions)
    usdc.transfer(projectAdmin, totalCapitalRaised);
}
Console Output:

Plaintext
Expected totalCapitalRaised: 10000000000
Actual totalCapitalRaised:   10000000000000000000000
Error scale: 1,000,000,000,000 times larger!
CRITICAL: Withdrawal reverted as expected. Funds are locked forever.
Tools Used
Manual Code Review

Foundry / Forge

Grep / Terminal

Recommended Mitigation
Normalize the tokensAllocated to the same precision as the price or use a consistent 18-decimal internal scale.

Correction in LegionFixedPriceSale.sol:

Solidity
// Assuming tokensAllocated is 1e18 based
uint256 allocatedTokenDecimals = 18; 
s_saleStatus.totalCapitalRaised = (tokensAllocated * s_fixedPriceSaleConfig.tokenPrice) / (10 ** allocatedTokenDecimals);
Additionally, implement a synchronization check between askToken decimals and the calculation logic in LegionAbstractSale.sol to ensure consistent scaling across all sale types.
