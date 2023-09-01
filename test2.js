const LiquidDouble = require('./LiquidDouble.js');
const { SuiLocalTestValidator } = require('suidouble');
const fs = require('fs');

const strategies = {
    strategy0: async(ld, curStep)=>{
        if (!curStep) {
            await ld.deposit({amount: '1.0'});
        } else {
            await ld.once_per_epoch();
        }
    },
    strategy1: async(ld, curStep)=>{
        if (curStep) {
            await ld.deposit({amount: '100.0'});
        }

        await ld.deposit({amount: '1.0'});
        await ld.withdraw({amount: '50%'});
        await ld.fulfill();
    },
};

const run = async()=>{
    const epochDuration = 5000;
    const strategyId = 1;
    const waitTillEpoch = 3;// 5; // do not trade on first N epoch, as we can start on different one
    const simulateNEpochs = 100;

    await SuiLocalTestValidator.launch({
        debug: true,
        epochDuration: epochDuration,
    });

    const ld = new LiquidDouble({
        packageId: '',
        debug: true,
    });
    await ld.initialize();
    // await ld.getCurrentEpoch();
    // const ldGuest = new LiquidDouble({
    //     packageId: '0x6b23ab08250e605174149f44c15030b11f7285e6c17078d1b845234f9a48c08c',
    //     liquidStoreId: '0x19deedb0e11267c254dd7be2bfe08b7c656d10390318eb059321f30de59ecea7',
    //     as: 'somebody',
    // });
    // await ldGuest.initialize();

    await ld.requestSuiFromFaucet();
    await ld.requestSuiFromFaucet();
    await ld.requestSuiFromFaucet();

    await ld.waitForEpoch(waitTillEpoch);

    for (let i = 0; i < simulateNEpochs; i++) {
        await strategies['strategy'+strategyId](ld, i);
        // await ld.deposit({amount: '1.0'});
        // await ld.withdraw({amount: '50%'});
        const stats = await ld.getCurrentStatsAndWaitForTheNextEpoch();
        console.log(stats);
    }

    const csv = ld.getCachedEpochStats(true);
    const filename = './simulations/'+ ((new Date()).getTime()) + '_strategy_'+strategyId+'.csv';
    fs.writeFileSync(filename, csv);

    // await ld.deposit();
    // await ld.withdraw();
    // await ld.fulfill();
    // await ld.getCurrentStats();

    // const currentPromises = await ld.getCurrentWithdrawPromises();
    // console.log('promises: ', currentPromises.length);

    // for (let promise of currentPromises) {
    //     console.log(promise.fields);
    // }
    // await ld.getCurrentTokenBalance();
    // await ld.getCurrentPrice();
    // await ld.getCurrentRate();
    // await ld.withdraw();
    // await ld.deposit();
    // await ldGuest.deposit();

    // await ldGuest.once_per_epoch();
    // await ld.calc_expected_profits();

    // await ld.getCurrentRate();
    await SuiLocalTestValidator.stop();
};

run();