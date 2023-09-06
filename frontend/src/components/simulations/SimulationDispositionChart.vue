<template>

    <div>
        <div style="width: 80%; margin: 20px auto;">
        <ApexChartsAsync
            type="donut"
            :options="chartOptions"
            :series="series" />

        </div>
    </div>

</template>

<script>

import ApexChartsAsync from 'shared/components/AsyncComponents/ApexChartsAsync.js';
// import { getCssVar } from 'quasar';

export default {
	name: 'SimulationDispositionChart',
	props: {
		simulation1: Object,
        epoch: {
            type: Number,
            default: -1,
        },
	},
	data() {
		return {
            selectedEpoch: -1,
            series: [0, 55, 41, 17, 15],
            chartOptions: {
                labels: ['ImmutablePool', 'PendingPool', 'StakedPool', 'StakedPoolRewards', 'ExtraFromStakedPromised'],
            legend: {
                show: true,
                        style: {
                            cssClass: 'apexcharts-yaxis-label',
                        },
            },
            xaxis: {

                labels: {
                        style: {
                            cssClass: 'apexcharts-yaxis-label',
                        },
            
                },
            },
            yaxis: {

                labels: {
                        style: {
                            cssClass: 'apexcharts-yaxis-label',
                        },
            
                },
            },
            },
		}
	},
	computed: {
	},
	components: {
		ApexChartsAsync,
        // SimulationPlayer,
	},
	watch:{
        simulation1: function() {
            if (this.simulation1) {
                this.updateChart();
            } else {
                this.epochRows = [];
                this.transactionsRows = [];
            }
        },
        epoch: function() {
            this.selectedEpoch = this.epoch;
            this.updateChart();
        }
	},
	mounted() {
        if (this.epoch) {
            this.selectedEpoch = this.epoch;
        }

        if (this.simulation1) {
            this.updateChart();
        }
	},
	methods: {
        updateChart() {
            let useEpoch = this.selectedEpoch;
            if (useEpoch < 0) {
                // select the most recent available
                useEpoch = this.simulation1.epochs[this.simulation1.epochs.length - 1].epoch;
            }

            let bestDistance = Infinity;
            let bestEpoch = this.simulation1.epochs[this.simulation1.epochs.length - 1];

            this.simulation1.epochs.forEach((epoch)=>{
                let distance = Math.abs( parseInt(epoch.epoch, 10) - parseInt(useEpoch, 10) );
                if (distance < bestDistance) {
                    bestDistance = distance;
                    bestEpoch = epoch;
                }
            });

            this.series = [];

            let immutablePool = parseFloat(bestEpoch.immutable_pool_sui, 10);
            if (immutablePool > 1000000) {
                immutablePool = immutablePool / 1000000000;
            }

            let pendingPool = parseFloat(bestEpoch.pending_amount, 10);
            let stakedPool = parseFloat(bestEpoch.staked_amount, 10);
            let stakedPoolWithRewards = parseFloat(bestEpoch.staked_with_rewards_balance, 10);

            let extra_staked_in_promised = parseFloat(bestEpoch.extra_staked_in_promised, 10);

            this.series.push(immutablePool, pendingPool, stakedPool, (stakedPoolWithRewards - stakedPool), extra_staked_in_promised);

            // alert(useEpoch);

            // this.series[0].data = [];
            // this.series[1].data = [];
            // this.categories = [];

            // for (const epoch of this.simulation1.epochs) {
            //     this.series[0].data.push(epoch.price_calculated);
            //     this.series[1].data.push(parseFloat(epoch.token_total_supply, 10));
            //     this.categories.push(epoch.epoch);
            // }

			// const categories = [];
			// for (let stat of stats.stats) {
			// 	const statDate = new Date(stat.date);

			// 	serie.data.push(stat.count);
			// 	categories.push(''+statDate.toLocaleString('default', { month: 'short' })+' '+statDate.getDate());
			// }

			// this.calculated.series = [serie];
			// this.calculated.categories = categories;
        }
	},
	beforeCreate() {
	}
}
</script>

<style >


.apexcharts-tooltip {
		/*background: #f3f3f3;*/
		color: black;
	}
	.apexcharts-xaxis-label {
		fill: var(--text-color);
	}
	body.body--dark .apexcharts-xaxis-label {
		fill: var(--text-color-dark);
	}
	.apexcharts-yaxis-label {
		fill: var(--text-color);
	}
	body.body--dark .apexcharts-yaxis-label {
		fill: var(--text-color-dark);
	}

    .apexcharts-legend-text {
        color: var(--text-color) !important;    
    }
    body.body--dark .apexcharts-legend-text {
        color: var(--text-color-dark) !important;
    }

</style>