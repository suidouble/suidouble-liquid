
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
        pending: Balance<SUI>,
        pending_balance: u64,
        staked: vector<StakedSui>,
        staked_balance: u64,
        staked_with_rewards_balance: u64,
        promised_amount: u64,
        promised: Balance<SUI>,
        rewards_balance: u64,
        rewards: Balance<SUI>,
        liquid_store_epoch: u64,
        treasury: Option<coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>>
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
        was_staked_balance: u64,
        was_promised_amount: u64,
        after_pending_balance: u64,
        after_staked_balance: u64,
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
            pending: balance::zero<SUI>(),
            pending_balance: 0,
            staked: vector::empty(),
            staked_balance: 0,
            staked_with_rewards_balance: 0,
            promised_amount: 0,
            promised: balance::zero<SUI>(),
            rewards_balance: 0,
            rewards: balance::zero<SUI>(),
            liquid_store_epoch: 0,
            treasury: none()
        };

        event::emit(NewLiquidStoreEvent {
            id: object::uid_to_inner(&liquid_store.id),
        });

        transfer::share_object(liquid_store);
    }

    fun get_token_supply(liquid_store: &LiquidStore):u64 {
        let treasury_ref = option::borrow(&liquid_store.treasury); // aborts if there is no treasury
        coin::total_supply(treasury_ref)
    }

    fun get_current_price(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let total_supply = get_token_supply(liquid_store);
        suidouble_liquid_coin::get_current_price2(liquid_store.pending_balance, liquid_store.promised_amount, total_supply, &liquid_store.staked, state, ctx) 
        // suidouble_liquid_coin::get_current_price(liquid_store.staked_balance, liquid_store.pending_balance, &liquid_store.staked, state, ctx)        
    }

    fun get_current_price_reverse(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let total_supply = get_token_supply(liquid_store);
        suidouble_liquid_coin::get_current_price_reverse2(liquid_store.pending_balance, liquid_store.promised_amount, total_supply, &liquid_store.staked, state, ctx) 
        // suidouble_liquid_coin::get_current_price_reverse(liquid_store.staked_balance, liquid_store.pending_balance, &liquid_store.staked, state, ctx)        
    }

    public(friend) fun staked_balance(liquid_store: &LiquidStore): &u64 { 
        &liquid_store.staked_balance 
    }

    public(friend) fun pending_balance(liquid_store: &LiquidStore): &u64 { 
        &liquid_store.pending_balance 
    }

    // this function should be called right after the package deploy, attaching TreasuryCap to the LiquidStore
    // most other functions would not work if Treasury is not set
    public entry fun attach_treasury(liquid_store: &mut LiquidStore, treasury: coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, _ctx: &mut TxContext) {
        // can be called only once? @todo: check
        option::fill(&mut liquid_store.treasury, treasury);
    }

    public entry fun deposit(liquid_store: &mut LiquidStore, coin: Coin<SUI>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        // let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);

        let current_price_reverse = get_current_price_reverse(liquid_store, state, ctx);
        // current price is amount of tokens you get from 1 sui

        let sui_amount = coin::value(&coin);

        coin::put(&mut liquid_store.pending, coin);

        let token_amount = suidouble_liquid_coin::sui_to_token(sui_amount, current_price_reverse);
        
        liquid_store.pending_balance = liquid_store.pending_balance + sui_amount;

        let treasury = option::borrow_mut(&mut liquid_store.treasury); // aborts if there is no treasury

        suidouble_liquid_coin::mint(treasury, token_amount, ctx);

        event::emit(PriceEvent {
            price_reverse: current_price_reverse,
            price: 0,
        });

        once_per_epoch_if_needed(liquid_store, state, ctx);
    }



    public entry fun withdraw(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let token_amount = coin::value(&input_coin);

        let current_price = get_current_price(liquid_store, state, ctx);
        let sui_amount = suidouble_liquid_coin::token_to_sui(token_amount, current_price);

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
            sui_amount: sui_amount,
            token_amount: token_amount,
            fulfilled_at_epoch: fulfilled_at_epoch,
        };   

        liquid_store.promised_amount = liquid_store.promised_amount + sui_amount;
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

    // public entry fun withdraw(liquid_store: &mut LiquidStore, amount: u64, ctx: &mut TxContext) {
    //     let available_to_withdraw = liquid_store.staked_balance - liquid_store.promised_amount;

    //     assert!(amount <= available_to_withdraw, EWithdrawingTooMuch);
    //     let uid = object::new(ctx);
    //     let for = tx_context::sender(ctx);
    //     let fulfilled_at_liquid_store_epoch = liquid_store.liquid_store_epoch + WithdrawPromiseCooldownEpochs;

    //     let liquid_withdraw_promise = LiquidStoreWithdrawPromise {
    //         id: uid,
    //         for: for,
    //         amount: amount,
    //         fulfilled_at_liquid_store_epoch: fulfilled_at_liquid_store_epoch,
    //     };   
    //     liquid_store.promised_amount = liquid_store.promised_amount + amount;
    //     transfer::public_transfer(liquid_withdraw_promise, tx_context::sender(ctx));

    //     // assert!(amount < liquid_store.pending_balance || amount < liquid_store.staked_balance, EWithdrawingTooMuch);

    //     // if (amount <= liquid_store.pending_balance) {
    //     //     // just take it from the pending balance
    //     //     let coin = coin::take(&mut liquid_store.pending, amount, ctx);            
    //     //     liquid_store.pending_balance = liquid_store.pending_balance - amount;
    //     //     transfer::public_transfer(coin, tx_context::sender(ctx));
    //     // } else if (amount <= liquid_store.staked_balance) {
    //     //     // create withdraw promise!
    //     //     // @todo: check if we promised too much already
    //     //     let uid = object::new(ctx);
    //     //     let for = tx_context::sender(ctx);
    //     //     let fulfilled_at_liquid_store_epoch = liquid_store.liquid_store_epoch + WithdrawPromiseCooldownEpochs;
    //     //     let liquid_withdraw_promise = LiquidStoreWithdrawPromise {
    //     //         id: uid,
    //     //         for: for,
    //     //         amount: amount,
    //     //         fulfilled_at_liquid_store_epoch: fulfilled_at_liquid_store_epoch,
    //     //     };   
    //     //     liquid_store.promised_amount = liquid_store.promised_amount + amount;
    //     //     transfer::public_transfer(liquid_withdraw_promise, tx_context::sender(ctx));

    //     //     // stake_activation_epoch(&staked_sui) <= tx_context::epoch(ctx),
    //     // }
    // }


    // // functions from staking_pool, we don't have direct access to, so have to include with little refactoring
    // fun staking_pool_echange_rate_at_epoch(rates: &Table<u64, PoolTokenExchangeRate>, epoch: u64): PoolTokenExchangeRate {
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
    // fun get_sui_amount(exchange_rate: &PoolTokenExchangeRate, token_amount: u64): u64 {
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
    // fun get_token_amount(exchange_rate: &PoolTokenExchangeRate, sui_amount: u64): u64 {
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

    // logic taken from test function of staking_pool module
    entry fun calc_expected_profits(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let expected_amount = suidouble_liquid_coin::expected_staked_balance(&liquid_store.staked, state, ctx);
        liquid_store.staked_with_rewards_balance = expected_amount;

        // let n = vector::length(&liquid_store.staked);
        // let i = 0;

        // let current_epoch = tx_context::epoch(ctx);

        // let expected_amount = 0;

        // while (i < n) {
        //     let ref = vector::borrow(&liquid_store.staked, i);
        //     let pool = staking_pool::pool_id(ref);

        //     let staked_amount = staking_pool::staked_sui_amount(ref);
        //     let staked_activation_epoch = stake_activation_epoch(ref);

        //     if (staked_activation_epoch >= current_epoch) {
        //         // no profits yet
        //         expected_amount = expected_amount + staked_amount;
        //     } else {
        //         let exchange_rates = pool_exchange_rates(state, &pool);

        //         let exchange_rate_at_staking_epoch = staking_pool_echange_rate_at_epoch(exchange_rates, staked_activation_epoch);
        //         let new_epoch_exchange_rate = staking_pool_echange_rate_at_epoch(exchange_rates, current_epoch);

        //         let pool_token_withdraw_amount = get_token_amount(&exchange_rate_at_staking_epoch, staked_amount);
        //         let total_sui_withdraw_amount = get_sui_amount(&new_epoch_exchange_rate, pool_token_withdraw_amount);

        //         // let rewards = total_sui_withdraw_amount - staked_amount;

        //         expected_amount = expected_amount + total_sui_withdraw_amount;
        //     };

        //     i = i + 1;
        // };

        // liquid_store.staked_with_rewards_balance = expected_amount;
    }


    public entry fun once_per_epoch_if_needed(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        if (current_epoch > liquid_store.liquid_store_epoch) {
            let was_pending_balance = liquid_store.pending_balance + 0;
            let was_staked_balance = liquid_store.staked_balance + 0;
            let was_promised_amount = liquid_store.promised_amount + 0;

            // fulfil promises first
            unstake_promised(liquid_store, state, ctx);

            // stake pending
            send_pending_to_staked(liquid_store, state, ctx);

            // 
            liquid_store.liquid_store_epoch = current_epoch;

            let expected_staked = suidouble_liquid_coin::expected_staked_balance(&liquid_store.staked, state, ctx);

            liquid_store.staked_with_rewards_balance = expected_staked; // @todo: do we need to expose this???

            event::emit(EpochEvent {
                expected_staked: expected_staked,
                was_pending_balance: was_pending_balance,
                was_staked_balance: was_staked_balance,
                was_promised_amount: was_promised_amount,
                after_pending_balance: liquid_store.pending_balance,
                after_staked_balance: liquid_store.staked_balance,
                after_promised_amount: liquid_store.promised_amount,
                epoch: current_epoch,
            });
        };
    }


    fun send_pending_to_staked(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let value_to_stake = (liquid_store.pending_balance / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            let coin = coin::take(&mut liquid_store.pending, value_to_stake, ctx);

            // pick a random validator
            let uid = object::new(ctx);
            let random = object::uid_to_bytes(&uid);
            object::delete(uid);
            let validator_address = suidouble_liquid_staker::random_validator_address(state, random);

            // stake sui
            let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);
            vector::push_back(&mut liquid_store.staked, staked_sui);

            liquid_store.staked_balance = liquid_store.staked_balance + value_to_stake;
            liquid_store.pending_balance = liquid_store.pending_balance - value_to_stake;
        }
    }

    fun send_pending_to_promised(liquid_store: &mut LiquidStore) {
        if (liquid_store.promised_amount > 0) {
            if (liquid_store.pending_balance <= liquid_store.promised_amount) {
                // move everything
                let taken_balance = balance::withdraw_all(&mut liquid_store.pending);
                let taken_amount = balance::value(&taken_balance);
                balance::join(&mut liquid_store.promised, taken_balance);

                liquid_store.pending_balance = liquid_store.pending_balance - taken_amount;
                liquid_store.promised_amount = liquid_store.promised_amount - taken_amount;
            } else {
                // we can split
                let taken_balance = balance::split(&mut liquid_store.pending, liquid_store.promised_amount);
                let taken_amount = balance::value(&taken_balance);
                balance::join(&mut liquid_store.promised, taken_balance);

                liquid_store.pending_balance = liquid_store.pending_balance - taken_amount;
                liquid_store.promised_amount = liquid_store.promised_amount - taken_amount;
            }
        }
    }

    fun unstake_promised(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        if (liquid_store.promised_amount > 0) {
            // move pending to promised?
            if (liquid_store.promised_amount <= liquid_store.pending_balance) {
                // we can fulfil promises without touching staked. Let's do!
                send_pending_to_promised(liquid_store);
            };
            
            // withdraw staked
            let n = vector::length(&liquid_store.staked);
            let i = 0;

            let current_epoch = tx_context::epoch(ctx);
            let staked_sui_to_keep = vector::empty<StakedSui>();

            while (i < n && liquid_store.promised_amount > 0) {
                let staked_sui = vector::remove(&mut liquid_store.staked, 0);

                if (staking_pool::stake_activation_epoch(&staked_sui) > current_epoch) {
                    // can not withdraw, it's too early
                    vector::push_back(&mut staked_sui_to_keep, staked_sui);
                } else {
                    let was_staked = staking_pool::staked_sui_amount(&staked_sui);
                    let can_we_split_the_staked:bool = false;

                    if (was_staked > liquid_store.promised_amount) {
                        // check if we can split StakedSui, keeping something in pool
                        if (liquid_store.promised_amount > MIN_STAKING_THRESHOLD && (was_staked - liquid_store.promised_amount) > MIN_STAKING_THRESHOLD) {
                            can_we_split_the_staked = true;
                        } 
                    };

                    let to_withdraw;
                    if (can_we_split_the_staked) {
                        to_withdraw = staking_pool::split(&mut staked_sui, liquid_store.promised_amount, ctx);
                        vector::push_back(&mut staked_sui_to_keep, staked_sui); // keep remaining
                    } else {
                        to_withdraw = staked_sui;
                    };

                    let was_staked_final = staking_pool::staked_sui_amount(&to_withdraw);
                    let withdrawn_balance = request_withdraw_stake_non_entry(state, to_withdraw, ctx);

                    liquid_store.staked_balance = liquid_store.staked_balance - was_staked_final;

                    let withdrawn_value = balance::value(&withdrawn_balance);

                    if (withdrawn_value <= liquid_store.promised_amount) {
                        // just add it to promised balance
                        balance::join(&mut liquid_store.promised, withdrawn_balance);
                        liquid_store.promised_amount = liquid_store.promised_amount - withdrawn_value;
                    } else {
                        // split it to promised and pending
                        let to_promised = balance::split(&mut withdrawn_balance, liquid_store.promised_amount);
                        balance::join(&mut liquid_store.promised, to_promised);
                        liquid_store.promised_amount = 0;

                        let to_pending_amount = balance::value(&withdrawn_balance);
                        liquid_store.pending_balance = liquid_store.pending_balance + to_pending_amount;
                        balance::join(&mut liquid_store.pending, withdrawn_balance);
                    };
                };

                i = i + 1;
            };

            vector::append(&mut liquid_store.staked, staked_sui_to_keep); // keeping staked references

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

        // let value_to_stake = (liquid_store.pending_balance / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;
        // assert!(value_to_stake > 0, EDelegationOfZeroSui);

        let current_epoch = tx_context::epoch(ctx);
        liquid_store.liquid_store_epoch = current_epoch;

        // if (value_to_stake > 0) {
        //     let coin = coin::take(&mut liquid_store.pending, value_to_stake, ctx);

        //     // pick a random validator
        //     let uid = object::new(ctx);
        //     let random = object::uid_to_bytes(&uid);
        //     object::delete(uid);
        //     let validator_address = suidouble_liquid_staker::random_validator_address(state, random);

        //     // stake sui
        //     let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);
        //     vector::push_back(&mut liquid_store.staked, staked_sui);

        //     liquid_store.staked_balance = liquid_store.staked_balance + value_to_stake;
        //     liquid_store.pending_balance = liquid_store.pending_balance - value_to_stake;
        // };
            // stake_activation_epoch(&staked_sui) <= tx_context::epoch(ctx),

        // // fulfil promises
        // if (liquid_store.promised_amount > MIN_STAKING_THRESHOLD) {
        //     // find enough StakedSui to cover promises
        //     // let withdrawn_balances = vector::empty<Balance<SUI>>();
        //     let n = vector::length(&liquid_store.staked);
        //     let i = 0;

        //     let current_epoch = tx_context::epoch(ctx);
        //     let staked_sui_to_keep = vector::empty<StakedSui>();

        //     while (i < n && liquid_store.promised_amount > 0) {
        //         let staked_sui = vector::remove(&mut liquid_store.staked, 0);

        //         if (stake_activation_epoch(&staked_sui) > current_epoch) {
        //             // can not withdraw, it's too early
        //             vector::push_back(&mut staked_sui_to_keep, staked_sui);
        //             i = i + 1;
        //         } else {
        //             let was_staked = staked_sui_amount(&staked_sui);

        //             // @todo: calculate expected rewards too, so we don't fill pending too much ?

        //             if (was_staked < liquid_store.promised_amount) {
        //                 // withdraw everything
        //                 // though we may get more (with rewards), it's ok:
        //                 let withdrawn_balance = request_withdraw_stake_non_entry(state, staked_sui, ctx);
        //                 let withdrawn_value = balance::value(&withdrawn_balance);

        //                 if (withdrawn_value <= liquid_store.promised_amount) {
        //                     // just add it to promised balance
        //                     balance::join(&mut liquid_store.promised, withdrawn_balance);
        //                     liquid_store.promised_amount = liquid_store.promised_amount - withdrawn_value;
        //                 } else {
        //                     // split it to promised and pending
        //                     let to_promised = balance::split(&mut withdrawn_balance, liquid_store.promised_amount);
        //                     balance::join(&mut liquid_store.promised, to_promised);
        //                     liquid_store.promised_amount = 0;

        //                     let to_pending_amount = balance::value(&withdrawn_balance);
        //                     liquid_store.pending_balance = liquid_store.pending_balance + to_pending_amount;
        //                     balance::join(&mut liquid_store.pending, withdrawn_balance);
        //                 };
        //             } else {
        //                 // if we are already expected to get more than needed, try to split staked_sui first
        //                 let splet = staking_pool::split(&mut staked_sui, liquid_store.promised_amount, ctx);
        //                 vector::push_back(&mut staked_sui_to_keep, staked_sui); // keep remaining

        //                 let withdrawn_balance = request_withdraw_stake_non_entry(state, splet, ctx);
        //                 let withdrawn_value = balance::value(&withdrawn_balance);

        //                 // we still may get more than needed (+rewards) so push extra to pending
        //                 if (withdrawn_value <= liquid_store.promised_amount) {
        //                     // just add it to promised balance
        //                     balance::join(&mut liquid_store.promised, withdrawn_balance);
        //                     liquid_store.promised_amount = liquid_store.promised_amount - withdrawn_value;
        //                 } else {
        //                     // split it to promised and pending
        //                     let to_promised = balance::split(&mut withdrawn_balance, liquid_store.promised_amount);
        //                     balance::join(&mut liquid_store.promised, to_promised);
        //                     liquid_store.promised_amount = 0;

        //                     let to_pending_amount = balance::value(&withdrawn_balance);
        //                     liquid_store.pending_balance = liquid_store.pending_balance + to_pending_amount;
        //                     balance::join(&mut liquid_store.pending, withdrawn_balance);
        //                 };
        //             };

        //             i = i + 1;
        //         }
        //     };

        //     vector::append(&mut liquid_store.staked, staked_sui_to_keep); //
        // };
    }
}
