const { SuiMaster } = require('suidouble');
const LiquidDouble = require('./LiquidDouble.js');
const path = require('path');
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
        path: path.join(__dirname, 'move/'),
    });

    console.log(suiMaster.address); 

    await addedPackage.upgrade();




    // const ld = new LiquidDouble({
    //     suiMaster: suiMaster,
    //     packageId: packageId,
    // });
    // await ld.initialize();

    // await ld._suiMaster.upgrae

    console.log('should be upgraded');
    console.log('upgraded packageId', addedPackage.address);
    console.log('do not forget to update in package config')
    // console.log('liquidStoreId', ld._liquidStoreId);

    try {
        const success = await addedPackage.moveCall('suidouble_liquid', 'migrate', [liquidStoreId, adminCapId]);
        if (success && success.status == 'success') {
            console.log('migrate function successfull');
        }
    } catch (e) {
        console.error(e);
    }
};

run();