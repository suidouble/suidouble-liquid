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
        } else {
            await this.ld.once_per_epoch();
        }
    }

    async end() {
    }
};

module.exports = Strategy;