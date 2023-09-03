
module suidouble_liquid::suidouble_liquid_promised_pool {
    friend suidouble_liquid::suidouble_liquid;

    // use suidouble_liquid::suidouble_liquid_coin;
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

    // use std::option::{Self, Option, none};
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
        // promised_amount_by_epoch: Table<u64, u64>,

        promised_promised_waiting_by_epoch: Table<u64, vector<SuidoubleLiquidPromisedWaiting>>,
        still_waiting_for_sui_amount: u64,

        oldest_waiting_epoch: u64,
        // newest_waiting_epoch: u64,
    }

    public(friend) fun default(ctx: &mut TxContext): SuidoubleLiquidPromisedPool {
        let current_epoch = tx_context::epoch(ctx);
        let pool = SuidoubleLiquidPromisedPool { 
            all_time_promised_amount: 0,
            all_time_extra_amount: 0,

            promised_amount: 0,
            promised_sui: balance::zero<SUI>(),
            // promised_staked: vector::empty(),

            promised_amount_in_staked: 0,
            promised_staked: table::new(ctx),
            got_extra_staked: balance::zero<SUI>(),

            created_at_epoch: current_epoch,
            // promised_amount_by_epoch: table::new(ctx),

            promised_promised_waiting_by_epoch: table::new(ctx),
            still_waiting_for_sui_amount: 0,


            oldest_waiting_epoch: current_epoch,
            // newest_waiting_epoch: 0,
        };

        pool 
    }

    public(friend) fun take_extra_staked_balance(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool): Balance<SUI> {
        balance::withdraw_all(&mut suidouble_liquid_promised_pool.got_extra_staked)
    } 

    public(friend) fun take_promised_staked_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, promise_id: ID, state: &mut SuiSystemState, ctx: &mut TxContext): Coin<SUI> {
        let still_staked = table::remove(&mut suidouble_liquid_promised_pool.promised_staked, promise_id);
        
        let SuidoubleLiquidPromisedPoolStillStaked { staked_sui, expected_sui_amount, promise_id: _ } = still_staked;
        let withdrawn_balance = request_withdraw_stake_non_entry(state, staked_sui, ctx);
        // let withdrawn_amount = balance::value(&withdrawn_balance);

        let coin = coin::take(&mut withdrawn_balance, expected_sui_amount, ctx);
        suidouble_liquid_promised_pool.promised_amount_in_staked = suidouble_liquid_promised_pool.promised_amount_in_staked - expected_sui_amount;

        let got_extra_amount = balance::value(&withdrawn_balance);
        balance::join(&mut suidouble_liquid_promised_pool.got_extra_staked, withdrawn_balance);

        suidouble_liquid_promised_pool.all_time_extra_amount = suidouble_liquid_promised_pool.all_time_extra_amount + got_extra_amount;

        coin
    } 

    public(friend) fun is_there_promised_staked_sui(suidouble_liquid_promised_pool:  &SuidoubleLiquidPromisedPool, promise_id: ID): bool {
        table::contains(&suidouble_liquid_promised_pool.promised_staked, promise_id)
    }

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

    public(friend) fun promised_amount(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool): u64 { 
        suidouble_liquid_promised_pool.promised_amount 
    }

    public(friend) fun still_waiting_for_sui_amount(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool): u64 {
        suidouble_liquid_promised_pool.still_waiting_for_sui_amount
    }

    public(friend) fun try_to_fill_with_perfect_staked_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, staked_pool: &mut suidouble_liquid_staker::SuidoubleLiquidStaker, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        let still_waiting_for_sui_amount = 0;
        if (contains_promised_waiting_by_epoch(suidouble_liquid_promised_pool, current_epoch)) { // @todo: should pull previous epochs items if any
            let waiting_promised_vec = table::remove(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, current_epoch);

            let n = vector::length(&waiting_promised_vec);
            let i = 0;
            while (i < n) {
                let promised_waiting = vector::pop_back(&mut waiting_promised_vec);
                let expected_sui_amount = promised_waiting.expected_sui_amount;

                let perfect_staked_sui_option = suidouble_liquid_staker::find_the_perfect_staked_sui(staked_pool, expected_sui_amount, state, ctx);
                
                if (option::is_some(&perfect_staked_sui_option)) {
                    // we found a perfect StakedSui for this withdraw
                    let perfect_staked_sui = option::destroy_some(perfect_staked_sui_option);
                    let promise_id = promised_waiting.promise_id;

                    attach_promised_staked_sui(suidouble_liquid_promised_pool, perfect_staked_sui, expected_sui_amount, promise_id);
                } else {
                    option::destroy_none(perfect_staked_sui_option); // just removing an none option

                    still_waiting_for_sui_amount = still_waiting_for_sui_amount + expected_sui_amount;
                };

                i = i + 1;
            };

            suidouble_liquid_promised_pool.still_waiting_for_sui_amount = suidouble_liquid_promised_pool.still_waiting_for_sui_amount + still_waiting_for_sui_amount;
        };
    }

    public(friend) fun contains_promised_waiting_by_epoch(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, on_epoch: u64): bool {
        // we need to collect previous epochs ( in case there was no transactions to process )
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

        // if (table::contains(&suidouble_liquid_promised_pool.promised_amount_by_epoch, by_epoch)) {
        //     let to_mut = table::borrow_mut(&mut suidouble_liquid_promised_pool.promised_amount_by_epoch, by_epoch);
        //     *to_mut = *to_mut + by_amount;
        // } else {
        //     table::add(&mut suidouble_liquid_promised_pool.promised_amount_by_epoch, by_epoch, by_amount);
        // };

        // if (suidouble_liquid_promised_pool.oldest_waiting_epoch == 0 || suidouble_liquid_promised_pool.oldest_waiting_epoch > by_epoch) {
        //     suidouble_liquid_promised_pool.oldest_waiting_epoch = by_epoch;
        // };
        // if (suidouble_liquid_promised_pool.newest_waiting_epoch == 0 || suidouble_liquid_promised_pool.newest_waiting_epoch < by_epoch) {
        //     suidouble_liquid_promised_pool.newest_waiting_epoch = by_epoch;
        // };

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


    public(friend) fun fulfill_with_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, sui: Balance<SUI>) {
        // @todo: check if passed more than needed
        let amount = balance::value(&sui);
        balance::join(&mut suidouble_liquid_promised_pool.promised_sui, sui);

        suidouble_liquid_promised_pool.still_waiting_for_sui_amount = suidouble_liquid_promised_pool.still_waiting_for_sui_amount - amount;

        suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount - amount;
        // decrement_promised_amount(suidouble_liquid_promised_pool, amount);
    }

    public(friend) fun take_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        coin::take(&mut suidouble_liquid_promised_pool.promised_sui, amount, ctx)
    } 


    // public(friend) fun promised_amount_at_epoch(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, epoch: u64): u64 { 
    //     if (table::contains(&suidouble_liquid_promised_pool.promised_amount_by_epoch, epoch)) {
    //         let amount_ref = table::borrow(&suidouble_liquid_promised_pool.promised_amount_by_epoch, epoch);
    //         return (0 + *amount_ref)
    //     };

    //     0
    // }
    // /**
    // *  Private. Called from fulfill_with_sui, just moving out the logic
    // */
    // fun decrement_promised_amount(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, amount: u64) {
    //     suidouble_liquid_promised_pool.promised_amount = suidouble_liquid_promised_pool.promised_amount - amount;

    //     let i = suidouble_liquid_promised_pool.oldest_waiting_epoch;
    //     let till = suidouble_liquid_promised_pool.newest_waiting_epoch;
    //     let left_to_increase = amount;

    //     while (i <= till && left_to_increase > 0) {
    //         if (table::contains(&suidouble_liquid_promised_pool.promised_amount_by_epoch, i)) {
    //             let to_mut = table::borrow_mut(&mut suidouble_liquid_promised_pool.promised_amount_by_epoch, i);
    //             let to_mut_value = *to_mut;
    //             if (to_mut_value > amount) {
    //                 // just decrement promised amount
    //                 *to_mut = *to_mut - amount;
    //                 left_to_increase = 0;
    //             } else {
    //                 if (to_mut_value > 0) {
    //                     left_to_increase = left_to_increase - to_mut_value; 
    //                     *to_mut = 0;
    //                 };

    //                 if (i == suidouble_liquid_promised_pool.newest_waiting_epoch) {
    //                     // we fulfilled everything
    //                     suidouble_liquid_promised_pool.newest_waiting_epoch = 0;
    //                     suidouble_liquid_promised_pool.oldest_waiting_epoch = 0;
    //                 } else {
    //                     suidouble_liquid_promised_pool.oldest_waiting_epoch = i + 1;
    //                     // actually it may be not the next, but next + N, but it's enough for gas optimization,
    //                     // as we'll just skip empties and set it to real next on the next fulfill
    //                 }
    //             };
    //         };

    //         i = i + 1;
    //     };
    // }

    // public(friend) fun promised_amount_till_epoch(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, epoch: u64): u64 {
    //     let ret = 0;
    //     let i = epoch;
    //     let till = suidouble_liquid_promised_pool.created_at_epoch + 1;

    //     while (i >= till) {
    //         ret = ret + promised_amount_at_epoch(suidouble_liquid_promised_pool, i);

    //         if (i > 0) {
    //             i = i - 1;
    //         }
    //     };

    //     ret
    // }

    // // @todo: have to get vector with previous items too
    // public(friend) fun promised_waiting_by_epoch(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, on_epoch: u64): &vector<SuidoubleLiquidPromisedWaiting> {
    //     // if (table::contains(&suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch)) {
    //     //     return table::borrow(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch);
    //     // };

    //     // waiting_promised_vec_ref
    //     // &vector::empty()

    //     table::borrow(&mut suidouble_liquid_promised_pool.promised_promised_waiting_by_epoch, on_epoch)
    // }
    // public(friend) fun promise_sui(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, sui: &mut Balance<SUI>)

    // public(friend) fun promise(suidouble_liquid_promised_pool: &SuidoubleLiquidPromisedPool, suidouble_liquid_promised_pool: &suidouble_liquid_staker::SuidoubleLiquidStaker, amount: u64) {

    // } 
    

    // public(friend) fun attach_waiting_promised_staked_sui(suidouble_liquid_promised_pool: &mut SuidoubleLiquidPromisedPool, promised_waiting: &SuidoubleLiquidPromisedWaiting, staked_sui: StakedSui) {
    //     let promise_id = promised_waiting.promise_id;
    //     let expected_sui_amount = promised_waiting.expected_sui_amount;

    //     let still_staked = SuidoubleLiquidPromisedPoolStillStaked {
    //         staked_sui: staked_sui,
    //         expected_sui_amount: expected_sui_amount,
    //         promise_id: promise_id,
    //     };
    //     table::add(&mut suidouble_liquid_promised_pool.promised_staked, promise_id, still_staked);

    //     suidouble_liquid_promised_pool.all_time_promised_amount = suidouble_liquid_promised_pool.all_time_promised_amount + expected_sui_amount;
    //     suidouble_liquid_promised_pool.promised_amount_in_staked = suidouble_liquid_promised_pool.promised_amount_in_staked + expected_sui_amount;
    // }

    // public(friend) fun promised_waiting_expected_sui_amount(promised_waiting: &SuidoubleLiquidPromisedWaiting): u64 {
    //     promised_waiting.expected_sui_amount
    // }

    // public(friend) fun promised_waiting_promise_id(promised_waiting: &SuidoubleLiquidPromisedWaiting): ID {
    //     promised_waiting.promise_id
    // }
}