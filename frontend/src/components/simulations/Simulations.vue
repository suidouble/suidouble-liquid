<template>

	<div>
        <q-select square outlined v-model="selected1name" :options="available" label="Select simulation" />

        <q-separator />

        <q-card square flat bordered>
        <div class="row">
            <div class="col col-12 col-md-4">
                <SimulationPriceChart :simulation1="simulation1" v-if="simulation1" />
            </div>
            <div class="col col-12 col-md-3">
                &nbsp;
            </div>
            <div class="col col-12 col-md-5">
                <SimulationDispositionChart :simulation1="simulation1" :epoch="selectedEpoch"  v-if="simulation1"  />
            </div>
        </div>
        <SimulationPlayer @epoch="onEpoch" :simulation1="simulation1"/>

        </q-card>

        <SimulationTableView :simulation1="simulation1" />
	</div>

</template>

<script>
import axios from 'axios';
import SimulationTableView from './SimulationTableView.vue';
import SimulationPriceChart from './SimulationPriceChart.vue';
import SimulationDispositionChart from './SimulationDispositionChart.vue';
import SimulationPlayer from './SimulationPlayer.vue';

export default {
	name: 'Simulations',
	data() {
		return {
            available: [],
            selected1name: null,

            simulation1: null,
            selectedEpoch: -1,
		}
	},
	computed: {
	},
	components: {
        SimulationTableView,
        SimulationPriceChart,
        SimulationDispositionChart,
        SimulationPlayer,
	},
	watch:{
        selected1name: function() {
            this.loadSimulation1();
        }
	},
	mounted() {
        this.loadAvailable()
            .then(()=>{
                if (this.available.length) {
                    // show most recent by default
                    this.selected1name = this.available[this.available.length - 1];
                }
            });

	},
	methods: {
        onEpoch(epoch) {
            this.selectedEpoch = epoch;
        },
        loadSimulation1: async function() {
            if (this.selected1name) {
                this.simulation1 = null;
                this.simulation1 = await this.loadSimulation(this.selected1name);
            } else {
                this.simulation1 = null;
            }
        },
        loadAvailable: async function() {
            let data = [];

            try {
                const baseUrl = (process.env.API_URL ? process.env.API_URL : '/');
                const config = { headers: {} };
                const url = baseUrl + 'api/simulations/list';
                const response = await axios.get(url, config);
                data = response.data.items;
            } catch (e) {
                console.error(e);
            }

            this.available = data;
        },
        loadSimulation: async function(simulationName) {
            if (!this.__simulationsCache) {
                this.__simulationsCache = {};
            }
            await new Promise((res)=>setTimeout(res, 50)); // nextTick
            if (this.__simulationsCache[simulationName]) {
                return this.__simulationsCache[simulationName];
            }

            // await new Promise((res)=>setTimeout(res, 2000));
            
            let object = null;
            try {
                const baseUrl = (process.env.API_URL ? process.env.API_URL : '/');
                const config = { headers: {} };
                const url = baseUrl + 'api/simulations/get';
                const response = await axios.post(url, {name: simulationName}, config);
                const json = response.data.json;
                object = JSON.parse(json);
            } catch (e) {
                console.error(e);
            }

            this.__simulationsCache[simulationName] = object;

            return object;
        }
	},
	beforeCreate() {
	}
}
</script>

<style scoped>



</style>