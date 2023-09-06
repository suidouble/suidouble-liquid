class Strategy {
    constructor(params = {}) {
        this.transactions = [];
        this.liquidStoreWithdrawPromiseIds = [];

        this.ld = params.ld;
    }

    async step(curStep) {    
        const suiTransaction1 = await this.ld.deposit({amount: '9.99'});
        this.transactions.push(suiTransaction1);   
    }

    async end() {
    }
};

module.exports = Strategy;