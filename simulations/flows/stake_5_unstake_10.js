class Strategy {
    constructor(params = {}) {
        this.transactions = [];
        this.liquidStoreWithdrawPromiseIds = [];

        this.ld = params.ld;
    }

    async step(curStep) {    
        if (!curStep) {
            // do nothing on the first step, so we can see the state of fresh system in stats
            // very first epoch run
            this.liquidStoreWithdrawPromiseIds = [];
            this.transactions = [];

            await this.ld.once_per_epoch();
        } else {
            // start with a single deposit
            const suiTransaction1 = await this.ld.deposit({amount: '5.0'});
            this.transactions.push(suiTransaction1);            

            const suiTransaction2 = await this.ld.withdraw({amount: '10%'});
            this.transactions.push(suiTransaction2);  

            if (suiTransaction2.promiseId) { // just an extra field we've added to SuiTransaction
                this.liquidStoreWithdrawPromiseIds.push({
                    promiseId: suiTransaction2.promiseId,
                    step: curStep,
                });
            }

            // pick the promise to be fulfilled
            const fulfillPromiseAfterNEpochs = 5;
            const promise = this.liquidStoreWithdrawPromiseIds.find((item)=>{ return (item.step === (curStep - fulfillPromiseAfterNEpochs)); });

            if (promise) {
                const suiTransaction3 = await this.ld.fulfill(promise.promiseId);
                this.transactions.push(suiTransaction3);  
            }

        }
    }
};

module.exports = Strategy;