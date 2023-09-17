/**
*   Manages helping object SuidoubleLiquidStats
*     currently it stores mapping of pool_id to validator_address, so we can easily get validator address to stake to the same pool we already did
*     but also added metadata object to store something in the future (settings ,stats etc), with no need to refactor functions structure
*/
module suidouble_liquid::suidouble_liquid_stats {
    friend suidouble_liquid::suidouble_liquid;
    friend suidouble_liquid::suidouble_liquid_staker;

    use sui::table::{Self, Table};
    use std::vector;
    use sui::tx_context::{TxContext};

    use std::option::{Option, none, some};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::event;

    struct NewLiquidStatsEvent has copy, drop {
        id: ID,
    }

    struct SuidoubleLiquidValidatorInfo has store, drop { 
        address: address,
        metadata: vector<u8>,
    }

    struct SuidoubleLiquidStats has key {
        id: UID,
        pool_ids: Table<ID, SuidoubleLiquidValidatorInfo>,
        metadata: vector<u8>,
    }

    /**
    *   Mint an object and transfer it to tx's author
    */
    public(friend) fun default_and_share(ctx: &mut TxContext) {
        let liquid_stats = default(ctx);

        event::emit(NewLiquidStatsEvent {
            id: object::uid_to_inner(&liquid_stats.id),
        });

        transfer::share_object(liquid_stats);
    }

    public(friend) fun default(ctx: &mut TxContext): SuidoubleLiquidStats {
        // let current_epoch = tx_context::epoch(ctx);
        let stats = SuidoubleLiquidStats {
            id: object::new(ctx),
            pool_ids: table::new(ctx),
            metadata: vector::empty(),
        };

        stats 
    }

    /**
    *   Add pool_id -> pool_address to the dictionary
    */
    public(friend) fun store_address(suidouble_liquid_stats: &mut SuidoubleLiquidStats, pool_id: ID, pool_address: address) {
        if (table::contains(&suidouble_liquid_stats.pool_ids, pool_id)) {
            // update?
            let validator_info = table::borrow_mut(&mut suidouble_liquid_stats.pool_ids, pool_id);
            validator_info.address = pool_address;
        } else {
            let validator_info = SuidoubleLiquidValidatorInfo {
                address: pool_address,
                metadata: vector::empty(),
            };

            table::add(&mut suidouble_liquid_stats.pool_ids, pool_id, validator_info);
        };
    }

    /**
    *   Get pool_address by the pool_id if available
    */
    public(friend) fun validator_address_by_pool_id(suidouble_liquid_stats: &mut SuidoubleLiquidStats, pool_id: ID): Option<address> {
        if (table::contains(&suidouble_liquid_stats.pool_ids, pool_id)) {
            let validator_info = table::borrow(&suidouble_liquid_stats.pool_ids, pool_id);

            return some(validator_info.address)
        };

        none()
    }
}