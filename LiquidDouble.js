const { SuiMaster, TransactionBlock, MIST_PER_SUI } = require('suidouble');
const path = require('path');
const { stat } = require('fs');

class LiquidDouble {
    constructor(params = {}) {
        this._packageId = params.packageId || null;
        this._liquidStoreId = params.liquidStoreId || null;
        this._as = params.as || 'admin';

        this._suiMaster = null;
        this._mod = null;

        this._isInitialized = false;

        this._debug = !!params.debug;
        this._epochStats = {};
    }

    get packageId() {
        return this._packageId;
    }

    get coinType() {
        return ''+this._packageId+'::suidouble_liquid_coin::SUIDOUBLE_LIQUID_COIN';
    }

	log(...args) {
		if (!this._debug) {
			return;
		}

		let prefix = (this._suiMaster ? (''+this._suiMaster.instanceN+' |') : (this.instanceN ? ''+this.instanceN+' |' : '') );

		args.unshift(this.constructor.name+' |');
		args.unshift(prefix);
		console.info.apply(null, args);
	}

    async initialize() {
        if (this._isInitialized) {
            return true;
        }

        const suiMaster = new SuiMaster({provider: 'local', as: this._as, debug: this._debug});
        await suiMaster.initialize();
        await suiMaster.requestSuiFromFaucet();

        this._suiMaster = suiMaster;
        // suiMaster.requestSuiFromFaucet();

        const addedPackage = suiMaster.addPackage({
            id: this._packageId,
            path: path.join(__dirname, 'move/'),
        });

        let liquidStore = null;
        let hasToAttachTreasury = false;

        if (!this._packageId) {
            await addedPackage.publish();
            liquidStore = await suiMaster.objectStorage.findMostRecentByTypeName('LiquidStore');

            this._liquidStoreId = liquidStore.id;
            this._packageId = addedPackage._id;

            hasToAttachTreasury = true;
        }

        const mod = await addedPackage.getModule('suidouble_liquid');
        this._mod = mod;

        if (!this._liquidStoreId) {
            await this.findLiquidStore();
        }

        mod.pushObject(this._liquidStoreId); // LiquidStore created on publish
        await suiMaster.objectStorage.fetchObjects();
        liquidStore = await suiMaster.objectStorage.findMostRecentByTypeName('LiquidStore');

        if (!liquidStore) {
            throw new Error('can not initialize, can not find LiquidStore object');
        }

        if (hasToAttachTreasury) {
            await this.attachTreasury();
        }

        this._isInitialized = true;
    }

    async requestSuiFromFaucet() {
        await this._suiMaster.requestSuiFromFaucet();
    }

    /**
     * Find LiquidStore id from events emited on contract creation
     * @returns id
     */
    async findLiquidStore() {
        this.log('looking for NewLiquidStoreEvent...');

        const eventsResponse = await this._mod.fetchEvents({eventTypeName: 'NewLiquidStoreEvent', order: 'descending'});
        if (eventsResponse && eventsResponse.data && eventsResponse.data[0]) {
            const suiEvent = eventsResponse.data[0];
            this._liquidStoreId = suiEvent.parsedJson.id;

            this.log('found. liquidStoreId is ', this._liquidStoreId);

            return this._liquidStoreId;
        }

        this.log('no NewLiquidStoreEvent found');

        return null;
    }

    /**
     * Attach a TreasuryCap to LiquidStore so contract becomes functional
     * @returns Boolean
     */
    async attachTreasury() {
        this.log('attaching TreasuryCap into the pool....');
        const treasury = await this._suiMaster.objectStorage.findMostRecentByTypeName('TreasuryCap');

        this.log('TreasuryCap found', treasury);

        const res = await this._mod.moveCall('attach_treasury', [this._liquidStoreId, treasury.id, {type: 'SUI', amount: '10.0'}]);
        if (res && res.status && res.status == 'success') {
            this.log('TreasuryCap attached.');
            return true;
        }
    }

    /**
     * Get the current epoch from blockchain
     * @returns BigInt
     */
    async getCurrentEpoch() {
        // @todo: check why .getCurrentEpoch() doesn't work
        const suiSystemStateInfo = await this._suiMaster.provider.getLatestSuiSystemState();
        return BigInt(suiSystemStateInfo.epoch);
        // console.log('epochInfo', BigInt(suiSystemStateInfo.epoch));
    }

    /**
     * Get the current getCurrentValidators from blockchain
     * @returns BigInt
     */
    async getCurrentValidators() {
        // @todo: check why .getCurrentEpoch() doesn't work
        const suiSystemStateInfo = await this._suiMaster.provider.getLatestSuiSystemState();
        return suiSystemStateInfo.activeValidators;
        // console.log('epochInfo', BigInt(suiSystemStateInfo.epoch));
    }

    async deposit(params = {}) {
        let amount = params.amount || null;

        if (!amount) {
            amount = '10.0';
        }

        if (amount.indexOf && amount.indexOf('%') !== -1) {
            let currentBalance = await this.getCurrentSUIBalance();
            amount = parseFloat(amount, 10);
            let gonna = amount * (Number(currentBalance) / 100);
            amount = BigInt(Math.floor(gonna));
        }

        const res = await this._mod.moveCall('deposit', [this._liquidStoreId, {type: 'SUI', amount: amount}, '0x0000000000000000000000000000000000000005']);
        if (res && res.status && res.status == 'success') {
            res.ldAmountSend = amount;
            res.ldType = 'deposit';
            res.ldTime = new Date();

            let amountReceived = 0;
            for (const suiObject of res.created) {
                if (suiObject.typeName == 'Coin') {
                    amountReceived = suiObject.fields.balance;
                }
            }

            res.ldAmountReceived = amountReceived;

            return res;
        }

        return false;
    }

    async withdraw(params = {}) {
        let amount = params.amount || null;

        if (!amount) {
            amount = '10%';
        }

        if (amount.indexOf && amount.indexOf('%') !== -1) {
            let currentBalance = await this.getCurrentTokenBalance();
            amount = parseFloat(amount, 10);
            let gonnaWithdraw = amount * (Number(currentBalance) / 100);
            amount = BigInt(Math.floor(gonnaWithdraw));
        }

        this.log('going to withdraw', amount);

        const moveParams = [
            this._liquidStoreId,
            {type: this.coinType, amount: amount},
            '0x0000000000000000000000000000000000000005'
        ];

        const res = await this._mod.moveCall('withdraw', moveParams);
        if (res && res.status && res.status == 'success') {
            // lets return the promise id
            this.log('got a promise');
            const liquidStoreWithdrawPromise = await this._suiMaster.objectStorage.findMostRecentByTypeName('LiquidStoreWithdrawPromise');
            if (liquidStoreWithdrawPromise) {
                this.log('got a promise', liquidStoreWithdrawPromise.fields, liquidStoreWithdrawPromise.id);

                res.ldAmountSend = amount;
                res.ldType = 'withdraw';
                res.ldTime = new Date();
                res.promiseId = liquidStoreWithdrawPromise.id;
                res.fulfilled_at_epoch = liquidStoreWithdrawPromise.fields.fulfilled_at_epoch;
                res.ldAmountReceived = liquidStoreWithdrawPromise.fields.sui_amount;

                return res;
            }


            return res;
        }


        return false;
    }

    /**
     * Tries to fulfill the oldest liquid pool promise current account has
     * @returns Boolean true on success, false if there's no ready promises
     */
    async fulfill(promiseId = null, tryN = 0) {
        let promiseIdToUse = promiseId;

        if (!promiseIdToUse) {
            this.log('going to fulfill some promise');
            const currentPromises = await this.getCurrentWithdrawPromises();
            let min_epoch = Infinity;
            let min_epoch_promise = null;
    
            currentPromises.forEach((promise)=>{
                const epoch = BigInt(promise.fields.fulfilled_at_epoch);
                if (epoch < min_epoch) {
                    min_epoch = epoch;
                    min_epoch_promise = promise;
                }
            });
    
            if (!min_epoch_promise) {
                this.log('there is no promises to fulfill');
                return false; // nothing to fulfil
            }

            promiseIdToUse = min_epoch_promise.id;
        }

        this.log('going to fulfill promise', promiseIdToUse);

        try {
            const res = await this._mod.moveCall('fulfill', [this._liquidStoreId, promiseIdToUse, '0x0000000000000000000000000000000000000005']);
            if (res && res.status && res.status == 'success') {
                this.log('promise fulfilled', promiseIdToUse);

                res.promiseId = promiseIdToUse;
                res.ldType = 'fulfill';
                res.ldTime = new Date();

                let amountReceived = 0;
                for (const suiObject of res.created) {
                    if (suiObject.typeName == 'Coin') {
                        amountReceived = suiObject.fields.balance;
                    }
                }
    
                res.ldAmountReceived = amountReceived;

                return res;
            } else {
                // may get InsufficientGas as of wrong calculation. @todo: why?
                if (tryN < 3) {
                    return await this.fulfill(promiseIdToUse, tryN+1);
                } else {
                    console.log(res);
                    console.log(res._data);
                    console.log('promiseIdToUse', promiseIdToUse);
    
                    // await new Promise((res)=>setTimeout(res, 100000000));
                    throw new Error('can not withdraw');
                }
            }
        } catch (e) {
            console.error(e);
        }

        this.log('promise NOT fulfilled', promiseIdToUse);

        return false;

    }

    async once_per_epoch() {
        const txb = new TransactionBlock();
        // const ss = txb.moveCall({ target: `0x2::object::sui_system_state`, arguments: [] });
        txb.moveCall({ target: ''+this._packageId+'::suidouble_liquid::once_per_epoch_if_needed', arguments:[
            txb.pure(this._liquidStoreId),
            txb.object('0x0000000000000000000000000000000000000005'), // SUI_SYSTEM_STATE_OBJECT_ID
        ]});
        const res = await this._mod.moveCall('once_per_epoch_if_needed', {tx: txb});
        if (res && res.status && res.status == 'success') {
            return true;
        }

        return false;
    }

    async calc_expected_profits() {
        const txb = new TransactionBlock();
        txb.moveCall({ target: ''+this._packageId+'::suidouble_liquid::calc_expected_profits', arguments:[
            txb.pure(this._liquidStoreId),
            txb.object('0x0000000000000000000000000000000000000005'), // SUI_SYSTEM_STATE_OBJECT_ID
        ]});

        const res = await this._mod.moveCall('calc_expected_profits', {tx: txb});
        if (res && res.status && res.status == 'success') {
            return true;
        }

        return false;
    }

    /**
     * Get amount of tokens currenty stored under connected wallet
     */
    async getCurrentSUIBalance() {
        const balance = await this._suiMaster.getBalance('sui');

        this.log('current wallet balance of SUI is: ', balance);

        return balance;
    }

    /**
     * Format amount BigInt to readable string representation
     * @param {BigInt} amount 
     * @returns 
     */
    async amountToString(amount) {
        // as decimals are same for SUI and pool token:
        const suiCoin = this._suiMaster.suiCoins.get('sui');
        return suiCoin.amountToString(amount);
    }

    /**
     * Get amount of tokens currenty stored under connected wallet
     */
    async getCurrentTokenBalance() {
        const balance = await this._suiMaster.getBalance(this.coinType);

        this.log('current wallet balance of tokens is: ', balance);

        return balance;
    }

    /**
     * Get LiquidStoreWithdrawPromise objects owned by connected wallet
     */
    async getCurrentWithdrawPromises() {
        const ret = [];
        const paginatedResponse = await this._mod.getOwnedObjects({ typeName: 'LiquidStoreWithdrawPromise' });
        await paginatedResponse.forEach((suiObject)=>{
            ret.push(suiObject);
        });

        return ret;
    }

    async getCurrentStatsAndWaitForTheNextEpoch(extraStatsObject = {}) {
        const currentEpoch = await this.getCurrentEpoch();
        await new Promise((res)=>setTimeout(res, 500));

        const stats = await this.getCurrentStats(extraStatsObject);
        const waitingForEpoch = currentEpoch + BigInt(1);

        await this.waitForEpoch(waitingForEpoch);

        stats.waitedForEpoch = waitingForEpoch;

        // this.log('waiting for epoch', waitingForEpoch);
        // let isItNextEpoch = false;
        // do {
        //     await new Promise((res)=>setTimeout(res, 1000));
        //     const epochNow = await this.getCurrentEpoch();

        //     if (epochNow >= waitingForEpoch) {
        //         isItNextEpoch = true;
        //         this.log('ok, epoch now is', epochNow);
        //     }
        // } while (!isItNextEpoch);

        return stats;
    }

    async waitForEpoch(waitingForEpoch) {
        waitingForEpoch = BigInt(waitingForEpoch);

        this.log('waiting for epoch', waitingForEpoch);
        let isItNextEpoch = false;
        do {
            await new Promise((res)=>setTimeout(res, 1000));
            const epochNow = await this.getCurrentEpoch();

            if (epochNow >= waitingForEpoch) {
                isItNextEpoch = true;
                this.log('ok, epoch now is', epochNow);
            }
        } while (!isItNextEpoch);

        return true;
    }

    /**
     * Get current statistics of the pool
     */
    async getCurrentStats(extraStatsObject = {}) {
        const ret = {
            immutable_pool_sui: 0,
            immutable_pool_tokens: 0,
            price_of_last_transaction: 1,
            staked_sui_count: 0,
            staked_sui_activated_count: 0,
            staked_sui_pools_count: 0,
            token_total_supply: BigInt(0),
            pending_amount: BigInt(0),                     // pending SUI, not-staked yet
            staked_amount: BigInt(0),              // staked as StakedSui, not counting rewards
            staked_staked_suis: [],
            staked_with_rewards_balance: BigInt(0), // calculated once per epoch amount of Sui in StakedSui + Rewards
            all_time_promised_amount: BigInt(0),    // all time amount of SUI asked to take out of pool
            promised_amount: BigInt(0),             // promised as withdraw, but not un-staked yet, not ready for pay-out
            promised_fulfilled: BigInt(0),                    // fulfiled promises balance, ready for pay-out

            promised_amount_in_staked: BigInt(0),
            extra_staked_in_promised: BigInt(0),
            all_time_extra_amount: BigInt(0),

            still_waiting_for_sui_amount: BigInt(0),
        };

        ret.price_of_last_transaction = await this.getCurrentPrice();

        const liquidStore = this._suiMaster.objectStorage.findMostRecentByTypeName('LiquidStore');
        await liquidStore.fetchFields(); // update fields to most recent



        ret.extra_staked_in_promised = BigInt(liquidStore.fields.promised_pool.fields.got_extra_staked);
        ret.all_time_extra_amount = BigInt(liquidStore.fields.promised_pool.fields.all_time_extra_amount);
        ret.still_waiting_for_sui_amount = BigInt(liquidStore.fields.promised_pool.fields.still_waiting_for_sui_amount);

        ret.immutable_pool_sui = BigInt(liquidStore.fields.immutable_pool_sui);
        ret.immutable_pool_tokens = BigInt(liquidStore.fields.immutable_pool_tokens);

        console.log(liquidStore.fields.promised_pool);

        ret.token_total_supply = BigInt(liquidStore.fields.treasury.fields.total_supply.fields.value);

        ret.pending_amount = BigInt(liquidStore.fields.pending_pool);

        ret.staked_amount = BigInt(liquidStore.fields.staked_pool.fields.staked_amount);

        ret.promised_amount = BigInt(liquidStore.fields.promised_pool.fields.promised_amount);
        ret.all_time_promised_amount = BigInt(liquidStore.fields.promised_pool.fields.all_time_promised_amount);
        ret.promised_fulfilled = BigInt(liquidStore.fields.promised_pool.fields.promised_sui);
        ret.promised_amount_in_staked = BigInt(liquidStore.fields.promised_pool.fields.promised_amount_in_staked);

        ret.staked_with_rewards_balance = BigInt(liquidStore.fields.staked_with_rewards_balance);

        if (ret.token_total_supply) {
            ret.price_calculated = Number(ret.immutable_pool_sui + ret.pending_amount + ret.staked_with_rewards_balance - ret.promised_amount) / Number(ret.token_total_supply);
        } else {
            ret.price_calculated = Number(1);
        }

        ret.epoch = BigInt(liquidStore.fields.liquid_store_epoch);

        if (liquidStore.fields.staked_pool.fields.staked_pool.length) {
            const pool_ids = [];
            liquidStore.fields.staked_pool.fields.staked_pool.forEach((item)=>{
                ret.staked_sui_count++;

                const pool_id = item.fields.pool_id;
                const stake_activation_epoch = BigInt(item.fields.stake_activation_epoch);

                if (pool_ids.indexOf(pool_id) === -1) {
                    pool_ids.push(pool_id);
                }

                if (stake_activation_epoch <= ret.epoch) {
                    ret.staked_sui_activated_count++;
                }

                ret.staked_sui_pools_count = pool_ids.length;
            });
        }
        if (liquidStore.fields.staked_pool.fields.staked_pool.length) {
            for (const item of liquidStore.fields.staked_pool.fields.staked_pool) {
                ret.staked_staked_suis.push({
                    pool_id: item.fields.pool_id,
                    principal: item.fields.principal,
                    stake_activation_epoch: item.fields.stake_activation_epoch,
                });
            }
        }

        ret.token_total_supply = await this.amountToString(ret.token_total_supply);
        ret.pending_amount = await this.amountToString(ret.pending_amount);
        ret.staked_amount = await this.amountToString(ret.staked_amount);
        ret.staked_with_rewards_balance = await this.amountToString(ret.staked_with_rewards_balance);
        ret.promised_amount = await this.amountToString(ret.promised_amount);
        ret.all_time_promised_amount = await this.amountToString(ret.all_time_promised_amount);
        ret.promised_fulfilled = await this.amountToString(ret.promised_fulfilled);

        ret.extra_staked_in_promised = await this.amountToString(ret.extra_staked_in_promised);
        ret.all_time_extra_amount = await this.amountToString(ret.all_time_extra_amount);

        ret.promised_amount_in_staked = await this.amountToString(ret.promised_amount_in_staked);

        // ret.user_balance_sui = await this.getCurrentSUIBalance();
        // ret.user_balance_sui = await this.amountToString(ret.user_balance_sui);

        // ret.user_balance_tokens = await this.getCurrentTokenBalance();
        // ret.user_balance_tokens = await this.amountToString(ret.user_balance_tokens);

        ret.still_waiting_for_sui_amount = await this.amountToString(ret.still_waiting_for_sui_amount);

        Object.assign(ret, extraStatsObject);

        this._epochStats[ret.epoch] = ret;

        return ret;
    }

    /**
     * Get most recent price from PriceEvent emited on deposit or withdraw. Returns an amount of SUI you expect to get from 1 TOKEN
     * Note that price is subject for fluctation and will be little different on the next contract method call
     */
    async getCurrentPrice() {
        const eventsResponse = await this._mod.fetchEvents({eventTypeName: 'PriceEvent', order: 'descending'});
        if (eventsResponse && eventsResponse.data && eventsResponse.data[0]) {
            const suiEvent = eventsResponse.data[0];
            const price = BigInt(suiEvent.parsedJson.price);
            const price_reverse = BigInt(suiEvent.parsedJson.price_reverse);

            const k = BigInt(MIST_PER_SUI);
            let ret = 1; //
            if (price_reverse) {
                // the amount of tokens you get for 1 SUI
                ret = Number(k) / Number(price_reverse);
            } else {
                // the amount of sui you get for 1 token
                ret =  Number(price) / Number(k);
            }

            // console.log('price', price, price_reverse, ret);

            return ret;
        }

        return 1;
    }

    async fetchStatsStakedSuisHistory() {
        let poolIds = {};
        for (const key in this._epochStats) {
            const stats = this._epochStats[key];

            console.log(stats);
            if (stats.staked_staked_suis && stats.staked_staked_suis.length) {
                for (const staked_sui of stats.staked_staked_suis) {
                    if (!poolIds[staked_sui.pool_id]) {
                        poolIds[staked_sui.pool_id] = true;
                    }
                }
            }
        }

        poolIds = Object.keys(poolIds);

        console.log(poolIds);

        // now lets get mappings of validator address -> poolIds
        const poolIdToValidatorAddress = {};
        const validatorAddressToStakingPoolId = {};

        const validators = await this.getCurrentValidators();
        console.log(validators);
        for (const validator of validators) {
            validatorAddressToStakingPoolId[validator.suiAddress] = validator.stakingPoolId;
            poolIdToValidatorAddress[validator.stakingPoolId] = validator.suiAddress;
        }

        console.log('poolIdToValidatorAddress', poolIdToValidatorAddress);
        console.log('validatorAddressToStakingPoolId', validatorAddressToStakingPoolId);

        const poolsExchangeRates = {};

        for (const poolId of poolIds) {
            poolsExchangeRates[poolId] = [];
        }

        const paginatedResponse = await this._suiMaster.fetchEvents({
            query: {"MoveEventType": "0x3::validator_set::ValidatorEpochInfoEventV2"}
        });
        await paginatedResponse.forEach((suiEvent)=>{
            const json = suiEvent.parsedJson;
            const eventPoolId = validatorAddressToStakingPoolId[json.validator_address];
            const exchangeRate = json.pool_token_exchange_rate;
            exchangeRate.epoch = parseInt(json.epoch);
            exchangeRate.commission_rate = json.commission_rate;

            console.log('eventPoolId', eventPoolId);
            console.log('json', json);

            if (poolsExchangeRates[eventPoolId]) {
                poolsExchangeRates[eventPoolId].push(exchangeRate);
            }
        });

        for (const poolId of poolIds) {
            poolsExchangeRates[poolId].sort((a, b) => (a.epoch > b.epoch) ? 1 : -1);
        }

        return poolsExchangeRates;

        // console.log(poolsExchangeRates); adsdas; 



        // now lets fetch events for each validator

    // await ld._suiMaster._provider.subscribeEvent({
    //     filter: {"MoveEventType": "0x3::validator_set::ValidatorEpochInfoEventV2"},
    //     // filter: {"TimeRange":{"startTime": '1669039504014', "endTime": '2669039604014'}},
    //     onMessage: onMessage,
    // });
    }

    isStatsFull() {
        const data = Object.values(this._epochStats).sort((a, b) => (a.epoch > b.epoch) ? 1 : -1);
        if (data.length <= 1) {
            return true;
        }
        for (let i = 1; i < data.length; i++) {
            if (Number(data[i].epoch) != (Number(data[i - 1].epoch) + 1)) {
                return false;
            }
        }

        return true;
    }

    getCachedEpochStats(asCSV = false) {
        if (!asCSV) {
            return Object.values(this._epochStats).sort((a, b) => (a.epoch > b.epoch) ? 1 : -1);
        }

        const objectToCsv = (data)=>{
            const csvRows = [];
            const headers = Object.keys(data[0]);
            csvRows.push(headers.join(','));
         
            for (const row of data) {
                const values = headers.map(header => {
                    const val = row[header]
                    return `"${val}"`;
                });
                csvRows.push(values.join(','));
            }
            return csvRows.join('\n');
        };

        const data = Object.values(this._epochStats).sort((a, b) => (a.epoch > b.epoch) ? 1 : -1);

        return objectToCsv(data);
    }
}

module.exports = LiquidDouble;