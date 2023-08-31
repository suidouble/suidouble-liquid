
module suidouble_liquid::suidouble_liquid_staker {
    friend suidouble_liquid::suidouble_liquid;
    use suidouble_liquid::suidouble_liquid_coin;

    use std::vector;
    use sui_system::sui_system::SuiSystemState;
    use sui_system::sui_system::active_validator_addresses;
    use sui_system::staking_pool::{Self, StakedSui};

    struct SuidoubleLiquidStaker has store {
        staked_pool: vector<StakedSui>,
        staked_amount: u64,
    }

    const MINIMUM_VALIDATORS_COUNT: u64 = 3;

    public(friend) fun staked_amount(suidouble_liquid_staker: &SuidoubleLiquidStaker): u64 { 
        suidouble_liquid_staker.staked_amount 
    }

    // public(friend) fun staked_with_rewards_amount(suidouble_liquid_staker: &SuidoubleLiquidStaker, wrapper: &mut SuiSystemState, epoch: u64): u64 {
    //     suidouble_liquid_coin::expected_staked_balance(&suidouble_liquid_staker.staked_pool, wrapper, ctx)
    // }

    public(friend) fun default(wrapper: &mut SuiSystemState): SuidoubleLiquidStaker {
        // let currently_active_validators:vector<address> = active_validator_addresses(wrapper); 
        // let n = vector::length(&currently_active_validators);
        // let i = 0;

        // let validators_to_use = vector::empty<address>();
        // while (i < n && i < MINIMUM_VALIDATORS_COUNT) {
        //     let validator_address = vector::remove(&mut currently_active_validators, 0);
        //     vector::push_back(&mut validators_to_use, validator_address);
        // };

        let liquid_staker = SuidoubleLiquidStaker { 
            staked_pool: vector::empty(),
            staked_amount: 0,
        };

        liquid_staker 
    }

    public(friend) fun random_validator_address(wrapper: &mut SuiSystemState, random: vector<u8>): address {
        let currently_active_validators:vector<address> = active_validator_addresses(wrapper); 
        let n = vector::length(&currently_active_validators);

        let random_as_1 = (*vector::borrow(&random, 1));
        let random_as_2 = (*vector::borrow(&random, 2));
        let random_index = ( (random_as_1 as u64) * 256 + (random_as_2 as u64) ) % n;   

        let validator_address = vector::remove(&mut currently_active_validators, random_index);

        validator_address
    }
    
}