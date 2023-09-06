<template>

        <div style="">
        <ApexChartsAsync
            type="line"
            :options="chartOptions"
            :series="series" />
        </div>

</template>

<script>

import ApexChartsAsync from 'shared/components/AsyncComponents/ApexChartsAsync.js';
import { getCssVar } from 'quasar';

export default {
	name: 'SimulationPriceChart',
	props: {
		simulation1: Object
	},
	data() {
		return {
            series: [
                {
                    name: "Price",
                    type: 'line',
                    data: [0, 20.12, 0, 2, 0, 30, 0, 0],
                },
                {
                    name: "Token Supply",
                    type: 'line',
                    data: [0, 20.12, 0, 2, 0, 30, 0, 0],
                },
            ],
            categories: [],
		}
	},
	computed: {
		chartOptions() {
			return {
				categories: this.categories,
				chart: {
					id: "vuechart-example",
					toolbar: {
						show: false,
					},
					// height: 200,
				},stroke: {
  curve: 'smooth',
},
legend: {
    show: false,
},
				grid: {
					padding: {
						left: 8,
						right: 0,
					},
				},
				annotations: {
  xaxis: [
    {
      x: 'z1',
		x2: 'z22',
    fillColor: getCssVar('primary'),
      borderColor: getCssVar('primary'),
      color: getCssVar('primary'),
      label: {
        orientation: 'horizontal',
        style: {
          color: getCssVar('primary'),
            background: "#00E396"
        },
      borderColor: getCssVar('primary'),
      color: getCssVar('primary'),
        text: 'X-axis annotation - 22 Nov'
      }
    }
  ]
},
				colors: [getCssVar('primary'),getCssVar('secondary')],
				tooltip: {
					// fillSeriesColor: true,
                    x: {
                        formatter: function(value) {
                            return 'epoch '+value;
                        }
                    }
				},
				yaxis: [{
                    title: {text: 'Price', style: { cssClass: 'apexcharts-yaxis-label',}},
					show: true,
                    labels: {
                        style: {
                            cssClass: 'apexcharts-yaxis-label',
                        },
                    formatter: function (value) {
                        return parseFloat(value, 10).toFixed(6) + "";
                    }
                    },
				},{
                    title: {text: 'Token Supply', style: { cssClass: 'apexcharts-yaxis-label',}},
					show: true,
                    opposite: true,
                    labels: {
                        style: {
                            cssClass: 'apexcharts-yaxis-label',
                        },
                    formatter: function (value) {
                        return parseFloat(value, 10).toFixed(6) + "";
                    }
                    },
				},
                ],
				xaxis: {
					categories: this.categories,
                    show: false,
                    labels: {
                        formatter: function() {
                            return '';
                        }
                    },
					// labels: {
					// 	style: {
					// 		cssClass: 'apexcharts-xaxis-label',
					// 	},
					// },
				},
			};
		},
	},
	components: {
		ApexChartsAsync,
	},
	watch:{
        simulation1: function() {
            if (this.simulation1) {
                this.updateChart();
            } else {
                this.epochRows = [];
                this.transactionsRows = [];
            }
        }
	},
	mounted() {
        if (this.simulation1) {
            this.updateChart();
        }
	},
	methods: {
        updateChart() {
            this.series[0].data = [];
            this.series[1].data = [];
            this.categories = [];

            for (const epoch of this.simulation1.epochs) {
                this.series[0].data.push(epoch.price_calculated);
                this.series[1].data.push(parseFloat(epoch.token_total_supply, 10));
                this.categories.push(epoch.epoch);
            }

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

</style>