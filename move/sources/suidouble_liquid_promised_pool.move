/**
*   Manage all things related to Promises. read hackpaper for more info on the algorithm
*/
module suidouble_liquid::suidouble_liquid_promised_pool {
    friend suidouble_liquid::suidouble_liquid;

    use suidouble_liquid::suidouble_liquid_staker;

    use sui_system::sui_system::SuiSystemState;
    use sui::table::{Self, Table};
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui_system::staking_pool::{StakedSui};
    use sui::tx_context::{TxContext, Self};

    use sui::object::{ID};
    use sui_system::sui_system::request_withdraw_stake_non_entry;

    use std::option;

    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool


    struct SuidoubleLiquidPromisedWaiting has store, drop { // created on LiquidStoreWithdrawPromise creation, but not filled yet
        expected_sui_amount: u64,                     // so we have few more epochs to get rewards in the normal flow
        promise_id: ID,
    }

    struct SuidoubleLiquidPromisedPoolStillStaked has store { // filled and ready to unstake and pay off
        staked_sui: StakedSui,
        expected_sui_amount: u64, // amount using for pay-off, the rest extra rewards can be sent back to pending pool
        promise_id: ID,
    }

    struct SuidoubleLiquidPromisedPool has store {
        all_time_promised_amount: u64,
        all_time_extra_amount: u64,

        promised_amount: u64,           // pending, asked to fulfill, not yet fulfilled
        promised_sui: Balance<SUI>,

        promised_amount_in_staked: u64,
        promised_staked: Table<ID, SuidoubleLiquidPromisedPoolStillStaked>,
        got_extra_staked: Balance<SUI>,

        created_at_epoch: u64,

        promised_promised_waiting_by_epoch: Table<u64, vector<SuidoubleLiquidPromisedWaiting>>,
        still_waiting_for_sui_amount: u64,

        oldest_waiting_epoch: u64,
    }

    /**
    *  constructor
    */
    public(friend) fun default(ctx: &mut TxContext): SuidoubleLiquidPromisedPool {
        let current_epoch = tx_context::epoch(ctx);
        let pool = SuidoubleLiquidPromisedPool { 
            all_time_promised_amount: 0,
            all_time_extra_amount: 0,

            promised_amount: 0,
            promised_sui: balance::zero<SUI>(),

            promised_amount_in_staked: 0,
            promised_staked: table::new(ctx),
            got_extra_staked: balance::zero<SUI>(),

            created_at_epoch: current_epoch,

            promised_promised_waiting_by_epoch: table::new(ctx),
            still_waiting_for_sui_amount: 0,


            oldest_waiting_epoch: current_epoch,
        };

        pool 
    }

    /**
    *  
    *  Returns an amount of mSUI scheduled to be fulfilled at specific epoch in the future
    */
    public(friend) fun promised_amount_at_epoch(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, at_epoch: u64): u64 {
        let waiting_for_amount_at_epoch = 0;
        if (contains_promised_waiting_by_epoch(suidouble_liquid_promised_pool, at_epoch)) { 
            let waiting_promised_vec_mut = table::borrow_mut(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, at_epoch);

            let n = vector::length(waiting_promised_vec_mut);
            let i = 0;
            while (i < n) {
                let promised_waiting_ref = vector::borrow(waiting_promised_vec_mut, i);
                waiting_for_amount_at_epoch = waiting_for_amount_at_epoch + promised_waiting_ref.expected_sui_amount;
                i = i + 1;
            };
        };

        waiting_for_amount_at_epoch
    }

    /**
    *   balance we gathered from StakedSui we exchanged later than expected
    */
    public(friend) fun take_extra_staked_balance(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool): Balance<SUI> {
        balance::withdraw_all(&mut suidouble_liquid_promised_pool.got_extra_staked)
    } 

    /**
    *   withdraw perfect StakedSui (see hackpaper) for specific promise
    */
    public(friend) fun take_promised_staked_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, promise_id: ID, state: &mut SuiSystemState, ctx: &mut TxContext): Coin<SUI> {
        let still_staked = table::remove(&mut suidouble_liquid_promised_pool.promised_staked, promise_id);
        
        let SuidoubleLiquidPromisedPoolStillStaked { staked_sui, expected_sui_amount, promise_id: _ } = still_staked;
        let withdrawn_balance = request_withdraw_stake_non_entry(state, staked_sui, ctx);

        let withdrawn_amount = balance::value(&withdrawn_balance);
        let expected_sui_amount_fulfilled = expected_sui_amount;
        if (expected_sui_amount > withdrawn_amount) {
            expected_sui_amount_fulfilled = withdrawn_amount;
        };

        let coin = coin::take(&mut withdrawn_balance, expected_sui_amount_fulfilled, ctx);
        suidouble_liquid_promised_pool.promised_amount_in_staked = suidouble_liquid_promised_pool.promised_amount_in_staked - expected_sui_amount_fulfilled;

        let got_extra_amount = balance::value(&withdrawn_balance);
        balance::join(&mut suidouble_liquid_promised_pool.got_extra_staked, withdrawn_balance);

        suidouble_liquid_promised_pool.all_time_extra_amount = suidouble_liquid_promised_pool.all_time_extra_amount + got_extra_amount;

        coin
    } 

    /**
    *   is there a perfect StakedSui (see hackpaper) for specific promise
    */
    public(friend) fun is_there_promised_staked_sui(suidouble_liquid_promised_pool:  &SuidoubleLiquidPromisedPool, promise_id: ID): bool {
        table::contains(&suidouble_liquid_promised_pool.promised_staked, promise_id)
    }

    /**
    *   attach perfect StakedSui (see hackpaper) for specific promise
    */
    public(friend) fun attach_promised_staked_sui(suidouble_liquid_promised_pool:  &mut SuidoubleLiquidPromisedPool, staked_sui: StakedSui, expected_sui_amount: u64, promise_id: ID) {
        let still_staked = SuidoubleLiquidPromisedPoolStillStaked {
            staked_sui: staked_sui,
            expected_sui_amount: expected_sui_amount,
            promise_id: promise_id,
        };
        table::add(&mut suidouble_liquid_promised_pool.promised_staked, promise_id, still_staked);

        suidouble_liquid_promised_pool.promised_amount_in_staked = suidouble_liquid_promised_pool.promised_amount_in_staked + expected_sui_amount;
        
        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount - expected_sui_amount;
    }

    /**
    *   amount still promised
    */
    public(friend) fun promised_amount(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool): u64 { 
        suidouble_liquid_promised_pool.promised_amount 
    }

    /**
    *   amount still promised to be fulfilled
    */
    public(friend) fun still_waiting_for_sui_amount(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool): u64 {
        suidouble_liquid_promised_pool.still_waiting_for_sui_amount
    }

    /**
    *   try to attach perfect stakedsui for the current epoch (see hackpaper for more details)
    */
    public(friend) fun try_to_fill_with_perfect_staked_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, staked_pool: &mut suidouble_liquid_staker::SuidoubleLiquidStaker, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        let still_waiting_for_sui_amount = 0;
        if (contains_promised_waiting_by_epoch(suidouble_liquid_promised_pool, current_epoch)) { 
            let waiting_promised_vec = table::remove(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, current_epoch);

            let n = vector::length(&waiting_promised_vec);
            let i = 0;
            while (i < n) {
                let promised_waiting = vector::pop_back(&mut waiting_promised_vec);
                let expected_sui_amount = promised_waiting.expected_sui_amount;

                // find if we can extract perfect staked sui for this promise
                let perfect_staked_sui_option = suidouble_liquid_staker::find_the_perfect_staked_sui(staked_pool, expected_sui_amount, state, ctx);
                
                if (option::is_some(&perfect_staked_sui_option)) {
                    // we found a perfect StakedSui for this withdraw
                    let perfect_staked_sui = option::destroy_some(perfect_staked_sui_option);
                    let promise_id = promised_waiting.promise_id;

                    attach_promised_staked_sui(suidouble_liquid_promised_pool, perfect_staked_sui, expected_sui_amount, promise_id);
                } else {
                    option::destroy_none(perfect_staked_sui_option); // just removing an none option

                    // and ask to fill the PromisedPool in a normal way
                    still_waiting_for_sui_amount = still_waiting_for_sui_amount + expected_sui_amount;
                };

                i = i + 1;
            };

            suidouble_liquid_promised_pool.still_waiting_for_sui_amount = suidouble_liquid_promised_pool.still_waiting_for_sui_amount + still_waiting_for_sui_amount;
        };
    }

    /**
    *   is there something waiting promised on the specific epoch?
    */
    public(friend) fun contains_promised_waiting_by_epoch(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, on_epoch: u64): bool {
        // we need to collect previous epochs ( in case there was no transactions to process and once_per_epoch was not executed )
        if (on_epoch > 0) {
            let i = on_epoch - 1;
            while (i >= suidouble_liquid_promised_pool.oldest_waiting_epoch && i > 0) {
                if (table::contains(&suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, i)) {
                    let waiting_promised_vec = table::remove(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, i);
                    if (table::contains(&suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch)) {
                        // push it to current epoch vector
                        let cur_vector_mut = table::borrow_mut(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch);
                        vector::append(cur_vector_mut, waiting_promised_vec);
                    } else {
                        let cur_vector = vector::empty();
                        vector::append(&mut cur_vector, waiting_promised_vec);
                        table::add(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch, cur_vector);
                    };
                };

                if (i > 0) {
                    i = i - 1;
                };
            };
        };

        suidouble_liquid_promised_pool.oldest_waiting_epoch = on_epoch; // as we moved everything to this epoch table

        if (table::contains(&suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch)) {
            return true
        };

        false
    }

    /**
    *  Promise some amount of mSUI
    */
    public(friend) fun increment_promised_amount(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, by_amount: u64, by_epoch: u64, promise_id: ID) {
        suidouble_liquid_promised_pool.all_time_promised_amount = suidouble_liquid_promised_pool.all_time_promised_amount + by_amount;
        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount + by_amount;


        // store promise_id
        let promised_waiting = SuidoubleLiquidPromisedWaiting {
            expected_sui_amount: by_amount,
            promise_id: promise_id,
        };

        if (table::contains(&suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, by_epoch)) {
            let to_mut = table::borrow_mut(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, by_epoch);
            vector::push_back(to_mut, promised_waiting);
        } else {
            let vec = vector::singleton(promised_waiting);
            table::add(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, by_epoch, vec);
        }
    }


    /**
    *  fulfill promised amount with SUI
    */
    public(friend) fun fulfill_with_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, sui: Balance<SUI>) {
        // @todo: check if passed more than needed
        let amount = balance::value(&sui);
        balance::join(&mut suidouble_liquid_promised_pool.promised_sui, sui);

        suidouble_liquid_promised_pool.still_waiting_for_sui_amount = suidouble_liquid_promised_pool.still_waiting_for_sui_amount - amount;

        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount - amount;
    }

    /**
    *  take some SUI for payout
    */
    public(friend) fun take_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        coin::take(&mut suidouble_liquid_promised_pool.promised_sui, amount, ctx)
    } 

}