/**
*   Manage all stake related things for our pool
*/
module suidouble_liquid::suidouble_liquid_staker {
    friend suidouble_liquid::suidouble_liquid;
    friend suidouble_liquid::suidouble_liquid_promised_pool;

    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool

    use std::vector;
    use sui_system::sui_system::SuiSystemState;
    use sui_system::sui_system::active_validator_addresses;
    use sui_system::sui_system::pool_exchange_rates;
    use sui_system::staking_pool::{Self, StakedSui};
    use sui::table::{Table, Self};

    use sui::coin;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    use sui::object;
    use sui::tx_context::{Self, TxContext};

    use sui_system::sui_system::request_add_stake_non_entry;
    use sui_system::sui_system::request_withdraw_stake_non_entry;

    use std::option::{Self, Option};
    use suidouble_liquid::suidouble_liquid_stats;

    struct SuidoubleLiquidStaker has store {
        staked_pool: vector<StakedSui>,
        staked_amount: u64,
    }

    const MINIMUM_VALIDATORS_COUNT: u64 = 3;

    /**
    *   current staked amount in SUI
    */
    public(friend) fun staked_amount(suidouble_liquid_staker: &SuidoubleLiquidStaker): u64 { 
        suidouble_liquid_staker.staked_amount 
    }

    /**
    *   current amount in SUI available to withdraw at epoch
    */
    public(friend) fun staked_amount_available(suidouble_liquid_staker: &SuidoubleLiquidStaker, wrapper: &mut SuiSystemState, at_epoch: u64): u64 {
        expected_available_staked_balance(&suidouble_liquid_staker.staked_pool, wrapper, at_epoch)
    }

    /**
    *   current amount in SUI + rewards
    */
    public(friend) fun staked_amount_with_rewards(suidouble_liquid_staker: &SuidoubleLiquidStaker, wrapper: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let current_epoch = tx_context::epoch(ctx);

        expected_staked_balance(&suidouble_liquid_staker.staked_pool, wrapper, current_epoch)
    }

    /**
    * Stake SUI into the pool
    */
    public(friend) fun stake_sui(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, sui: &mut Balance<SUI>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let sui_amount = balance::value(sui);
        let value_to_stake = (sui_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            value_to_stake = sui_amount;
            
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
    * Stake SUI into the pool
    *   v2 version - with a respect to SuidoubleLiquidStats object,
    *     so we can stake 4/5 of the available SUI to the pool with highest expected APY, and 1/5 to the random pool
    */
    public(friend) fun stake_sui_v2(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, sui: &mut Balance<SUI>, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let sui_amount = balance::value(sui);
        let value_to_stake = (sui_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;
    
        if (value_to_stake > 0) {
            value_to_stake = sui_amount;

            if (value_to_stake / MIN_STAKING_THRESHOLD > 5) {
                // if we are staking > 5 SUI, let's send 4/5 to the pool with highest rates in last 5 epochs:
                let uid_to_highest = object::new(ctx);
                let random_to_highest = object::uid_to_bytes(&uid_to_highest);
                object::delete(uid_to_highest);
                let validator_address_to_highest = random_validator_address_high_apy(suidouble_liquid_staker, stats, state, random_to_highest);

                let coin_to_highest = coin::take(sui, (value_to_stake * 4 / 5), ctx);

                suidouble_liquid_staker.staked_amount = suidouble_liquid_staker.staked_amount + coin::value(&coin_to_highest);

                let staked_sui_to_highest = request_add_stake_non_entry(state, coin_to_highest, validator_address_to_highest, ctx);
                vector::push_back(&mut suidouble_liquid_staker.staked_pool, staked_sui_to_highest);

                value_to_stake = balance::value(sui);
            };
            
            let coin = coin::take(sui, value_to_stake, ctx);

            // pick a random validator
            let uid = object::new(ctx);
            let random = object::uid_to_bytes(&uid);
            object::delete(uid);
            let validator_address = random_validator_address(state, random);

            // stake sui
            let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);
            let pool_id = staking_pool::pool_id(&staked_sui);

            suidouble_liquid_stats::store_address(stats, pool_id, validator_address);

            vector::push_back(&mut suidouble_liquid_staker.staked_pool, staked_sui);

            suidouble_liquid_staker.staked_amount = suidouble_liquid_staker.staked_amount + value_to_stake;
        };

        value_to_stake
    }

    /**
    *   Find the perfect staked sui ( see hackpaper )
    *      perfect staked sui - is a StakedSui that can be withdrawn to the specific SUI amount ( with a respect to gathered rewards )
    */
    public(friend) fun find_the_perfect_staked_sui(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, amount: u64, state: &mut SuiSystemState, ctx: &mut TxContext): Option<StakedSui> {
        // return option::none();
        if (amount < MIN_STAKING_THRESHOLD) {
            return option::none()
        };

        let n = vector::length(&suidouble_liquid_staker.staked_pool);
        let i = 0;
        let current_epoch = tx_context::epoch(ctx);

        while (i < n) {
            let staked_sui_ref = vector::borrow(&suidouble_liquid_staker.staked_pool, i);
            let staked_activation_epoch = staking_pool::stake_activation_epoch(staked_sui_ref);
            if (staked_activation_epoch <= current_epoch) {
                // as we want perfect staked sui to be available to withdraw right away if needed

                let was_staked_amount = staking_pool::staked_sui_amount(staked_sui_ref);
                let now = expected_staked_balance_of(staked_sui_ref, state, current_epoch);

                if (now >= amount) {

                    let had_to_take = (amount as u128) * (was_staked_amount as u128) / (now as u128);

                    if ((had_to_take as u64) < (was_staked_amount - MIN_STAKING_THRESHOLD) && (had_to_take as u64) >= MIN_STAKING_THRESHOLD) {
                        // we can take it as split
                        let staked_sui_mut = vector::borrow_mut(&mut suidouble_liquid_staker.staked_pool, i);
                        let perfect_staked_sui = staking_pool::split(staked_sui_mut, (had_to_take as u64), ctx);

                        suidouble_liquid_staker.staked_amount = suidouble_liquid_staker.staked_amount - (had_to_take as u64);

                        return option::some(perfect_staked_sui)
                    };

                };

            };

            i = i + 1;
        };

        option::none()
    }

    /**
    *   Get array of growth rates over the last N epochs for the current staked sui list. Later using this for sorting.
    */
    fun epoch_staked_sui_growth_rates(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, state: &mut SuiSystemState, epoch: u64):vector<u128> {
        let n = vector::length(&suidouble_liquid_staker.staked_pool);
        let i = 0;

        let ret = vector::empty<u128>();
        let epoch_diff_to_check = 5;
        let price_k = 1_000_000_000;

        while (i < n) {
            let staked_sui_ref = vector::borrow(&suidouble_liquid_staker.staked_pool, i);

                let pool = staking_pool::pool_id(staked_sui_ref);
                let exchange_rates = pool_exchange_rates(state, &pool); // sui_system::sui_system::pool_exchange_rates

                let rate_now = staking_pool_echange_rate_at_epoch(exchange_rates, epoch);
                let was_epoch = 0;
                if (epoch >= epoch_diff_to_check) {
                    was_epoch = epoch - epoch_diff_to_check;
                };

                let rate_was = staking_pool_echange_rate_at_epoch(exchange_rates, was_epoch);

                let now_sui_amount = staking_pool::sui_amount(&rate_now);
                let now_pool_token_amount = staking_pool::pool_token_amount(&rate_now);

                if (now_pool_token_amount == 0) {
                    vector::push_back(&mut ret, 0);
                } else {
                    let was_sui_amount = staking_pool::sui_amount(&rate_was);
                    let was_pool_token_amount = staking_pool::pool_token_amount(&rate_was);

                    if (was_pool_token_amount == 0) {
                        vector::push_back(&mut ret, 0);
                    } else {

                        // @todo: check for div by 0
                        let would_get_now = (now_sui_amount as u128)
                                            * (price_k as u128)
                                            / (now_pool_token_amount as u128);

                        let would_get_was = (was_sui_amount as u128)
                                            * (price_k as u128)
                                            / (was_pool_token_amount as u128);

                        if (would_get_was >= would_get_now) {
                            vector::push_back(&mut ret, 0); // no growth. Is the pool deactivated?
                        } else {
                            vector::push_back(&mut ret, (would_get_now - would_get_was));
                        };

                    };
                };

            i = i + 1;
        };

        ret
    }

    /**
    *  Quick sort algo to sort vector `items` by values from vector `values`
    */
    fun quick_sort(items: &mut vector<staking_pool::StakedSui>, values: &mut vector<u128>, left: u64, right: u64){
        if (left < right){
            let partition_index = partion(items, values, left, right);
            if (partition_index > 1){
                quick_sort(items, values, left, partition_index -1);
            };
            quick_sort(items, values, partition_index + 1, right);
        }
    }

    /**
    *  Quick sort
    */
    fun partion(items: &mut vector<staking_pool::StakedSui>, values: &mut vector<u128>, left: u64, right: u64) : u64{
        let pivot: u64 = left;
        let index: u64 = pivot + 1;
        let i: u64 = index;
        
        while (i <= right) {
            if ( (*vector::borrow(values, i)) < (*vector::borrow(values, pivot)) ){
                vector::swap(items, i, index);
                vector::swap(values, i, index);
                index = index + 1;
            };

            i = i + 1;
        };

        vector::swap(items, pivot, index -1);
        vector::swap(values, pivot, index -1);

        index - 1
    }

    /**
    *  Simple hack. Move StakedSui with the lowest APY (based on last 5 epochs) to the begining of the pool vector, so:
    *    - we'll withdraw it first, increasing our average APY
    *    - we don't have to check deactivated pools, as they will have the lowest APY anyway
    */
    public(friend) fun quick_sort_by_apy(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, state: &mut SuiSystemState, epoch: u64) {
        let growth_rates = epoch_staked_sui_growth_rates(suidouble_liquid_staker, state, epoch);
        let length = vector::length(&growth_rates);

        if (length > 1) {
            let right = length - 1;
            quick_sort(&mut suidouble_liquid_staker.staked_pool, &mut growth_rates, 0, right);
        }
    }

    /**
    * Unstakes SUI from the pool. Returns Balance. Note that it may unstake little more than asked. It's ok and remaining should be moved to the pending pool
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
                } else {
                    gonna_unstake = 0; // don't want to go to minus, though we may get more than expected
                    balance::join(&mut total_withdrawn_balance, withdrawn_balance);
                };
            };

            i = i + 1;
        };

        vector::append(&mut suidouble_liquid_staker.staked_pool, staked_sui_to_keep); // keeping staked references

        total_withdrawn_balance
    }

    /**
    *   Expected amount of SUI in StakedSui at epoch (with gathered rewards)
    */
    fun expected_staked_balance_of(staked_sui_ref: &staking_pool::StakedSui, state: &mut SuiSystemState, at_epoch: u64): u64 {
        let staked_activation_epoch = staking_pool::stake_activation_epoch(staked_sui_ref);
        let staked_amount = staking_pool::staked_sui_amount(staked_sui_ref);

        if (staked_activation_epoch >= at_epoch) {
            // no profits yet
            return staked_amount
        };

        let pool = staking_pool::pool_id(staked_sui_ref);
        let exchange_rates = pool_exchange_rates(state, &pool); // sui_system::sui_system::pool_exchange_rates

        let exchange_rate_at_staking_epoch = staking_pool_echange_rate_at_epoch(exchange_rates, staked_activation_epoch);
        let new_epoch_exchange_rate = staking_pool_echange_rate_at_epoch(exchange_rates, at_epoch);

        let pool_token_withdraw_amount = get_token_amount(&exchange_rate_at_staking_epoch, staked_amount);
        let total_sui_withdraw_amount = get_sui_amount(&new_epoch_exchange_rate, pool_token_withdraw_amount);

        total_sui_withdraw_amount
    }


    /**
    *   Expected amount of SUI in StakedSui list at epoch (with gathered rewards)
    */
    public(friend) fun expected_staked_balance(staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, at_epoch: u64): u64 {
        let n = vector::length(staked_ref);
        let i = 0;

        let expected_amount:u64 = 0;

        while (i < n) {
            let ref = vector::borrow(staked_ref, i);
            expected_amount = expected_amount + expected_staked_balance_of(ref, state, at_epoch);

            i = i + 1;
        };

        expected_amount
    }

    /**
    *   same as expected_staked_balance, but returns amount available for unstaking right away
    */
    public(friend) fun expected_available_staked_balance(staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, at_epoch: u64): u64 {
        let n = vector::length(staked_ref);
        let i = 0;

        let expected_amount:u64 = 0;

        while (i < n) {
            let ref = vector::borrow(staked_ref, i);
            let staked_activation_epoch = staking_pool::stake_activation_epoch(ref);

            if (staked_activation_epoch <= at_epoch) {
                expected_amount = expected_amount + expected_staked_balance_of(ref, state, at_epoch);
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

        // still nothing found? go up
        look_up_epoch = at_epoch + 0;
        let check_till = look_up_epoch + 7; // maximum depth we check
        while (look_up_epoch <= check_till) {
            if (table::contains(rates, look_up_epoch)) {
                return *table::borrow(rates, look_up_epoch)
            };
            look_up_epoch = look_up_epoch + 1;
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

    /**
    *   constructor
    */
    public(friend) fun default(): SuidoubleLiquidStaker {
        let liquid_staker = SuidoubleLiquidStaker { 
            staked_pool: vector::empty(),
            staked_amount: 0,
        };

        liquid_staker 
    }

    /**
    *   try to get an address of validator with highest apy (based on our internal calculation), if nothing found - returns random validator address
    */
    public(friend) fun random_validator_address_high_apy(suidouble_liquid_staker: &mut SuidoubleLiquidStaker, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, wrapper: &mut SuiSystemState, random: vector<u8>): address {
        // as our staked_pool as sorted by APY (see quick_sort_by_apy)
        // we walk the staked_pool in the reverse order, and check if we have address for that pool
        let n = vector::length(&suidouble_liquid_staker.staked_pool);
        
        if (n > 1) {

            let i = n - 1;

            while (i > 0) { // no need to return very first one, so it's not >=
                let ref = vector::borrow(&suidouble_liquid_staker.staked_pool, i);
                let pool_id = staking_pool::pool_id(ref);

                let found = suidouble_liquid_stats::validator_address_by_pool_id(stats, pool_id);

                if (option::is_some(&found)) {
                    return option::destroy_some(found)
                };

                i = i - 1;
            };
        };
        
        // if nothing is found, return a random address
        random_validator_address(wrapper, random)
    }

    /**
    *   returns random active validator address
    */
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