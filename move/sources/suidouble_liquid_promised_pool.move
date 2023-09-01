
module suidouble_liquid::suidouble_liquid_promised_pool {
    friend suidouble_liquid::suidouble_liquid;

    use suidouble_liquid::suidouble_liquid_coin;
    use suidouble_liquid::suidouble_liquid_staker;


    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui_system::staking_pool::{Self, StakedSui};
    use sui::tx_context::{TxContext};


    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool

    // struct SuidoubleLiquidPromisedPoolStillStaked has store {
    //     staked_sui: StakedSui,
    //     expected_sui_amount: u64, // amount using for pay-off, the rest extra rewards can be sent back to pending pool
    // }

    struct SuidoubleLiquidPromisedPool has store {
        promised_amount: u64,
        promised_sui: Balance<SUI>,
        promised_staked: vector<StakedSui>,
    }

    public(friend) fun default(): SuidoubleLiquidPromisedPool {
        let pool = SuidoubleLiquidPromisedPool { 
            promised_amount: 0,
            promised_sui: balance::zero<SUI>(),
            promised_staked: vector::empty(),
        };

        pool 
    }

    public(friend) fun promised_amount(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool): u64 { 
        suidouble_liquid_promised_pool.promised_amount 
    }

    /**
    *  Promise some amount of mSUI
    */
    public(friend) fun increment_promised_amount(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, by_amount: u64) {
        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount + by_amount;
    }

    public(friend) fun fulfill_with_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, sui: Balance<SUI>) {
        // @todo: check if passed more than needed
        let amount = balance::value(&sui);
        balance::join(&mut suidouble_liquid_promised_pool.promised_sui, sui);
        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount - amount;
    }

    public(friend) fun take_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        coin::take(&mut suidouble_liquid_promised_pool.promised_sui, amount, ctx)
    } 

    // public(friend) fun promise_sui(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, sui: &mut Balance<SUI>)

    // public(friend) fun promise(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, suidouble_liquid_promised_pool: &suidouble_liquid_staker::SuidoubleLiquidStaker, amount: u64) {

    // } 
    
}