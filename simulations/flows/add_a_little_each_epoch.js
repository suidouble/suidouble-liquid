class Strategy {
    constructor(params = {}) {
        this.transactions = [];
        this.liquidStoreWithdrawPromiseIds = [];

        this.ld = params.ld;
    }

    async step(curStep) {    
        if (curStep > 0) {
            const suiTransaction1 = await this.ld.deposit({amount: '0.99'});
            this.transactions.push(suiTransaction1);
        }
    }

    async end() {
    }
};

module.exports = Strategy;