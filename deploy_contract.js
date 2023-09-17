const { SuiMaster } = require('suidouble');
const LiquidDouble = require('./LiquidDouble.js');
const config = require('./config.js');

const run = async()=>{
    const phrase = config.phrase;
    const chain = config.chain;

    const suiMaster = new SuiMaster({provider: chain, phrase: phrase, debug: true});
    await suiMaster.initialize();
    await suiMaster.requestSuiFromFaucet();

    const ld = new LiquidDouble({
        suiMaster: suiMaster,
        packageId: '',
    });
    await ld.initialize();

    // find admincap id

    const adminCap = suiMaster.objectStorage.findMostRecentByTypeName('AdminCap');
    await adminCap.fetchFields(); // update fields to most recent

    const liquidStats = suiMaster.objectStorage.findMostRecentByTypeName('SuidoubleLiquidStats');
    await liquidStats.fetchFields(); // update fields to most recent

    console.log('should be deployed');

    console.log('packageId', ld._packageId);
    console.log('liquidStoreId', ld._liquidStoreId);
    console.log('adminCapId', adminCap.id);
    console.log('liquidStatsId', liquidStats.id);
};

run();