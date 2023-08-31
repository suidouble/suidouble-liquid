
module suidouble_liquid::suidouble_liquid {
    const WithdrawPromiseCooldownEpochs: u64 = 1;
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool

    const EWithdrawingTooMuch: u64 = 1;
    const ETooEarly: u64 = 2;
    const EDelegationOfZeroSui: u64 = 3;
    const EInvalidPromised: u64 = 4;

    use suidouble_liquid::suidouble_liquid_coin;
    use suidouble_liquid::suidouble_liquid_staker;

    use sui::event;

    use sui::tx_context::{Self, sender, TxContext};

    // use sui::table::{Self, Table};
    use sui::transfer;
    use sui_system::sui_system::SuiSystemState;
    use sui_system::sui_system::request_add_stake_non_entry;
    use sui_system::sui_system::request_withdraw_stake_non_entry;
    // use sui_system::sui_system::pool_exchange_rates;

    use sui::package;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    use sui::object::{Self, UID, ID};

    use sui_system::staking_pool::{Self, StakedSui};
    // use sui_system::staking_pool::stake_activation_epoch;
    // use sui_system::staking_pool::staked_sui_amount;
    use std::vector;
    // use sui::display;

    // use sui::coin;
    use sui::math;

    use std::option::{Self, Option, none};

    /// One-Time-Witness for the module.
    struct SUIDOUBLE_LIQUID has drop {}

    struct LiquidStore has key {
        id: UID,
        maintainer_address: address,
        pending_pool: Balance<SUI>,
        // pending_balance: u64,
        // staked: vector<StakedSui>,
        // staked_balance: u64,
        staked_with_rewards_balance: u64,  // helps with debuging, but we'll probably get rid of it on producation
        promised_amount: u64,
        promised: Balance<SUI>,
        rewards_balance: u64,
        rewards: Balance<SUI>,
        liquid_store_epoch: u64,
        treasury: Option<coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>>,
        staked_pool: suidouble_liquid_staker::SuidoubleLiquidStaker,
        // balance: Balance<StakedSui>
    }

    struct LiquidStoreWithdrawPromise has key, store {
        id: UID,
        for: address,
        token_amount: u64,
        sui_amount: u64,   // at some possible price fluctation, we may receive lower value in SUI, so we keep both promised to optimize fulfiling 
        fulfilled_at_epoch: u64,
    }

    struct NewLiquidStoreEvent has copy, drop {
        id: ID,
    }

    struct PriceEvent has copy, drop {
        price: u64,         // may be 0 depending on the buy-sell side
        price_reverse: u64,
    }

    struct EpochEvent has copy, drop { // even to be emited after every epoch update
        expected_staked: u64,
        epoch: u64,
        was_pending_balance: u64,
        was_staked_amount: u64,
        was_promised_amount: u64,
        after_pending_balance: u64,
        after_staked_amount: u64,
        after_promised_amount: u64,
    }

    struct WithdrawPromiseEvent has copy, drop {
        id: ID,
        price: u64,
        token_amount: u64,
    }

    fun init(otw: SUIDOUBLE_LIQUID, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender(ctx));

        // let coin_treasury_cap = suidouble_liquid_coin::initialize_coin(otw, ctx);

        let liquid_store = LiquidStore {
            id: object::new(ctx),
            maintainer_address: sender(ctx),
            // balance: balance::zero<StakedSui>()
            pending_pool: balance::zero<SUI>(),
            // pending_balance: 0,
            // staked: vector::empty(),
            // staked_balance: 0,
            staked_with_rewards_balance: 0,
            promised_amount: 0,
            promised: balance::zero<SUI>(),
            rewards_balance: 0,
            rewards: balance::zero<SUI>(),
            liquid_store_epoch: 0,
            treasury: none(),
            staked_pool: suidouble_liquid_staker::default(),
        };

        event::emit(NewLiquidStoreEvent {
            id: object::uid_to_inner(&liquid_store.id),
        });

        transfer::share_object(liquid_store);
    }

    // this function should be called right after the package deploy, attaching TreasuryCap to the LiquidStore
    // most other functions would not work if Treasury is not set
    public entry fun attach_treasury(liquid_store: &mut LiquidStore, treasury: coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, _ctx: &mut TxContext) {
        // can be called only once? @todo: check
        option::fill(&mut liquid_store.treasury, treasury);
    }

    /**
    * Amount of currently circulated mTokens
    */
    fun get_token_supply(liquid_store: &LiquidStore):u64 {
        let treasury_ref = option::borrow(&liquid_store.treasury); // aborts if there is no treasury
        coin::total_supply(treasury_ref)
    }

    const PRICE_K: u64 = 1_000_000_000; // 1 SUI

    /**
    *  amount of mSUI you can get for 1_000_000_000 mTokens
    */
    fun get_current_price(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let total_supply = get_token_supply(liquid_store);

        if (total_supply == 0) {
            return (PRICE_K)
        };

        // let pending_balance_amount = liquid_store.pending_balance;
        let pending_amount = pending_amount(liquid_store);//liquid_store.pending_balance;
        let promised_amount = liquid_store.promised_amount;
        let currently_staked_with_rewards = staked_amount_with_rewards(liquid_store, state, ctx);

        let total_in = pending_amount + currently_staked_with_rewards - promised_amount;

        let price = ( (total_in as u128) * (PRICE_K as u128) ) / (total_supply as u128);

        (price as u64)
    }

    /**
    *  amount of mTokens you can get for 1_000_000_000 mSUI
    */
    fun get_current_price_reverse(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let pending_amount = pending_amount(liquid_store);//liquid_store.pending_balance;
        let promised_amount = liquid_store.promised_amount;
        let currently_staked_with_rewards = staked_amount_with_rewards(liquid_store, state, ctx);

        let total_in = pending_amount + currently_staked_with_rewards - promised_amount;

        if (total_in == 0) {
            return (PRICE_K)
        };

        let total_supply = get_token_supply(liquid_store);

        let price = ( (total_supply as u128) * (PRICE_K as u128) ) / (total_in as u128);

        (price as u64)
    }

    /**
    * currently pending mSUI amount
    */
    public(friend) fun pending_amount(liquid_store: &LiquidStore): u64 {
        // suidouble_liquid_staker::staked_amount(&liquid_store.staked_pool)
        balance::value(&liquid_store.pending_pool)
    }


    /**
    * currently staked mSUI amount without rewards
    */
    public(friend) fun staked_amount(liquid_store: &LiquidStore): u64 { 
        suidouble_liquid_staker::staked_amount(&liquid_store.staked_pool)
    }

    /**
    * currently staked mSUI amount + rewards
    */
    public fun staked_amount_with_rewards(liquid_store: &LiquidStore, wrapper: &mut SuiSystemState, ctx: &mut TxContext): u64 {
        let amount = suidouble_liquid_staker::staked_amount_with_rewards(&liquid_store.staked_pool, wrapper, ctx);

        amount
    }

    // public(friend) fun pending_balance(liquid_store: &LiquidStore): &u64 { 
    //     &liquid_store.pending_balance 
    // }


    public entry fun deposit(liquid_store: &mut LiquidStore, coin: Coin<SUI>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        // let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);

        let current_price_reverse = get_current_price_reverse(liquid_store, state, ctx);
        // current price is amount of tokens you get from 1 sui

        let sui_amount = coin::value(&coin);

        coin::put(&mut liquid_store.pending_pool, coin);

        let token_amount = ( (sui_amount as u128) * (current_price_reverse as u128) ) / ( PRICE_K as u128 );
        
        // liquid_store.pending_balance = liquid_store.pending_balance + sui_amount;

        let treasury = option::borrow_mut(&mut liquid_store.treasury); // aborts if there is no treasury

        suidouble_liquid_coin::mint(treasury, (token_amount as u64), ctx);

        event::emit(PriceEvent {
            price_reverse: current_price_reverse,
            price: 0,
        });

        once_per_epoch_if_needed(liquid_store, state, ctx);
    }



    public entry fun withdraw(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let token_amount = coin::value(&input_coin);

        let current_price = get_current_price(liquid_store, state, ctx);
        let sui_amount = ( (token_amount as u128) * (current_price as u128) ) / ( PRICE_K as u128 );// suidouble_liquid_coin::token_to_sui(token_amount, current_price);

        // let available_to_withdraw = liquid_store.staked_balance - liquid_store.promised_amount;
        // assert!(amount <= available_to_withdraw, EWithdrawingTooMuch);

        event::emit(PriceEvent {
            price_reverse: 0,
            price: current_price,
        });

        let treasury = option::borrow_mut(&mut liquid_store.treasury);
        suidouble_liquid_coin::burn(treasury, input_coin);

        let current_epoch = tx_context::epoch(ctx);

        let uid = object::new(ctx);
        let for = tx_context::sender(ctx);
        let fulfilled_at_epoch = current_epoch + WithdrawPromiseCooldownEpochs;

        let liquid_withdraw_promise = LiquidStoreWithdrawPromise {
            id: uid,
            for: for,
            sui_amount: (sui_amount as u64),
            token_amount: token_amount,
            fulfilled_at_epoch: fulfilled_at_epoch,
        };   

        liquid_store.promised_amount = liquid_store.promised_amount + (sui_amount as u64);
        transfer::public_transfer(liquid_withdraw_promise, tx_context::sender(ctx));

        once_per_epoch_if_needed(liquid_store, state, ctx);
    }


    public entry fun fulfill(liquid_store: &mut LiquidStore, promise: LiquidStoreWithdrawPromise, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);

        assert!(promise.fulfilled_at_epoch <= current_epoch, ETooEarly);

        once_per_epoch_if_needed(liquid_store, state, ctx);

        // let current_price_now = get_current_price(liquid_store, state, ctx);
        // let sui_amount_now = suidouble_liquid_coin::token_to_sui(promise.token_amount, current_price_now);

        // let sui_amount_to_use = math::min(sui_amount_now, promise.sui_amount);

        let sui_amount_to_use = promise.sui_amount;

        assert!(sui_amount_to_use <= balance::value(&liquid_store.promised), EInvalidPromised); // we should never throw this. @todo: hard integration tests

        let coin = coin::take(&mut liquid_store.promised, sui_amount_to_use, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx)); //  to promise.for ???

        // and remove a promise
        let LiquidStoreWithdrawPromise { id, for: _, sui_amount: _, token_amount: _, fulfilled_at_epoch: _ } = promise;
        object::delete(id);
    }

    // logic taken from test function of staking_pool module
    entry fun calc_expected_profits(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let expected_amount = staked_amount_with_rewards(liquid_store, state, ctx);
        liquid_store.staked_with_rewards_balance = expected_amount;
    }


    public entry fun once_per_epoch_if_needed(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        if (current_epoch > liquid_store.liquid_store_epoch) {
            let was_pending_balance = pending_amount(liquid_store);//  liquid_store.pending_balance + 0;
            let was_promised_amount = liquid_store.promised_amount + 0;

            let was_staked_amount = staked_amount(liquid_store);

            // fulfil promises first
            unstake_promised(liquid_store, state, ctx);

            // stake pending
            send_pending_to_staked(liquid_store, state, ctx);

            // 
            liquid_store.liquid_store_epoch = current_epoch;

            let expected_staked = staked_amount_with_rewards(liquid_store, state, ctx);

            liquid_store.staked_with_rewards_balance = expected_staked; // @todo: do we need to expose this???

            event::emit(EpochEvent {
                expected_staked: expected_staked,
                was_pending_balance: was_pending_balance,
                was_staked_amount: was_staked_amount,
                was_promised_amount: was_promised_amount,
                after_pending_balance: (pending_amount(liquid_store)),
                after_staked_amount: (staked_amount(liquid_store)),
                after_promised_amount: liquid_store.promised_amount,
                epoch: current_epoch,
            });
        };
    }


    fun send_pending_to_staked(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pending_amount = pending_amount(liquid_store);
        let value_to_stake = (pending_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            let staked_amount = suidouble_liquid_staker::stake_sui(&mut liquid_store.staked_pool, &mut liquid_store.pending_pool, state, ctx);

            // if (staked_amount > 0) {
            //     liquid_store.pending_balance = liquid_store.pending_balance - staked_amount;
            // }
        }
    }

    fun send_pending_to_promised(liquid_store: &mut LiquidStore) {
        if (liquid_store.promised_amount > 0) {
            let pending_amount = pending_amount(liquid_store);
            if (pending_amount <= liquid_store.promised_amount) {
                // move everything
                let taken_balance = balance::withdraw_all(&mut liquid_store.pending_pool);
                let taken_amount = balance::value(&taken_balance);
                balance::join(&mut liquid_store.promised, taken_balance);

                // liquid_store.pending_balance = liquid_store.pending_balance - taken_amount;
                liquid_store.promised_amount = liquid_store.promised_amount - taken_amount;
            } else {
                // we can split
                let taken_balance = balance::split(&mut liquid_store.pending_pool, liquid_store.promised_amount);
                let taken_amount = balance::value(&taken_balance);
                balance::join(&mut liquid_store.promised, taken_balance);

                // liquid_store.pending_balance = liquid_store.pending_balance - taken_amount;
                liquid_store.promised_amount = liquid_store.promised_amount - taken_amount;
            }
        }
    }

    fun unstake_promised(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        if (liquid_store.promised_amount > 0) {
            // move pending to promised?
            if (liquid_store.promised_amount <= pending_amount(liquid_store)) {
                // we can fulfil promises without touching staked. Let's do!
                send_pending_to_promised(liquid_store);
            };

            let unstaked_balance = suidouble_liquid_staker::unstake_sui(&mut liquid_store.staked_pool, liquid_store.promised_amount, state, ctx);
            let unstaked_balance_amount = balance::value(&unstaked_balance);

            if (unstaked_balance_amount <= liquid_store.promised_amount) {
                // just add it to promised balance
                balance::join(&mut liquid_store.promised, unstaked_balance);
                liquid_store.promised_amount = liquid_store.promised_amount - unstaked_balance_amount;
            } else {
                // split it to promised and pending
                let to_promised = balance::split(&mut unstaked_balance, liquid_store.promised_amount);
                balance::join(&mut liquid_store.promised, to_promised);
                liquid_store.promised_amount = 0;

                let to_pending_amount = balance::value(&unstaked_balance);
                // liquid_store.pending_balance = liquid_store.pending_balance + to_pending_amount;
                balance::join(&mut liquid_store.pending_pool, unstaked_balance);
            };
            // still need something?
            if (liquid_store.promised_amount > 0) {
                send_pending_to_promised(liquid_store);
            };
        };
    }

    public entry fun once_per_epoch(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        // fulfil promises first
        unstake_promised(liquid_store, state, ctx);

        // stake pending
        send_pending_to_staked(liquid_store, state, ctx);

        let current_epoch = tx_context::epoch(ctx);
        liquid_store.liquid_store_epoch = current_epoch;
    }
}
