const LiquidDouble = require('./LiquidDouble.js');
const { SuiLocalTestValidator } = require('suidouble');

const strategies = {
    strategyFindBadDays: require('./simulations/flows/find_bad_days_to_fix.js'),
    strategyStake5Unstake10: require('./simulations/flows/stake_5_unstake_10.js'),
    strategyStake5PlusUnstake10: require('./simulations/flows/stake_5plus_unstake_10.js'),
    strategyJustAddSome: require('./simulations/flows/just_add_some.js'),
    strategyAddOnStartAndWithdraw1p: require('./simulations/flows/add_on_start_and_withdraw_each_two_days.js'),
    strategyJustAddSomeAndWithdrawFast: require('./simulations/flows/just_add_some_and_withdraw_fast.js'),
    strategyJustAddOnStart: require('./simulations/flows/just_add_on_start.js'),
    strategyAddALittleEachEpoch: require('./simulations/flows/add_a_little_each_epoch.js'),
};

const run = async()=>{
    const epochDuration = 10000;
    const waitTillEpoch = 3;
    const strategyId = 'Stake5PlusUnstake10';
    const simulateNEpochs = 20;

    await SuiLocalTestValidator.launch({
        debug: false,
        epochDuration: epochDuration,
    });

    const ld = new LiquidDouble({
        packageId: '',
        debug: true,
    });
    await ld.initialize();
    await ld.requestSuiFromFaucet();

    await ld.waitForEpoch(waitTillEpoch);

    const strategy = new (strategies['strategy'+strategyId])({
        ld: ld,
    });

    let nextEpoch = 0;
    for (let i = 0; i < simulateNEpochs; i++) {
        await strategy.step(i, nextEpoch);
        const stats = await ld.getCurrentStatsAndWaitForTheNextEpoch({}, true);
        nextEpoch = stats.waitedForEpoch;
        console.log(stats);
    }

    await ld.once_per_epoch();
    await ld.getCurrentStatsAndWaitForTheNextEpoch();
    await ld.once_per_epoch();
    await ld.getCurrentStatsAndWaitForTheNextEpoch();

    if (strategy.end) {
        await strategy.end();
    }

    const stats = await ld.getCurrentStatsAndWaitForTheNextEpoch({}, true);

    console.log(stats);
};

run();