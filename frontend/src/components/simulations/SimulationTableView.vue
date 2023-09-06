<template>

	<div>
        <div v-if="!simulation1" class="q-pa-md text-center	">
            <q-spinner-gears size="50px" color="primary" />
        </div>
        <div v-if="simulation1">
        
        <q-card square flat bordered>
            <q-tabs
                v-model="selectedTab"
                dense
                class="text-grey"
                active-color="primary"
                indicator-color="primary"
                align="justify"
                narrow-indicator
                >
                    <q-tab name="store" label="Store" />
                    <q-tab name="transactions" label="Transactions" />
            </q-tabs>
            <q-separator />

            <q-tab-panels v-model="selectedTab" animated>
                <q-tab-panel name="store">

                        <q-table
                            :rows="epochRows"
                            :columns="epochColumns"
                            row-key="epoch"
                            :rows-per-page-options="[0]"
                            dense
                            flat
                            @row-click="onEpochRowClick"
                            />

                </q-tab-panel>
                <q-tab-panel name="transactions">

                        <q-table
                            :rows="transactionsRows"
                            :columns="transactionsColumns"
                            row-key="time"
                            :rows-per-page-options="[0]"
                            dense
                            flat
                            >
                            <template v-slot:body-cell="props">
                                <q-td :props="props">
                                    <template v-if="props.col.component">
                                        <component v-bind:is="props.col.component" :arr="transactionsRows" :epochs="epochRows" :id="props.key" :row="props.row" :col="props.col" :value="props.value" @cell="cellEvent"></component>
                                    </template>
                                    <template v-else>
                                        {{ props.value }}
                                    </template>
                                </q-td>
                            </template>
                        </q-table>

                </q-tab-panel>
                <q-tab-panel name="debug">



                </q-tab-panel>
            </q-tab-panels>
        </q-card>
        
        </div>

        <q-dialog v-model="showRowPopup" >
            <q-card style="width: 70vw; min-width: 500px;">
                <q-card-section class="row items-center q-pb-none">
                    <div class="text-h7 text-primary">Epoch {{ detailsForRowPopup.epoch }}</div>
                    <q-space />
                    <q-btn icon="close" flat round dense v-close-popup />
                </q-card-section>

                <q-card-section style="max-height: 80vh">

                    <q-tabs
                    v-model="selectedTabInDialog"
                    dense
                    class="text-grey"
                    active-color="primary"
                    indicator-color="primary"
                    align="justify"
                    narrow-indicator
                    >
                        <q-tab name="promised" label="Promised Pool" />
                        <q-tab name="stakedSui" label="StakedSui in Staked Pool" />
                    </q-tabs>

                    <q-separator />

                    <q-tab-panels v-model="selectedTabInDialog" >
                        <q-tab-panel name="stakedSui" class="q-pa-xs">
                            
                            <div class="text-h7 text-primary">StakedSui in StakedPool</div>

                            <div class="text-overline">
                                First one - is the one to be unstaked first. Last - unstaked last.
                            </div>

                            <template v-for="(staked_sui) in detailsForRowPopup.staked_staked_suis" v-bind:key="staked_sui.stake_activation_epoch">
                                amount: {{ staked_sui.principal }} <br />
                                pool rates:  
                                <template v-for="(rate) in staked_sui.rates" v-bind:key="rate.epoch">
                                    <span>{{  rate.k }} ( ep: {{ rate.epoch }}),</span>
                                </template>
                                <br/> diff 5 epochs: {{  staked_sui.diff5epochs }}
                                <br/> diff 7 epochs: {{ staked_sui.diff7epochs }}
                                <br/> activation epoch: {{ staked_sui.stake_activation_epoch }}
                                <q-separator />
                            </template>

                        </q-tab-panel>
                        <q-tab-panel name="promised" class="q-pa-xs">


                            <div class="text-h7 text-primary">Pending Promises ( not ready for pay out)</div>
                            <div v-if="detailsForRowPopup.notFulfilledPromises.length">
                                <span style="display: none">{{ detailsForRowPopup.totalForPayOut = 0 }}</span>

                                <template v-for="(notFulfilledPromise) in detailsForRowPopup.notFulfilledPromises" v-bind:key="notFulfilledPromise.promiseId">
                                    <div v-if="notFulfilledPromise.epoch >= detailsForRowPopup.epoch - 1" style="opacity: 0.6;">
                                        of amount {{  notFulfilledPromise.received }} created at epoch {{ notFulfilledPromise.epoch }}
                                    </div>
                                </template>

                                <br>{{ detailsForRowPopup.totalForPayOut }} - total
                            </div>

                            <div class="text-h7 text-primary q-pt-md">Ready Promises ( ready for pay out)</div>
                            <div v-if="detailsForRowPopup.notFulfilledPromises.length">
                                <span style="display: none">{{ detailsForRowPopup.totalForPayOut = 0 }}</span>
                                <template v-for="(notFulfilledPromise) in detailsForRowPopup.notFulfilledPromises" v-bind:key="notFulfilledPromise.promiseId">
                                    <div v-if="notFulfilledPromise.epoch < detailsForRowPopup.epoch - 1">
                                        of amount {{  notFulfilledPromise.received }} created at epoch {{ notFulfilledPromise.epoch }}
                                        {{ detailsForRowPopup.totalForPayOut = detailsForRowPopup.totalForPayOut + parseInt(notFulfilledPromise.received, 10) }}
                                    </div>
                                </template>

                                <br>{{ detailsForRowPopup.totalForPayOut }} - total
                            </div>

                            <div class="text-h7 text-primary q-pt-md">Promised Pool (waiting)</div>

                            <strong>{{ detailsForRowPopup.row.promised_amount }}</strong> (waiting to be fulfilled on next epochs)<br/>

                            <div class="text-h7 text-primary q-pt-md">Promised Pool (ready)</div>

                            <strong>{{ detailsForRowPopup.row.promised_fulfilled }}</strong> (ready to pay off in SUI) - promised_fulfilled<br/>
                            <strong>{{ detailsForRowPopup.row.promised_amount_in_staked }}</strong> (ready to pay off in StakedSUI)<br/>

                            <div class="q-pt-sm">
                                <strong >{{ detailsForRowPopup.total_ready_for_pay_off }}</strong> (ready to pay off)<br/>

                            </div>


                        </q-tab-panel>
                    </q-tab-panels>




                    
                </q-card-section>
            </q-card>
        </q-dialog>
	</div>

</template>

<script>
import { shallowRef} from 'vue';
import SimulationTableCellState from './cells/SimulationTableCellState.vue';

export default {
	name: 'SimulationTableView',
	props: {
		simulation1: Object
	},
	data() {
		return {
            selectedTab: 'store',
            selectedTabInDialog: 'promised',

            epochRows: [],
            transactionsRows: [],
            transactionsColumns: [
                {
                    name: 'epoch',
                    required: true,
                    label: 'Epoch',
                    align: 'left',
                    field: row => row.epoch,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'type',
                    required: true,
                    label: 'Type',
                    align: 'left',
                    field: row => row.type,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'send',
                    required: true,
                    label: 'Sent',
                    align: 'left',
                    field: row => {
                        if (row.type == 'deposit') {
                            return ''+row.send+' SUI';
                        }
                        if (row.type == 'withdraw') {
                            if (row.send > 1000) {

                                const decimals = 9;
                                const str = (''+row.send).padStart(decimals + 1,'0');
                                const ind = str.length - decimals;
                                return parseFloat( str.substring(0, ind) + '.' + str.substring(ind) , 10) + ' TOKEN';

                            } else {
                                return ''+row.send+' TOKEN';
                            }
                        }

                        return '';
                    },
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'received',
                    required: true,
                    label: 'Received',
                    align: 'left',
                    field: row => {
                        if (row.type == 'deposit') {
                            const decimals = 9;
                            const str = (''+row.received).padStart(decimals + 1,'0');
                            const ind = str.length - decimals;
                            return parseFloat( str.substring(0, ind) + '.' + str.substring(ind) , 10) + ' TOKEN';
                        }
                        if (row.type == 'fulfill') {
                            const decimals = 9;
                            const str = (''+row.received).padStart(decimals + 1,'0');
                            const ind = str.length - decimals;
                            return parseFloat( str.substring(0, ind) + '.' + str.substring(ind) , 10) + ' SUI';
                        }
                        if (row.type == 'withdraw') {
                            const decimals = 9;
                            const str = (''+row.received).padStart(decimals + 1,'0');
                            const ind = str.length - decimals;
                            const am = parseFloat( str.substring(0, ind) + '.' + str.substring(ind) , 10) + ' SUI';

                            return 'promise of '+am;
                        }

                        return '';
                    },
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'state',
                    required: true,
                    label: 'State',
                    align: 'left',
                    component: shallowRef(SimulationTableCellState),
                    field: row => row.epoch,
                    // format: val => `${val}`,
                    sortable: true
                },
            ],
            epochColumns: [
                {
                    name: 'epoch',
                    required: true,
                    label: 'Epoch',
                    align: 'left',
                    field: row => row.epoch,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'token_total_supply',
                    required: true,
                    label: 'Token Supply',
                    align: 'left',
                    field: row => row.token_total_supply,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'price_calculated',
                    required: true,
                    label: 'Calculated Price',
                    align: 'left',
                    field: row => row.price_calculated,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'pending_amount',
                    required: true,
                    label: 'PendingPool',
                    align: 'left',
                    field: row => row.pending_amount,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'staked_amount',
                    required: true,
                    label: 'StakedPool',
                    align: 'left',
                    field: row => row.staked_amount,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'staked_with_rewards_balance',
                    required: true,
                    label: 'StakedPool + Rewards',
                    align: 'left',
                    field: row => row.staked_with_rewards_balance,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'promised_amount',
                    required: true,
                    label: 'Promised (next epochs)',
                    align: 'left',
                    field: row => row.promised_amount,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'promised_amount_in_staked',
                    required: true,
                    label: 'Promised (ready, StakedSui)',
                    align: 'left',
                    field: row => row.promised_amount_in_staked,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'promised_fulfilled',
                    required: true,
                    label: 'Promised (ready, SUI)',
                    align: 'left',
                    field: row => row.promised_fulfilled,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'all_time_promised_amount',
                    required: true,
                    label: 'PromisedPool (all time)',
                    align: 'left',
                    field: row => row.all_time_promised_amount,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'extra_staked_in_promised',
                    required: true,
                    label: 'extra_staked_in_promised',
                    align: 'left',
                    field: row => row.extra_staked_in_promised,
                    // format: val => `${val}`,
                    sortable: true
                },
                {
                    name: 'all_time_extra_amount',
                    required: true,
                    label: 'extra_staked_in_promised (all time)',
                    align: 'left',
                    field: row => row.all_time_extra_amount,
                    // format: val => `${val}`,
                    sortable: true
                },
            ],

            notFulfilledPromises: [],

            detailsForRowPopup: null,
            showRowPopup: false,
		}
	},
	computed: {
	},
	components: {
	},
	watch:{
        simulation1: function() {
            if (this.simulation1) {
                this.epochRows = this.simulation1.epochs;
                this.transactionsRows = this.simulation1.transactions;
                this.notFulfilledPromises = this.findNotFulfilledPromises();
            } else {
                this.epochRows = [];
                this.transactionsRows = [];
                this.notFulfilledPromises = [];
            }
        }
	},
	mounted() {
        if (this.simulation1) {
            this.epochRows = this.simulation1.epochs;
            this.transactionsRows = this.simulation1.transactions;
            this.notFulfilledPromises = this.findNotFulfilledPromises();
        }
	},
	methods: {
        onEpochRowClick(evt, row, index) {
            // alert(index);
            // console.error('row', row);
            console.log(evt, row, index);

            this.detailsForRowPopup = this.getRowDetails(row);
            console.error()
            this.showRowPopup = true;
        },
        getRowDetails(row) {
            const ret = {
                epoch: parseInt(row.epoch, 10),
                notFulfilledPromises: [],
                row: row,

                total_ready_for_pay_off: (parseFloat(row.promised_fulfilled, 10) + parseFloat(row.promised_amount_in_staked, 10)),

                staked_staked_suis: row.staked_staked_suis,
            };

            if (!ret.staked_staked_suis || !ret.staked_staked_suis.length) {
                ret.staked_staked_suis = [];
            }

            for (const transaction of this.simulation1.transactions) {
                if (transaction.type == 'withdraw' && parseInt(transaction.epoch, 10) <= ret.epoch) {
                    const promiseId = transaction.promiseId;
                    // const expectedAmount = transaction.received;

                    let foundFulfilled = false;
                    for (const findTransaction of this.simulation1.transactions) {
                        if (parseInt(findTransaction.epoch, 10) <= ret.epoch) {
                            if (findTransaction.type == 'fulfill' && findTransaction.promiseId && findTransaction.promiseId == promiseId) {
                                foundFulfilled = true;
                            }
                        }
                    }

                    if (!foundFulfilled) {
                        ret.notFulfilledPromises.push(transaction);
                    }
                }    
            }

            for (const staked_sui of ret.staked_staked_suis) {
                const poolId = staked_sui.pool_id;
                const curEpoch = Number(row.epoch);
                const minEpoch = curEpoch - 7;

                staked_sui.rates = [];

                let priceNow = 1;
                let price5epochs = 1;
                let price7epochs = 1;

                if (this.simulation1 && this.simulation1.pools && this.simulation1.pools[poolId]) {
                    // get last 7 epochs till this one
                    for (const rate of this.simulation1.pools[poolId]) {
                        if (rate.epoch >= minEpoch && rate.epoch <= curEpoch) {
                            rate.k = Number(rate.sui_amount) / Number(rate.pool_token_amount);
                            staked_sui.rates.push(rate);

                            if (rate.epoch == curEpoch) {
                                priceNow = rate.k;
                            }
                            if (rate.epoch == curEpoch - 5) {
                                price5epochs = rate.k;
                            }
                            if (rate.epoch == curEpoch - 7) {
                                price7epochs = rate.k;
                            }
                        }
                    }
                }

                staked_sui.diff5epochs = priceNow - price5epochs;
                staked_sui.diff7epochs = priceNow - price7epochs;
            }

            return ret;
        },
        findNotFulfilledPromises() {
            const ret = [];

            for (const transaction of this.simulation1.transactions) {
                if (transaction.type == 'withdraw') {
                    const promiseId = transaction.promiseId;
                    // const expectedAmount = transaction.received;

                    let foundFulfilled = false;
                    for (const findTransaction of this.simulation1.transactions) {
                        if (findTransaction.type == 'fulfill' && findTransaction.promiseId && findTransaction.promiseId == promiseId) {
                            foundFulfilled = true;
                        }
                    }

                    if (!foundFulfilled) {
                        ret.push(transaction);
                    }
                }    
            }

            return ret;
        }
	},
	beforeCreate() {
	}
}
</script>

<style scoped>



</style>