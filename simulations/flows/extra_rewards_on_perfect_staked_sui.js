

let liquidStoreWithdrawPromiseIds = [];

module.exports = async(ld, curStep) => {
    if (!curStep) {
        // do nothing on the first step, so we can see the state of fresh system in stats
        // very first epoch run
        liquidStoreWithdrawPromiseIds = [];
        await ld.once_per_epoch();
    } else {
        if (curStep == 1) {
            // start with a single deposit of 100 SUI
            await ld.deposit({amount: '100.0'});

            return;
        }

        if (curStep >= 20) {
            if (curStep == 20) {
                let promiseId = await ld.withdraw({amount: '100%'});
                liquidStoreWithdrawPromiseIds.push({
                    promiseId: promiseId,
                    step: curStep,
                });
            }
        } else {
            // Add 1 SUI each step and withdraw 1% of your pool tokens
            await ld.deposit({amount: '1.0'});
            
            let promiseId = await ld.withdraw({amount: '10%'});
            liquidStoreWithdrawPromiseIds.push({
                promiseId: promiseId,
                step: curStep,
            });
        }

        // pick the promise to be fulfilled
        const fulfillPromiseAfterNEpochs = 5;
        const promise = liquidStoreWithdrawPromiseIds.find((item)=>{ return (item.step === (curStep - fulfillPromiseAfterNEpochs)); });

        if (promise) {
            await ld.fulfill(promise.promiseId);
        }
    }
};