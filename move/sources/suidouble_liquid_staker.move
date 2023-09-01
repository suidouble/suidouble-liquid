
module suidouble_liquid::suidouble_liquid_staker {
    friend suidouble_liquid::suidouble_liquid;
    friend suidouble_liquid::suidouble_liquid_promised_pool;

    use suidouble_liquid::suidouble_liquid_coin;
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool

    use std::vector;
    use sui_system::sui_system::SuiSystemState;
    use sui_system::sui_system::active_validator_addresses;
    use sui_system::sui_system::pool_exchange_rates;
    use sui_system::staking_pool::{Self, StakedSui};
    use sui::table::{Table, Self};

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, sender, TxContext};

    use sui_system::sui_system::request_add_stake_non_entry;
    use sui_system::sui_system::request_withdraw_stake_non_entry;

    struct SuidoubleLiquidStaker has store {
        staked_pool: vector<StakedSui>,
        staked_amount: u64,
    }

    const MINIMUM_VALIDATORS_COUNT: u64 = 3;

    public(friend) fun staked_amount(suidouble_liquid_staker: &SuidoubleLiquidStaker): u64 { 
        suidouble_liquid_staker.staked_amount 
    }

    public(friend) fun staked_amount_with_rewards(suidouble_liquid_staker: &SuidoubleLiquidStaker, wrapper: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let current_epoch = tx_context::epoch(ctx);

        expected_staked_balance(&suidouble_liquid_staker.staked_pool, wrapper, current_epoch)
    }

    // public(friend) fun staked_with_rewards_amount(suidouble_liquid_staker: &SuidoubleLiquidStaker, wrapper: &mut SuiSystemState, epoch: u64): u64 {
    //     suidouble_liquid_coin::expected_staked_balance(&suidouble_liquid_staker.staked_pool, wrapper, ctx)
    // }

    /**
    * Stake SUI into the pool
    */
    public(friend) fun stake_sui(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, sui: &mut Balance<SUI>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let sui_amount = balance::value(sui);
        let value_to_stake = (sui_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            let coin = coin::take(sui, value_to_stake, ctx);

            // pick a random validator
            let uid = object::new(ctx);
            let random = object::uid_to_bytes(&uid);
            object::delete(uid);
            let validator_address = random_validator_address(state, random);

            // stake sui
            let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);
            vector::push_back(&mut suidouble_liquid_staker.staked_pool, staked_sui);

            suidouble_liquid_staker.staked_amount = suidouble_liquid_staker.staked_amount + value_to_stake;
        };

        value_to_stake
    }

    /**
    *  Simple hack. Move StakedSui with the lowest APY (based on last 7 epochs) to the begining of the pool vector, so:
    *    - we'll withdraw it first, increasing our average APY
    *    - we don't have to check deactivated pools, as they will have the lowest APY anyway
    */
    public(friend) fun quick_sort_by_apy(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, state: &mut SuiSystemState, ctx: &mut TxContext) {

    }

    /**
    * Unstakes SUI from the pool. Returns Balance. Note that it may unstake more than asked. It's ok and remaining should be moved to the pending pool
    */
    public(friend) fun unstake_sui(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, amount: u64, state: &mut SuiSystemState, ctx: &mut TxContext): Balance<SUI> {
        // withdraw staked
        let n = vector::length(&suidouble_liquid_staker.staked_pool);
        let i = 0;

        let current_epoch = tx_context::epoch(ctx);
        let staked_sui_to_keep = vector::empty<StakedSui>();

        let gonna_unstake = amount + 0;
        let total_withdrawn_balance = balance::zero<SUI>();

        while (i < n && gonna_unstake > 0) {
            let staked_sui = vector::remove(&mut suidouble_liquid_staker.staked_pool, 0);

            if (staking_pool::stake_activation_epoch(&staked_sui) > current_epoch) {
                // can not withdraw, it's too early
                vector::push_back(&mut staked_sui_to_keep, staked_sui);
            } else {
                let was_staked = staking_pool::staked_sui_amount(&staked_sui);
                let can_we_split_the_staked:bool = false;

                if (was_staked > gonna_unstake) {
                    // check if we can split StakedSui, keeping something in pool
                    if (gonna_unstake > MIN_STAKING_THRESHOLD && (was_staked - gonna_unstake) > MIN_STAKING_THRESHOLD) {
                        can_we_split_the_staked = true;
                    } 
                };

                let to_withdraw;
                if (can_we_split_the_staked) {
                    to_withdraw = staking_pool::split(&mut staked_sui, gonna_unstake, ctx);
                    vector::push_back(&mut staked_sui_to_keep, staked_sui); // keep remaining
                } else {
                    to_withdraw = staked_sui;
                };

                let was_staked_final = staking_pool::staked_sui_amount(&to_withdraw);
                let withdrawn_balance = request_withdraw_stake_non_entry(state, to_withdraw, ctx);

                suidouble_liquid_staker.staked_amount = suidouble_liquid_staker.staked_amount - was_staked_final;

                let withdrawn_value = balance::value(&withdrawn_balance);

                if (withdrawn_value <= gonna_unstake) {
                    // just add it to promised balance
                    balance::join(&mut total_withdrawn_balance, withdrawn_balance);
                    gonna_unstake = gonna_unstake - withdrawn_value;
                    // liquid_store.promised_amount = liquid_store.promised_amount - withdrawn_value;
                } else {
                    gonna_unstake = 0; // don't want to go to minus, though we may get more than expected
                    balance::join(&mut total_withdrawn_balance, withdrawn_balance);

                    // // split it to promised and pending
                    // let to_promised = balance::split(&mut withdrawn_balance, liquid_store.promised_amount);
                    // balance::join(&mut liquid_store.promised, to_promised);
                    // liquid_store.promised_amount = 0;

                    // let to_pending_amount = balance::value(&withdrawn_balance);
                    // liquid_store.pending_balance = liquid_store.pending_balance + to_pending_amount;
                    // balance::join(&mut liquid_store.pending, withdrawn_balance);
                };
            };

            i = i + 1;
        };

        vector::append(&mut suidouble_liquid_staker.staked_pool, staked_sui_to_keep); // keeping staked references

        total_withdrawn_balance
    }

    // logic taken from test function of staking_pool module
    public(friend) fun expected_staked_balance(staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, at_epoch: u64): u64 {
        let n = vector::length(staked_ref);
        let i = 0;

        let expected_amount:u64 = 0;

        while (i < n) {
            let ref = vector::borrow(staked_ref, i);
            let pool = staking_pool::pool_id(ref);

            let staked_amount = staking_pool::staked_sui_amount(ref);
            let staked_activation_epoch = staking_pool::stake_activation_epoch(ref);

            if (staked_activation_epoch >= at_epoch) {
                // no profits yet
                expected_amount = expected_amount + staked_amount;
            } else {
                let exchange_rates = pool_exchange_rates(state, &pool); // sui_system::sui_system::pool_exchange_rates

                let exchange_rate_at_staking_epoch = staking_pool_echange_rate_at_epoch(exchange_rates, staked_activation_epoch);
                let new_epoch_exchange_rate = staking_pool_echange_rate_at_epoch(exchange_rates, at_epoch);

                let pool_token_withdraw_amount = get_token_amount(&exchange_rate_at_staking_epoch, staked_amount);
                let total_sui_withdraw_amount = get_sui_amount(&new_epoch_exchange_rate, pool_token_withdraw_amount);

                // let rewards = total_sui_withdraw_amount - staked_amount;

                expected_amount = expected_amount + total_sui_withdraw_amount;
            };

            i = i + 1;
        };

        expected_amount
    }

    // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    fun staking_pool_echange_rate_at_epoch(rates: &Table<u64, staking_pool::PoolTokenExchangeRate>, at_epoch: u64): staking_pool::PoolTokenExchangeRate {
        let look_up_epoch = at_epoch + 0;
        let pool_activation_epoch = 1; // ??? todo: find somehow

        // Find the latest epoch that's earlier than the given epoch with an entry in the table
        while (look_up_epoch >= pool_activation_epoch) {
            if (table::contains(rates, look_up_epoch)) {
                return *table::borrow(rates, look_up_epoch)
            };
            look_up_epoch = look_up_epoch - 1;
        };

        // we don't have to be here
        return *table::borrow(rates, 0)
    }

    // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    fun get_sui_amount(exchange_rate: &staking_pool::PoolTokenExchangeRate, token_amount: u64): u64 {
        let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
            return token_amount
        };
        let res = (exchange_rate_sui_amount as u128)
                * (token_amount as u128)
                / (exchange_rate_pool_token_amount as u128);
        (res as u64)
    }

    // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    fun get_token_amount(exchange_rate: &staking_pool::PoolTokenExchangeRate, sui_amount: u64): u64 {
        let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
            return sui_amount
        };
        let res = (exchange_rate_pool_token_amount as u128)
                * (sui_amount as u128)
                / (exchange_rate_sui_amount as u128);
        (res as u64)
    }

    public(friend) fun default(): SuidoubleLiquidStaker {
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