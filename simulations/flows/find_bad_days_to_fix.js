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
            const suiTransaction = await this.ld.deposit({amount: '0.99'});
            this.transactions.push(suiTransaction);
        } else {
            if (curStep == 1) {
                // start with a single deposit
                const suiTransaction = await this.ld.deposit({amount: '0.99'});
                this.transactions.push(suiTransaction);            

                return;
            }
            if (curStep == 2) {
                await this.ld.once_per_epoch();
            }
            if (curStep == 3) {
                const suiTransaction = await this.ld.withdraw({amount: '0.99'});

                if (suiTransaction.promiseId) { // just an extra field we've added to SuiTransaction
                    this.liquidStoreWithdrawPromiseIds.push({
                        promiseId: suiTransaction.promiseId,
                        step: curStep,
                    });
                }
                this.transactions.push(suiTransaction);
            }
            if (curStep == 4) {
                const suiTransaction = await this.ld.deposit({amount: '0.2'});
                this.transactions.push(suiTransaction);
            }
            if (curStep == 5) {
                const suiTransaction = await this.ld.deposit({amount: '0.2'});
                this.transactions.push(suiTransaction);
            }
            if (curStep == 6) {
                const promise = this.liquidStoreWithdrawPromiseIds[0];
                const suiTransaction = await this.ld.fulfill(promise.promiseId);
                this.transactions.push(suiTransaction);            

                console.log('withdraw success', !!suiTransaction);
            }
        }
    }
};

module.exports = Strategy;