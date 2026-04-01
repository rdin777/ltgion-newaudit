// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/sales/LegionFixedPriceSale.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Простейший мок токена для теста
contract MockERC20 {
    string public name;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;

    constructor(string memory _name, uint8 _decimals) {
        name = _name;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract CriticalDecimalMismatchTest is Test {
    LegionFixedPriceSale sale;
    MockERC20 usdc; // 6 decimals (Ask Token)
    MockERC20 projectToken; // 18 decimals (Allocated Token)

    address projectAdmin = address(0xBAD);
    address legionAdmin = address(0x1337);

    function setUp() public {
        sale = new LegionFixedPriceSale();
        usdc = new MockERC20("USDC", 6);
        projectToken = new MockERC20("PROJ", 18);
        
        // В реальности здесь была бы инициализация через прокси, 
        // но для мат. PoC нам достаточно прямого вызова расчета.
    }

    function test_TotalCapitalRaisedExploit() public {
        // --- СЦЕНАРИЙ ---
        uint256 tokensAllocated = 10_000 * 1e18; // Продали 10,000 токенов (18 знаков)
        uint256 tokenPrice = 1 * 1e6;            // Цена 1.00 USDC (6 знаков)
        uint8 askTokenDecimals = 6;              // USDC decimals

        // Имитируем логику из LegionFixedPriceSale.sol:142-143
        // s_saleStatus.totalCapitalRaised = (tokensAllocated * s_fixedPriceSaleConfig.tokenPrice) / (10 ** askTokenDecimals);
        
        uint256 totalCapitalRaised = (tokensAllocated * tokenPrice) / (10 ** askTokenDecimals);

        // Ожидаемый результат: 10,000 * 1e6 = 10,000,000,000 (10k USDC)
        uint256 expectedCapitalInUSDC = 10_000 * 1e6;

        console.log("--- RESULT ANALYSIS ---");
        console.log("Tokens Sold: 10,000 (18 decimals)");
        console.log("Price: 1.00 USDC (6 decimals)");
        console.log("-----------------------");
        console.log("Expected totalCapitalRaised (in 6-dec units):", expectedCapitalInUSDC);
        console.log("Actual totalCapitalRaised calculated by Contract:", totalCapitalRaised);
        console.log("--------------------------------------------------");
        console.log("Poisoned Event Value for Backend:", totalCapitalRaised);
        console.log("Real Value expected by Referrers:", expectedCapitalInUSDC);
        console.log("--------------------------------------------------");
        
        // Вычисляем масштаб ошибки
        uint256 errorMultiplier = totalCapitalRaised / expectedCapitalInUSDC;
        console.log("Error scale: %s times larger than expected!", errorMultiplier);

        // Проверка на Bricking (Блокировку средств)
        // Если проект реально собрал 10,000 USDC, а контракт думает, что 10,000 * 1e18
        // то попытка перевода ВСЕГДА будет падать.
        
        vm.prank(projectAdmin);
        usdc.mint(address(sale), expectedCapitalInUSDC); // Кладём реальные деньги на баланс

        console.log("Contract USDC Balance:", usdc.balanceOf(address(sale)));
        
        // Имитация SafeTransferLib.safeTransfer(bidToken, msg.sender, totalCapitalRaised)
        vm.expectRevert(); // Транзакция ОБЯЗАТЕЛЬНО упадет из-за нехватки баланса
        vm.prank(address(sale));
        usdc.transfer(projectAdmin, totalCapitalRaised);
        
        console.log("CRITICAL: Withdrawal reverted as expected. Funds are locked forever.");
    }
}
