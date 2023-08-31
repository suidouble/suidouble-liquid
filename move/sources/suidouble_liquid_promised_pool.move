
module suidouble_liquid::suidouble_liquid_staker {
    friend suidouble_liquid::suidouble_liquid;
    use suidouble_liquid::suidouble_liquid_coin;
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool

    struct SuidoubleLiquidPromisedPoolStillStaked has store {
        staked_sui: StakedSui,
        expected_sui_amount: u64, // amount using for pay-off, the rest extra rewards can be sent back to pending pool
    }

    struct SuidoubleLiquidPromisedPool has store {
        promised_amount: u64,
        promised_sui: Balance<SUI>,
        promised_staked: vector<SuidoubleLiquidPromisedPoolStillStaked>,
    }

    public(friend) fun default(): SuidoubleLiquidPromisedPool {
        let pool = SuidoubleLiquidPromisedPool { 
            promised_amount: 0,
            promised_sui: balance::zero<SUI>(),
            promised_staked: vector::empty(),
        };

        pool 
    }
    
}