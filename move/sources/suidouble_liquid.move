
module suidouble_liquid::suidouble_liquid {
    const VERSION: u64 = 8;

    const WithdrawPromiseCooldownEpochs: u64 = 2;     // withdraw promise is ready to exchange for SUI in N epochs
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI, value we use to stake to StakedSui, our users can stake any amount to our pool
    const PRICE_K: u64 = 1_000_000_000; // 1 SUI, for price calculation, price values are amount you get for PRICE_K items

    const EWithdrawingTooMuch: u64 = 1;
    const ETooEarly: u64 = 2;
    const EDelegationOfZeroSui: u64 = 3;
    const EInvalidPromised: u64 = 4;

    /// Calling functions from the wrong package version
    const EWrongVersion: u64 = 5;

    const ENotAdmin: u64 = 6;
    const ENotUpgrade: u64 = 7;

    use suidouble_liquid::suidouble_liquid_coin;
    use suidouble_liquid::suidouble_liquid_staker;
    use suidouble_liquid::suidouble_liquid_promised_pool;
    use suidouble_liquid::suidouble_liquid_stats;

    use std::string::{utf8};

    use sui::event;

    use sui::tx_context::{Self, sender, TxContext};

    use sui::transfer;
    use sui_system::sui_system::SuiSystemState;

    use sui::package;
    use sui::display;

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    use sui::object::{Self, UID, ID};

    use std::option::{Self, Option, none};

    /// One-Time-Witness for the module.
    struct SUIDOUBLE_LIQUID has drop {}

    struct LiquidStore has key {
        id: UID,
        admin: ID,
        version: u64,

        pending_pool: Balance<SUI>,
        staked_with_rewards_balance: u64,  // helps with debuging, but we'll probably get rid of it on producation

        liquid_store_epoch: u64,
        treasury: Option<coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>>,

        staked_pool: suidouble_liquid_staker::SuidoubleLiquidStaker,
        promised_pool: suidouble_liquid_promised_pool::SuidoubleLiquidPromisedPool,

        fee_pool: Balance<SUI>,
        fee_pool_token: Balance<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>,

        immutable_pool_sui: Balance<SUI>,
        immutable_pool_tokens: Balance<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>,
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

    struct PriceEvent has copy, drop {   // emited for both deposit and withdraw
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

        price: u64,
    }

    struct WithdrawPromiseEvent has copy, drop {
        id: ID,
        price: u64,
        // token_amount: u64,
    }

    struct AdminCap has key {  // admin capability. Take care of this object. Issued to the creator on the package publishing
        id: UID,
    }


    fun init(otw: SUIDOUBLE_LIQUID, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);

        let admin = AdminCap {
            id: object::new(ctx),
        };

        let liquid_store = LiquidStore {
            id: object::new(ctx),
            admin: object::id(&admin),
            pending_pool: balance::zero<SUI>(),
            staked_with_rewards_balance: 0,
            liquid_store_epoch: 0,
            treasury: none(),

            staked_pool: suidouble_liquid_staker::default(),
            promised_pool: suidouble_liquid_promised_pool::default(ctx),

            fee_pool: balance::zero<SUI>(),
            fee_pool_token: balance::zero<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>(),

            version: VERSION,

            immutable_pool_sui: balance::zero<SUI>(),
            immutable_pool_tokens: balance::zero<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>(),
        };

        event::emit(NewLiquidStoreEvent {
            id: object::uid_to_inner(&liquid_store.id),
        });

        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            utf8(b"DoubleLiquid Withdraw Promise"),
            // For `link` we can build a URL using an `id` property
            utf8(b"https://doubleliquid.pro/promise/{id}"),
            utf8(b"https://suidouble.github.io/dl/promise.png"),
            utf8(b"DoubleLiquid Withdraw Promise of {sui_amount} mSUI, ready at epoch {fulfilled_at_epoch}"),
            // Project URL is usually static
            utf8(b"https://doubleliquid.pro/"),
            // Creator field can be any
            utf8(b"DoubleLiquid")
        ];

        // Get a new `Display` object for the `Color` type.
        let display = display::new_with_fields<LiquidStoreWithdrawPromise>(
            &publisher, keys, values, ctx
        );

        // Commit first version of `Display` to apply changes.
        display::update_version(&mut display);

        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(display, sender(ctx));

        suidouble_liquid_stats::default_and_share(ctx);

        transfer::transfer(admin, tx_context::sender(ctx));
        transfer::share_object(liquid_store);
    }

    /**
    *  Function to migrate the contract to new version. Should be executed by admin only (see AdminCap)
    */
    entry fun migrate(liquid_store: &mut LiquidStore, a: &AdminCap, ctx: &mut TxContext) {
        assert!(liquid_store.admin == object::id(a), ENotAdmin);
        assert!(liquid_store.version < VERSION, ENotUpgrade);

        liquid_store.version = VERSION;
        suidouble_liquid_stats::default_and_share(ctx);
    }

    // this function should be called right after the package deploy, attaching TreasuryCap to the LiquidStore
    // most other functions would not work if Treasury is not set
    public entry fun attach_treasury(liquid_store: &mut LiquidStore, treasury: coin::TreasuryCap<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, sui: Coin<SUI>, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        // filling immutable_pool, note. It's Immutable: you'll never able to withdraw this SUI or tokens, it's for stabilization of the price.
        let amount = coin::value(&sui);
        coin::put(&mut liquid_store.immutable_pool_sui, sui);

        // mint tokens as 1:1 on the deposit to the immutable pool
        let tokens = suidouble_liquid_coin::mint_and_return(&mut treasury, amount, ctx);
        coin::put(&mut liquid_store.immutable_pool_tokens, tokens);

        // can be called only once? @todo: check
        option::fill(&mut liquid_store.treasury, treasury);
    }

    /**
    *  Function to collect fees, both as SUI and iSUI in one call. Executed by admin only.
    */
    public entry fun collect_fees(liquid_store: &mut LiquidStore, _admin: &AdminCap, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let amount_sui = balance::value(&liquid_store.fee_pool);
        let to_pay_out_sui = coin::take(&mut liquid_store.fee_pool, amount_sui, ctx);
        let amount_token = balance::value(&liquid_store.fee_pool_token);
        let to_pay_out_token = coin::take(&mut liquid_store.fee_pool_token, amount_token, ctx);

        transfer::public_transfer(to_pay_out_sui, tx_context::sender(ctx));
        transfer::public_transfer(to_pay_out_token, tx_context::sender(ctx));
    }

    /**
    *   Send PendingPool to staked. Helping function, can increase APY, if executed right before the next epoch arrives. Totally optional though.
    *     v2 version - with respect to SuidoubleLiquidStats object
    */
    public entry fun stake_pending_no_wait_v2(liquid_store: &mut LiquidStore, _admin: &AdminCap, sta: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        send_pending_to_staked_v2(liquid_store, sta, state, ctx);
    }

    /**
    *   Send PendingPool to staked. Helping function, can increase APY, if executed right before the next epoch arrives. Totally optional though.
    */
    public entry fun stake_pending_no_wait(liquid_store: &mut LiquidStore, _admin: &AdminCap, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        send_pending_to_staked(liquid_store, state, ctx);
    }


    /**
    * Amount of currently circulated mTokens
    */
    fun get_token_supply(liquid_store: &LiquidStore):u64 {
        let treasury_ref = option::borrow(&liquid_store.treasury); // aborts if there is no treasury
        coin::total_supply(treasury_ref)
    }


    /**
    *  amount of mSUI you can get for 1_000_000_000 mTokens
    */
    fun get_current_price(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let total_supply = get_token_supply(liquid_store);

        if (total_supply == 0) {
            return (PRICE_K)
        };

        let immutable_amount = immutable_amount(liquid_store);
        let pending_amount = pending_amount(liquid_store);
        let promised_amount = promised_amount(liquid_store);
        let currently_staked_with_rewards = staked_amount_with_rewards(liquid_store, state, ctx);

        let total_in = immutable_amount + pending_amount + currently_staked_with_rewards - promised_amount;

        let price = ( (total_in as u128) * (PRICE_K as u128) ) / (total_supply as u128);

        (price as u64)
    }

    /**
    *  amount of mTokens you can get for 1_000_000_000 mSUI
    */
    fun get_current_price_reverse(liquid_store: &LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext):u64 {
        let immutable_amount = immutable_amount(liquid_store);
        let pending_amount = pending_amount(liquid_store);
        let promised_amount = promised_amount(liquid_store);
        let currently_staked_with_rewards = staked_amount_with_rewards(liquid_store, state, ctx);

        let total_in = immutable_amount + pending_amount + currently_staked_with_rewards - promised_amount;

        if (total_in == 0) {
            return (PRICE_K)
        };

        let total_supply = get_token_supply(liquid_store);

        let price = ( (total_supply as u128) * (PRICE_K as u128) ) / (total_in as u128);

        (price as u64)
    }

    /**
    * amount of mSUI in immutable pool
    */
    public(friend) fun immutable_amount(liquid_store: &LiquidStore): u64 {
        // suidouble_liquid_staker::staked_amount(&liquid_store.staked_pool)
        balance::value(&liquid_store.immutable_pool_sui)
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

    /**
    * currently promised mSUI amount (not yet fulfilled)
    */
    public(friend) fun promised_amount(liquid_store: &LiquidStore): u64 { 
        suidouble_liquid_promised_pool::promised_amount(&liquid_store.promised_pool)
    }

    /**
    *  Amount of mSUI promised pool still waits to be added into
    */
    public(friend) fun still_waiting_for_sui_amount(liquid_store: &LiquidStore): u64 {
        suidouble_liquid_promised_pool::still_waiting_for_sui_amount(&liquid_store.promised_pool)
    }


    /**
    *  Deposit SUI coin object to the pending pool. Use merge_coins on client side to combine the vector if needed
    *    v2 version - with the respect to SuidoubleLiquidStats object
    */
    public entry fun deposit_v2(liquid_store: &mut LiquidStore, coin: Coin<SUI>, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);
        // let staked_sui = request_add_stake_non_entry(state, coin, validator_address, ctx);

        let current_price_reverse = get_current_price_reverse(liquid_store, state, ctx);
        // current price is amount of tokens you get from 1 sui

        let sui_amount = coin::value(&coin);

        coin::put(&mut liquid_store.pending_pool, coin);

        let token_amount = ( (sui_amount as u128) * (current_price_reverse as u128) ) / ( PRICE_K as u128 );

        let treasury = option::borrow_mut(&mut liquid_store.treasury); // aborts if there is no treasury

        suidouble_liquid_coin::mint(treasury, (token_amount as u64), ctx);

        event::emit(PriceEvent {
            price_reverse: current_price_reverse,
            price: 0,
        });

        once_per_epoch_if_needed_v2(liquid_store, stats, state, ctx);
    }

    /**
    *  Deposit SUI coin object to the pending pool. Use merge_coins on client side to combine the vector if needed
    */
    public entry fun deposit(liquid_store: &mut LiquidStore, coin: Coin<SUI>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let current_price_reverse = get_current_price_reverse(liquid_store, state, ctx);
        // current price is amount of tokens you get from 1 sui

        let sui_amount = coin::value(&coin);

        coin::put(&mut liquid_store.pending_pool, coin);

        let token_amount = ( (sui_amount as u128) * (current_price_reverse as u128) ) / ( PRICE_K as u128 );

        let treasury = option::borrow_mut(&mut liquid_store.treasury); // aborts if there is no treasury

        suidouble_liquid_coin::mint(treasury, (token_amount as u64), ctx);

        event::emit(PriceEvent {
            price_reverse: current_price_reverse,
            price: 0,
        });

        once_per_epoch_if_needed(liquid_store, state, ctx);
    }

    /**
    *  Burn iSUI and get nothing back. Just in case you want to increase the pool price a little.
    *    Use case - for admin to burn the fees
    */
    public entry fun burn_and_get_nothing(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, _state: &mut SuiSystemState, _ctx: &mut TxContext) {
        let treasury = option::borrow_mut(&mut liquid_store.treasury);
        suidouble_liquid_coin::burn(treasury, input_coin);
    }

    /**
    * Try to perform quick withdraw, exchange of iSUI to SUI, if there's amount available
    */
    public entry fun withdraw_fast(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let token_amount = coin::value(&input_coin);

        let current_price = get_current_price(liquid_store, state, ctx);
        let sui_amount = ( (token_amount as u128) * (current_price as u128) ) / ( PRICE_K as u128 );
        let sui_amount64 = ( sui_amount as u64 );

        event::emit(PriceEvent {
            price_reverse: 0,
            price: current_price,
        });

        let treasury = option::borrow_mut(&mut liquid_store.treasury);
        suidouble_liquid_coin::burn(treasury, input_coin);

        let current_epoch = tx_context::epoch(ctx);

        let taken_balance = balance::zero<SUI>();
        let taken_balance_amount = 0;

        // first - take needed amount from the PendingPool
        let amount_to_take_from_pending = sui_amount64;
        let current_pending_amount = pending_amount(liquid_store);
        if (current_pending_amount < sui_amount64) {
            amount_to_take_from_pending = current_pending_amount;
        };

        if (amount_to_take_from_pending > 0) {
            let taken = balance::split(&mut liquid_store.pending_pool, amount_to_take_from_pending);
            balance::join(&mut taken_balance, taken);
            taken_balance_amount = taken_balance_amount + amount_to_take_from_pending;
        };

        if (taken_balance_amount < sui_amount64) {
            // check if we can get remaining from the stakedPool
            let promised_next_epoch = suidouble_liquid_promised_pool::promised_amount_at_epoch(&mut liquid_store.promised_pool, current_epoch + 1);
            let available_next_epoch = suidouble_liquid_staker::staked_amount_available(&mut liquid_store.staked_pool, state, current_epoch + 1);

            let available_for_fast_withdraw = 0;
            if (promised_next_epoch < available_next_epoch) {
                available_for_fast_withdraw = available_next_epoch - promised_next_epoch;
            };

            let still_waiting = sui_amount64 - taken_balance_amount;
            let still_waiting_normalized = still_waiting;
            if (still_waiting_normalized < MIN_STAKING_THRESHOLD) {
                still_waiting_normalized = MIN_STAKING_THRESHOLD;
            };

            assert!(still_waiting_normalized <= available_for_fast_withdraw, EWithdrawingTooMuch);

            let unstaked = suidouble_liquid_staker::unstake_sui(&mut liquid_store.staked_pool, still_waiting_normalized, state, ctx);
            let unstaked_amount = balance::value(&unstaked);

            assert!(unstaked_amount <= available_for_fast_withdraw, EWithdrawingTooMuch);

            taken_balance_amount = taken_balance_amount + unstaked_amount;

            balance::join(&mut taken_balance, unstaked);
        };

        assert!(taken_balance_amount >= sui_amount64, EWithdrawingTooMuch);

        let fee_permille = 20;
        let fee_amount = sui_amount / 1000 * fee_permille;

        sui_amount64 = sui_amount64 - (fee_amount as u64);

        let fee = balance::split(&mut taken_balance, (fee_amount as u64));
        
        balance::join(&mut liquid_store.fee_pool, fee);

        let to_pay_out = coin::take(&mut taken_balance, sui_amount64, ctx);

        // anything left is sent to pending pool
        balance::join(&mut liquid_store.pending_pool, taken_balance);

        transfer::public_transfer(to_pay_out, tx_context::sender(ctx));
    }


    /**
    *  Exchange iSUI to the LiquidStoreWithdrawPromise
    *   v2 - with a respect to SuidoubleLiquidStats object
    */
    public entry fun withdraw_v2(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let token_amount = coin::value(&input_coin);

        let current_price = get_current_price(liquid_store, state, ctx);
        let sui_amount = ( (token_amount as u128) * (current_price as u128) ) / ( PRICE_K as u128 );// suidouble_liquid_coin::token_to_sui(token_amount, current_price);

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


        suidouble_liquid_promised_pool::increment_promised_amount(&mut liquid_store.promised_pool, (sui_amount as u64), fulfilled_at_epoch, object::id(&liquid_withdraw_promise));

        transfer::public_transfer(liquid_withdraw_promise, tx_context::sender(ctx));

        once_per_epoch_if_needed_v2(liquid_store, stats, state, ctx);
    }


    /**
    *  Exchange iSUI to the LiquidStoreWithdrawPromise
    */
    public entry fun withdraw(liquid_store: &mut LiquidStore, input_coin: Coin<suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN>, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let token_amount = coin::value(&input_coin);

        let current_price = get_current_price(liquid_store, state, ctx);
        let sui_amount = ( (token_amount as u128) * (current_price as u128) ) / ( PRICE_K as u128 );// suidouble_liquid_coin::token_to_sui(token_amount, current_price);

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


        suidouble_liquid_promised_pool::increment_promised_amount(&mut liquid_store.promised_pool, (sui_amount as u64), fulfilled_at_epoch, object::id(&liquid_withdraw_promise));

        transfer::public_transfer(liquid_withdraw_promise, tx_context::sender(ctx));

        once_per_epoch_if_needed(liquid_store, state, ctx);
    }

    /**
    *  Fulfil LiquidStoreWithdrawPromise, burn it and get promised SUI
    *    v2 version - with a respect to SuidoubleLiquidStats object
    */
    public entry fun fulfill_v2(liquid_store: &mut LiquidStore, promise: LiquidStoreWithdrawPromise, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let current_epoch = tx_context::epoch(ctx);

        assert!(promise.fulfilled_at_epoch <= current_epoch, ETooEarly);

        once_per_epoch_if_needed_v2(liquid_store, stats, state, ctx);

        if (suidouble_liquid_promised_pool::is_there_promised_staked_sui(&mut liquid_store.promised_pool, object::id(&promise))) {
            // we have StakedSui kept for this promise
            let coin = suidouble_liquid_promised_pool::take_promised_staked_sui(&mut liquid_store.promised_pool, object::id(&promise), state, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx)); //  to promise.for ???
        } else {
            let sui_amount_to_use = promise.sui_amount;
            let coin = suidouble_liquid_promised_pool::take_sui(&mut liquid_store.promised_pool, sui_amount_to_use, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx)); //  to promise.for ???
        };

        // and remove a promise
        let LiquidStoreWithdrawPromise { id, for: _, sui_amount: _, token_amount: _, fulfilled_at_epoch: _ } = promise;
        object::delete(id);
    }

    /**
    *  Fulfil LiquidStoreWithdrawPromise, burn it and get promised SUI
    */
    public entry fun fulfill(liquid_store: &mut LiquidStore, promise: LiquidStoreWithdrawPromise, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let current_epoch = tx_context::epoch(ctx);

        assert!(promise.fulfilled_at_epoch <= current_epoch, ETooEarly);

        once_per_epoch_if_needed(liquid_store, state, ctx);

        if (suidouble_liquid_promised_pool::is_there_promised_staked_sui(&mut liquid_store.promised_pool, object::id(&promise))) {
            // we have StakedSui kept for this promise
            let coin = suidouble_liquid_promised_pool::take_promised_staked_sui(&mut liquid_store.promised_pool, object::id(&promise), state, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx)); //  to promise.for ???
        } else {
            let sui_amount_to_use = promise.sui_amount;
            let coin = suidouble_liquid_promised_pool::take_sui(&mut liquid_store.promised_pool, sui_amount_to_use, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx)); //  to promise.for ???
        };

        // and remove a promise
        let LiquidStoreWithdrawPromise { id, for: _, sui_amount: _, token_amount: _, fulfilled_at_epoch: _ } = promise;
        object::delete(id);
    }

    /**
    *  Helpful function to calculate current amount of staked SUI + rewards till this epoch
    *      logic taken from test function of staking_pool module
    */
    entry fun calc_expected_profits(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let expected_amount = staked_amount_with_rewards(liquid_store, state, ctx);
        liquid_store.staked_with_rewards_balance = expected_amount;
    }


    /**
    *  Guess what? I wrote the same one two times and forgot about it.
    *  Helpful function to calculate current amount of staked SUI + rewards till this epoch
    *      logic taken from test function of staking_pool module
    */
    public entry fun test_staked_amount_with_rewards(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let expected_staked = staked_amount_with_rewards(liquid_store, state, ctx);
        liquid_store.staked_with_rewards_balance = expected_staked; // @todo: do we need to expose this???
    }

    /**
    *  Gather development fees ( 0.5% apy of token supply ) and move them to fee_pool_token
    *      + gather fees from extra_staked_balance ( see hackpaper ) and split it to fee_pool and pending_pool
    *      + update liquid_store_epoch of the pool to current one
    */
    fun gather_development_fees_and_increment_epoch(liquid_store: &mut LiquidStore, _state: &mut SuiSystemState, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        let total_token_supply = get_token_supply(liquid_store);
        let store_was_epoch = liquid_store.liquid_store_epoch;

        if (current_epoch > store_was_epoch) {
            // take got_extra_staked from promised_pool
            let extra_staked_balance = suidouble_liquid_promised_pool::take_extra_staked_balance(&mut liquid_store.promised_pool);
            let extra_staked_balance_value = balance::value(&extra_staked_balance);
            if (extra_staked_balance_value > 0) {
                let extra_staked_balance_to_fees = extra_staked_balance_value / 2;
                let to_fees = balance::split(&mut extra_staked_balance, extra_staked_balance_to_fees);

                balance::join(&mut liquid_store.fee_pool, to_fees);
            };
            balance::join(&mut liquid_store.pending_pool, extra_staked_balance);

            // got 0.5% p.a. fees in tokens:

            let epoch_diff = current_epoch - store_was_epoch;
            // ( 0.5% of all supply per year ) = 0.5 / 365 
            // 365 * 100 = percent of p.a. per day, 365 * 1000 = 0.1% of p.a. per day = (0.1 / 365)%
            let fee_k = 5 * epoch_diff;
            // fee_k = 0;

            let token_amount = (total_token_supply as u128)
                    * (fee_k as u128)
                    / 365000;

            let treasury = option::borrow_mut(&mut liquid_store.treasury); // aborts if there is no treasury
            let fee_coin = suidouble_liquid_coin::mint_and_return(treasury, (token_amount as u64), ctx);

            coin::put(&mut liquid_store.fee_pool_token, fee_coin);

            liquid_store.liquid_store_epoch = current_epoch;
        }
    }

    /**
    *  Function doing all background work, executed once every epoch and doing all things - 
    *      stake PendingPool
    *      unstake Promised amounts
    *      gather fees
    *      emits epoch info event
    *
    *      called as part of user-side functions in background. But may be executed alone as entry - to save some gas for users
    *
    *      v2 version - with a respect to SuidoubleLiquidStats object
    */
    public entry fun once_per_epoch_if_needed_v2(liquid_store: &mut LiquidStore, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let current_epoch = tx_context::epoch(ctx);
        if (current_epoch > liquid_store.liquid_store_epoch) {
            let was_pending_balance = pending_amount(liquid_store);//  liquid_store.pending_balance + 0;
            let was_promised_amount = promised_amount(liquid_store);// liquid_store.promised_amount + 0;

            let was_staked_amount = staked_amount(liquid_store);

            // fulfil promises first
            unstake_promised(liquid_store, state, ctx);

            suidouble_liquid_staker::quick_sort_by_apy(&mut liquid_store.staked_pool, state, current_epoch);

            // stake pending
            send_pending_to_staked_v2(liquid_store, stats, state, ctx);

            gather_development_fees_and_increment_epoch(liquid_store, state, ctx);

            let expected_staked = staked_amount_with_rewards(liquid_store, state, ctx);

            liquid_store.staked_with_rewards_balance = expected_staked; // @todo: do we need to expose this???

            event::emit(EpochEvent {
                expected_staked: expected_staked,
                was_pending_balance: was_pending_balance,
                was_staked_amount: was_staked_amount,
                was_promised_amount: was_promised_amount,
                after_pending_balance: (pending_amount(liquid_store)),
                after_staked_amount: (staked_amount(liquid_store)),
                after_promised_amount: promised_amount(liquid_store),
                epoch: current_epoch,
                price: get_current_price(liquid_store, state, ctx),
            });
        };
    }

    /**
    *  Function doing all background work, executed once every epoch and doing all things - 
    *      stake PendingPool
    *      unstake Promised amounts
    *      gather fees
    *      emits epoch info event
    *
    *      called as part of user-side functions in background. But may be executed alone as entry - to save some gas for users
    */
    public entry fun once_per_epoch_if_needed(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        assert!(liquid_store.version == VERSION, EWrongVersion);

        let current_epoch = tx_context::epoch(ctx);
        if (current_epoch > liquid_store.liquid_store_epoch) {
            let was_pending_balance = pending_amount(liquid_store);//  liquid_store.pending_balance + 0;
            let was_promised_amount = promised_amount(liquid_store);// liquid_store.promised_amount + 0;

            let was_staked_amount = staked_amount(liquid_store);

            // fulfil promises first
            unstake_promised(liquid_store, state, ctx);

            suidouble_liquid_staker::quick_sort_by_apy(&mut liquid_store.staked_pool, state, current_epoch);

            // stake pending
            send_pending_to_staked(liquid_store, state, ctx);

            gather_development_fees_and_increment_epoch(liquid_store, state, ctx);

            let expected_staked = staked_amount_with_rewards(liquid_store, state, ctx);

            liquid_store.staked_with_rewards_balance = expected_staked; // @todo: do we need to expose this???

            event::emit(EpochEvent {
                expected_staked: expected_staked,
                was_pending_balance: was_pending_balance,
                was_staked_amount: was_staked_amount,
                was_promised_amount: was_promised_amount,
                after_pending_balance: (pending_amount(liquid_store)),
                after_staked_amount: (staked_amount(liquid_store)),
                after_promised_amount: promised_amount(liquid_store),
                epoch: current_epoch,
                price: get_current_price(liquid_store, state, ctx),
            });
        };
    }


    /**
    *  stake PendingPool
    *  v2 version - with a respect to SuidoubleLiquidStats object
    */
    fun send_pending_to_staked_v2(liquid_store: &mut LiquidStore, stats: &mut suidouble_liquid_stats::SuidoubleLiquidStats, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pending_amount = pending_amount(liquid_store);
        let value_to_stake = (pending_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            suidouble_liquid_staker::stake_sui_v2(&mut liquid_store.staked_pool, &mut liquid_store.pending_pool, stats, state, ctx);
        }
    }

    /**
    *  stake SUI from PendingPool
    */
    fun send_pending_to_staked(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {
        let pending_amount = pending_amount(liquid_store);
        let value_to_stake = (pending_amount / MIN_STAKING_THRESHOLD) * MIN_STAKING_THRESHOLD;

        if (value_to_stake > 0) {
            suidouble_liquid_staker::stake_sui(&mut liquid_store.staked_pool, &mut liquid_store.pending_pool, state, ctx);
        }
    }

    /**
    *  move needed amount from PendingPool to PromisedPool if needed and available
    */
    fun send_pending_to_promised(liquid_store: &mut LiquidStore, _ctx: &mut TxContext) {
        let still_waiting_for_sui_amount = still_waiting_for_sui_amount(liquid_store);

        if (still_waiting_for_sui_amount > 0) {
            let pending_amount = pending_amount(liquid_store);
            if (pending_amount <= still_waiting_for_sui_amount) {
                // move everything
                let taken_balance = balance::withdraw_all(&mut liquid_store.pending_pool);
                suidouble_liquid_promised_pool::fulfill_with_sui(&mut liquid_store.promised_pool, taken_balance);

            } else {
                // we can split
                let taken_balance = balance::split(&mut liquid_store.pending_pool, still_waiting_for_sui_amount);
                suidouble_liquid_promised_pool::fulfill_with_sui(&mut liquid_store.promised_pool, taken_balance);

            }
        }
    }

    /**
    *  performs needed unstaking
    */
    fun unstake_promised(liquid_store: &mut LiquidStore, state: &mut SuiSystemState, ctx: &mut TxContext) {

        // try to fulfill promises with StakedSui
        suidouble_liquid_promised_pool::try_to_fill_with_perfect_staked_sui(&mut liquid_store.promised_pool, &mut liquid_store.staked_pool, state, ctx);

        let still_waiting_for_sui_amount = still_waiting_for_sui_amount(liquid_store);

        if (still_waiting_for_sui_amount > 0) {
            send_pending_to_promised(liquid_store, ctx);
            still_waiting_for_sui_amount = still_waiting_for_sui_amount(liquid_store);

            // let try_to_unstake_amount = promised_amount(liquid_store);
            if (still_waiting_for_sui_amount > 0) {

                let unstaked_balance = suidouble_liquid_staker::unstake_sui(&mut liquid_store.staked_pool, still_waiting_for_sui_amount, state, ctx);
                let unstaked_balance_amount = balance::value(&unstaked_balance);

                if (unstaked_balance_amount <= still_waiting_for_sui_amount) {
                    // just add it to promised balance
                    suidouble_liquid_promised_pool::fulfill_with_sui(&mut liquid_store.promised_pool, unstaked_balance);

                } else {
                    // split it to promised and pending
                    let to_promised = balance::split(&mut unstaked_balance, still_waiting_for_sui_amount);
                    suidouble_liquid_promised_pool::fulfill_with_sui(&mut liquid_store.promised_pool, to_promised);

                    balance::join(&mut liquid_store.pending_pool, unstaked_balance);
                };

                // still need something?
                send_pending_to_promised(liquid_store, ctx);
            };

        };
    }

}
