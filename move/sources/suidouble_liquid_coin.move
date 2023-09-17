
module suidouble_liquid::suidouble_liquid_coin {
    friend suidouble_liquid::suidouble_liquid;
    friend suidouble_liquid::suidouble_liquid_staker;

    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    // /// The type identifier of coin. The coin will have a type
    // /// tag of kind: `Coin<package_object::mycoin::iSUI>`
    // /// Make sure that the name of the type matches the module's name.
    struct SUIDOUBLE_LIQUID_COIN has drop {}

    // /// Module initializer is called once on module publish. A treasury
    // /// cap is sent to the publisher, publisher will send it to the Liquid Pool on the next step
    // /// and it's ready
    fun init(witness: SUIDOUBLE_LIQUID_COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"iSUI", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public(friend) fun mint(treasury: &mut coin::TreasuryCap<SUIDOUBLE_LIQUID_COIN>, amount: u64, ctx: &mut TxContext) {
        let coin = coin::mint(treasury, amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    public(friend) fun mint_and_return(treasury: &mut coin::TreasuryCap<SUIDOUBLE_LIQUID_COIN>, amount: u64, ctx: &mut TxContext): coin::Coin<SUIDOUBLE_LIQUID_COIN> {
        coin::mint(treasury, amount, ctx)
    }

    public(friend) fun burn(treasury: &mut coin::TreasuryCap<SUIDOUBLE_LIQUID_COIN>, coin: coin::Coin<SUIDOUBLE_LIQUID_COIN>) {
        coin::burn(treasury, coin);
    }
}