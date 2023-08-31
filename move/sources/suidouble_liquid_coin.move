
module suidouble_liquid::suidouble_liquid_coin {
    friend suidouble_liquid::suidouble_liquid;
    friend suidouble_liquid::suidouble_liquid_staker;

    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use sui_system::sui_system::SuiSystemState;
    // use sui::types;

    use sui_system::staking_pool;
    use sui_system::sui_system::pool_exchange_rates;
    use sui::table::{Table, Self};

    use std::vector;

    // /// The type identifier of coin. The coin will have a type
    // /// tag of kind: `Coin<package_object::mycoin::MYCOIN>`
    // /// Make sure that the name of the type matches the module's name.
    struct SUIDOUBLE_LIQUID_COIN has drop {}

    // /// Module initializer is called once on module publish. A treasury
    // /// cap is sent to the publisher, publisher will send it to the Liquid Pool on the next step
    // /// and it's ready
    fun init(witness: SUIDOUBLE_LIQUID_COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"MYCOIN", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public(friend) fun mint(treasury: &mut coin::TreasuryCap<SUIDOUBLE_LIQUID_COIN>, amount: u64, ctx: &mut TxContext) {
        let coin = coin::mint(treasury, amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    public(friend) fun burn(treasury: &mut coin::TreasuryCap<SUIDOUBLE_LIQUID_COIN>, coin: coin::Coin<SUIDOUBLE_LIQUID_COIN>) {
        coin::burn(treasury, coin);
    }

    // const PRICE_K: u64 = 1_000_000_000; // 1 SUI

    // public(friend) fun sui_to_token(amount: u64, price_reverse: u64): u64 {
    //     let token_amount = ( (amount as u128) * (price_reverse as u128) ) / ( PRICE_K as u128 );

    //     (token_amount as u64)
    // }

    // public(friend) fun token_to_sui(amount: u64, price: u64): u64 {
    //     let sui_amount = ( (amount as u128) * (price as u128) ) / ( PRICE_K as u128 );

    //     (sui_amount as u64)
    // }

    // public(friend) fun get_current_price_reverse2(pending_balance: u64, promised_amount: u64, token_total_supply: u64, staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
    //     // let total_in = staked_balance + pending_balance;
        

    //     let currently_staked_with_rewards = expected_staked_balance(staked_ref, state, ctx);
    //     let total_in = pending_balance + currently_staked_with_rewards - promised_amount;

    //     if (total_in == 0) {
    //         return (PRICE_K)
    //     };
    //     // let total_out = currently_staked_with_rewards + pending_balance;

    //     let price_for_1_sui = ( (token_total_supply as u128) * (PRICE_K as u128) ) / (total_in as u128);
    //     // let price_for_1_sui_as_u64 = price_for_1_sui as u64;

    //     (price_for_1_sui as u64)
    // }

    // public(friend) fun get_current_price_reverse(staked_balance: u64, pending_balance: u64, staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
    //     let total_in = staked_balance + pending_balance;

    //     let currently_staked_with_rewards = expected_staked_balance(staked_ref, state, ctx);
    //     let total_out = currently_staked_with_rewards + pending_balance;

    //     if (total_out == 0) {
    //         return (PRICE_K)
    //     };

    //     let price_for_1_sui = ( (total_in as u128) * (PRICE_K as u128) ) / (total_out as u128);
    //     // let price_for_1_sui_as_u64 = price_for_1_sui as u64;

    //     (price_for_1_sui as u64)
    // }

    // public(friend) fun get_current_price2(pending_balance: u64, promised_amount: u64, token_total_supply: u64, staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
    //     // let total_in = staked_balance + pending_balance;
        
    //     if (token_total_supply == 0) {
    //         return (PRICE_K)
    //     };

    //     let currently_staked_with_rewards = expected_staked_balance(staked_ref, state, ctx);
    //     let total_in = pending_balance + currently_staked_with_rewards - promised_amount;
    //     // let total_out = currently_staked_with_rewards + pending_balance;

    //     let price_for_1_sui = ( (total_in as u128) * (PRICE_K as u128) ) / (token_total_supply as u128);
    //     // let price_for_1_sui_as_u64 = price_for_1_sui as u64;

    //     (price_for_1_sui as u64)
    // }

    // public(friend) fun get_current_price(staked_balance: u64, pending_balance: u64, staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
    //     let total_in = staked_balance + pending_balance;
        
    //     if (total_in == 0) {
    //         return (PRICE_K)
    //     };

    //     let currently_staked_with_rewards = expected_staked_balance(staked_ref, state, ctx);
    //     let total_out = currently_staked_with_rewards + pending_balance;

    //     let price_for_1_sui = ( (total_out as u128) * (PRICE_K as u128) ) / (total_in as u128);
    //     // let price_for_1_sui_as_u64 = price_for_1_sui as u64;

    //     (price_for_1_sui as u64)
    // }

    // // logic taken from test function of staking_pool module
    // public(friend) fun expected_staked_balance(staked_ref: &vector<staking_pool::StakedSui>, state: &mut SuiSystemState, ctx: &mut TxContext): u64 {
    //     let n = vector::length(staked_ref);
    //     let i = 0;

    //     let current_epoch = tx_context::epoch(ctx);

    //     let expected_amount:u64 = 0;

    //     while (i < n) {
    //         let ref = vector::borrow(staked_ref, i);
    //         let pool = staking_pool::pool_id(ref);

    //         let staked_amount = staking_pool::staked_sui_amount(ref);
    //         let staked_activation_epoch = staking_pool::stake_activation_epoch(ref);

    //         if (staked_activation_epoch >= current_epoch) {
    //             // no profits yet
    //             expected_amount = expected_amount + staked_amount;
    //         } else {
    //             let exchange_rates = pool_exchange_rates(state, &pool); // sui_system::sui_system::pool_exchange_rates

    //             let exchange_rate_at_staking_epoch = staking_pool_echange_rate_at_epoch(exchange_rates, staked_activation_epoch);
    //             let new_epoch_exchange_rate = staking_pool_echange_rate_at_epoch(exchange_rates, current_epoch);

    //             let pool_token_withdraw_amount = get_token_amount(&exchange_rate_at_staking_epoch, staked_amount);
    //             let total_sui_withdraw_amount = get_sui_amount(&new_epoch_exchange_rate, pool_token_withdraw_amount);

    //             // let rewards = total_sui_withdraw_amount - staked_amount;

    //             expected_amount = expected_amount + total_sui_withdraw_amount;
    //         };

    //         i = i + 1;
    //     };

    //     expected_amount
    // }

    // // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    // fun staking_pool_echange_rate_at_epoch(rates: &Table<u64, staking_pool::PoolTokenExchangeRate>, epoch: u64): staking_pool::PoolTokenExchangeRate {
    //     let look_up_epoch = epoch + 0;
    //     let pool_activation_epoch = 1; // ??? todo: find somehow

    //     // Find the latest epoch that's earlier than the given epoch with an entry in the table
    //     while (look_up_epoch >= pool_activation_epoch) {
    //         if (table::contains(rates, look_up_epoch)) {
    //             return *table::borrow(rates, look_up_epoch)
    //         };
    //         look_up_epoch = look_up_epoch - 1;
    //     };

    //     // we don't have to be here
    //     return *table::borrow(rates, 0)
    // }

    // // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    // fun get_sui_amount(exchange_rate: &staking_pool::PoolTokenExchangeRate, token_amount: u64): u64 {
    //     let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
    //     let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

    //     // When either amount is 0, that means we have no stakes with this pool.
    //     // The other amount might be non-zero when there's dust left in the pool.
    //     if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
    //         return token_amount
    //     };
    //     let res = (exchange_rate_sui_amount as u128)
    //             * (token_amount as u128)
    //             / (exchange_rate_pool_token_amount as u128);
    //     (res as u64)
    // }

    // // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    // fun get_token_amount(exchange_rate: &staking_pool::PoolTokenExchangeRate, sui_amount: u64): u64 {
    //     let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
    //     let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

    //     // When either amount is 0, that means we have no stakes with this pool.
    //     // The other amount might be non-zero when there's dust left in the pool.
    //     if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
    //         return sui_amount
    //     };
    //     let res = (exchange_rate_pool_token_amount as u128)
    //             * (sui_amount as u128)
    //             / (exchange_rate_sui_amount as u128);
    //     (res as u64)
    // }
    // /// For when someone tries to send a non OTW struct
    // const ENotOneTimeWitness: u64 = 0;

    // public(friend) fun initialize_coin<T: drop>(witness: T, ctx: &mut TxContext): coin::TreasuryCap<T> {
    //     assert!(types::is_one_time_witness(&witness), ENotOneTimeWitness);

    //     let (treasury, metadata) = coin::create_currency(witness, 6, b"MYCOIN", b"", b"", option::none(), ctx);
    //     transfer::public_freeze_object(metadata);
        
    //     treasury
    // }
}