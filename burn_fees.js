const { SuiMaster } = require('suidouble');
const LiquidDouble = require('./LiquidDouble.js');

const config = require('./config.js');

const run = async()=>{
    const burn_amount = '3.0';

    const phrase = config.phrase;
    const chain = config.chain;
    const packageId = config.packageId;
    const firstVPackageId = config.firstVPackageId || packageId;
    const adminCapId = config.adminCapId;
    const liquidStoreId = config.liquidStoreId;

    const coin_type = ''+firstVPackageId+'::suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN';
    const state = '0x0000000000000000000000000000000000000005';

    const suiMaster = new SuiMaster({provider: chain, phrase: phrase, debug: true});
    await suiMaster.initialize();
    await suiMaster.requestSuiFromFaucet();

    const addedPackage = suiMaster.addPackage({
        id: packageId,
    });

    try {
        const success = await addedPackage.moveCall('suidouble_liquid', 'burn_and_get_nothing', [liquidStoreId, {amount: burn_amount, type: coin_type}, state]);
        if (success && success.status == 'success') {
            console.log('burn_and_get_nothing function successfull');
        }
    } catch (e) {
        console.error(e);
    }
};

run();

