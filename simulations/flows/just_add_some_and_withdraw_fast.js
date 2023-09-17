class Strategy {
    constructor(params = {}) {
        this.transactions = [];
        this.liquidStoreWithdrawPromiseIds = [];

        this.ld = params.ld;
    }

    async step(curStep) {    
        if (curStep > 5) {
            const suiTransaction2 = await this.ld.withdraw_fast({amount: '10%'});
            this.transactions.push(suiTransaction2);
        } else {
            const suiTransaction1 = await this.ld.deposit({amount: '9.99'});
            this.transactions.push(suiTransaction1);
        }
    }

    async end() {
    }
};

module.exports = Strategy;