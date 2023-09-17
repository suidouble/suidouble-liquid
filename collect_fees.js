const { SuiMaster } = require('suidouble');
const LiquidDouble = require('./LiquidDouble.js');
const config = require('./config.js');

const run = async()=>{
    const phrase = config.phrase;
    const chain = config.chain;
    const packageId = config.packageId;
    const adminCapId = config.adminCapId;
    const liquidStoreId = config.liquidStoreId;

    const suiMaster = new SuiMaster({provider: chain, phrase: phrase, debug: true});
    await suiMaster.initialize();
    await suiMaster.requestSuiFromFaucet();

    const addedPackage = suiMaster.addPackage({
        id: packageId,
    });

    try {
        const success = await addedPackage.moveCall('suidouble_liquid', 'collect_fees', [liquidStoreId, adminCapId]);
        if (success && success.status == 'success') {
            console.log('collect_fees function successfull');
        }
    } catch (e) {
        console.error(e);
    }
};

run();

