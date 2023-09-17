class Strategy {
    constructor(params = {}) {
        this.transactions = [];
        this.liquidStoreWithdrawPromiseIds = [];

        this.ld = params.ld;
    }

    async step(curStep) {    
        if (curStep == 1) {
            const suiTransaction2 = await this.ld.deposit({amount: '500.0'});
            this.transactions.push(suiTransaction2);
        } else if (curStep > 1) {          
            const suiTransaction2 = await this.ld.withdraw({amount: '1%'});
            this.transactions.push(suiTransaction2);  

            if (suiTransaction2.promiseId) { // just an extra field we've added to SuiTransaction
                this.liquidStoreWithdrawPromiseIds.push({
                    promiseId: suiTransaction2.promiseId,
                    step: curStep,
                });
            }

            // pick the promise to be fulfilled
            const fulfillPromiseAfterNEpochs = 4;
            const promise = this.liquidStoreWithdrawPromiseIds.find((item)=>{ return (item.step === (curStep - fulfillPromiseAfterNEpochs)); });

            if (promise) {
                const suiTransaction3 = await this.ld.fulfill(promise.promiseId);
                this.transactions.push(suiTransaction3);  
            }
        }
    }

    async end() {
    }
};

module.exports = Strategy;