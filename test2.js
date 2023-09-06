const LiquidDouble = require('./LiquidDouble.js');
const { SuiLocalTestValidator } = require('suidouble');
const fs = require('fs');
const SuiTransaction = require('suidouble/lib/SuiTransaction.js');

const strategies = {
    strategyFindBadDays: require('./simulations/flows/find_bad_days_to_fix.js'),
    strategyStake5Unstake10: require('./simulations/flows/stake_5_unstake_10.js'),
    strategyStake5PlusUnstake10: require('./simulations/flows/stake_5plus_unstake_10.js'),
    strategyJustAddSome: require('./simulations/flows/just_add_some.js'),
};

const run = async()=>{
    const epochDuration = 15000;
    const strategyId = 'Stake5PlusUnstake10';
    const strategy2Id = 'JustAddSome';
    const strategy3Id = 'JustAddSome';
    const strategy4Id = 'JustAddSome';

    const waitTillEpoch = 5;// 5; // do not trade on first N epoch, as we can start on different one
    const simulateNEpochs = 100;

    await SuiLocalTestValidator.launch({
        debug: false,
        epochDuration: epochDuration,
    });

    const ld = new LiquidDouble({
        packageId: '',
        debug: false,
    });
    await ld.initialize();
    // const validators = await ld.getCurrentValidators();

    // const onMessage = (rawEvent) => {
    //     console.log(rawEvent);
    // };

    // await ld._suiMaster._provider.subscribeEvent({
    //     filter: {"MoveEventType": "0x3::validator_set::ValidatorEpochInfoEventV2"},
    //     // filter: {"TimeRange":{"startTime": '1669039504014', "endTime": '2669039604014'}},
    //     onMessage: onMessage,
    // });

    // const obj = new (ld._suiMaster.SuiObject)({
    //     suiMaster: ld._suiMaster,
    //     debug: true,
    //     id: validators[3].stakingPoolId,
    // });

    // ld._suiMaster.objectStorage.push(obj);
    // await obj.fetchFields();

    // console.log(validators);
    // console.log(obj.fields);
    // console.log(obj.address);
    // console.log(obj._type);

    // await new Promise((res)=>setTimeout(res, 600000));

    const extraUsers = [];
    if (strategy2Id) {
        const ld2 = new LiquidDouble({
            as: 'user2',
            packageId: ld.packageId,
        });
        await ld2.initialize();
        await ld2.requestSuiFromFaucet();
        await ld2.requestSuiFromFaucet();
        await ld2.requestSuiFromFaucet();
        const strategy2 = new (strategies['strategy'+strategy2Id])({
            ld: ld2,
        });

        extraUsers.push(strategy2);
    }
    if (strategy3Id) {
        const ld3 = new LiquidDouble({
            as: 'user3',
            packageId: ld.packageId,
        });
        await ld3.initialize();
        await ld3.requestSuiFromFaucet();
        await ld3.requestSuiFromFaucet();
        await ld3.requestSuiFromFaucet();
        const strategy3 = new (strategies['strategy'+strategy3Id])({
            ld: ld3,
        });

        extraUsers.push(strategy3);
    }
    if (strategy4Id) {
        const ld4 = new LiquidDouble({
            as: 'user4',
            packageId: ld.packageId,
        });
        await ld4.initialize();
        await ld4.requestSuiFromFaucet();
        await ld4.requestSuiFromFaucet();
        await ld4.requestSuiFromFaucet();
        const strategy4 = new (strategies['strategy'+strategy4Id])({
            ld: ld4,
        });

        extraUsers.push(strategy4);
    }


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

    const strategy = new (strategies['strategy'+strategyId])({
        ld: ld,
    });

    let nextEpoch = 0;
    for (let i = 0; i < simulateNEpochs; i++) {
        await strategy.step(i, nextEpoch);

        for (const s of extraUsers) {
            await s.step(i, nextEpoch);
        }

        // await strategies['strategy'+strategyId](ld, i);
        // await ld.deposit({amount: '1.0'});
        // await ld.withdraw({amount: '50%'});
        const stats = await ld.getCurrentStatsAndWaitForTheNextEpoch();

        nextEpoch = stats.waitedForEpoch;
        console.log(stats);
    }

    if (strategy.end) {
        await strategy.end();
    }
    for (const s of extraUsers) {
        if (s.end) {
            await s.end();
        }
    }

    await ld.once_per_epoch();
    await ld.getCurrentStatsAndWaitForTheNextEpoch();
    await ld.once_per_epoch();
    await ld.getCurrentStatsAndWaitForTheNextEpoch();

    await ld.fetchStatsStakedSuisHistory();

    const epochs = ld.getCachedEpochStats();

    const exportObject = {
        title: '',
        description: '',
        time: (new Date()).getTime(),
        epochs: epochs,
        transactions: [],
    };

    const pools = await ld.fetchStatsStakedSuisHistory();
    exportObject.pools = pools;

    // generate file name and description
    let usersCount = 1 + extraUsers.length;
    let name = ''+usersCount+'_user'+(usersCount > 1 ? 's' : '');
    const strategyNames = [strategyId];
    if (strategy2Id) strategyNames.push(strategy2Id);
    if (strategy3Id) strategyNames.push(strategy3Id);
    if (strategy4Id) strategyNames.push(strategy4Id);

    name = name + '(' + strategyNames.join('_') + ')';
    name = name + '_' + simulateNEpochs + 'epochs';

    name = ''+ (Math.floor( (new Date()).getTime()  ) ) + '_' + name; // prepend time for easier sorting

    exportObject.title = name;

    const exportTransactions = [];

    strategy.transactions.forEach((suiTransaction)=>{
        if (suiTransaction.ldTime) {
            exportTransactions.push({
                type: suiTransaction.ldType ? suiTransaction.ldType : '',
                send: suiTransaction.ldAmountSend ? suiTransaction.ldAmountSend : '',
                received: suiTransaction.ldAmountReceived ? suiTransaction.ldAmountReceived : '',
                promiseId: suiTransaction.promiseId ? suiTransaction.promiseId : '',
                epoch: suiTransaction.executedEpoch ? suiTransaction.executedEpoch : '',
                time: suiTransaction.ldTime ? (suiTransaction.ldTime.getTime()) : '',
                user: 1,
            });
        }
    });

    let userN = 2;
    for (const s of extraUsers) {
        s.transactions.forEach((suiTransaction)=>{
            if (suiTransaction.ldTime) {
                exportTransactions.push({
                    type: suiTransaction.ldType ? suiTransaction.ldType : '',
                    send: suiTransaction.ldAmountSend ? suiTransaction.ldAmountSend : '',
                    received: suiTransaction.ldAmountReceived ? suiTransaction.ldAmountReceived : '',
                    promiseId: suiTransaction.promiseId ? suiTransaction.promiseId : '',
                    epoch: suiTransaction.executedEpoch ? suiTransaction.executedEpoch : '',
                    time: suiTransaction.ldTime ? (suiTransaction.ldTime.getTime()) : '',
                    user: userN,
                });
            }
        });

        userN++;
    }

    exportTransactions.sort((a, b) => ((a.time > b.time) ? 1 : -1));
    exportObject.transactions = exportTransactions;

    const filename = './simulations/'+ name+'.json';

    console.log(exportObject);

    const json = JSON.stringify(exportObject, (key, value) => { return (typeof value === "bigint" ? value.toString() : value); }, 2);

    fs.writeFileSync(filename, json);

    if (!ld.isStatsFull()) {
        console.log('WARNING: stats are not full');
    }

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