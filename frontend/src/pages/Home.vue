<template>

  <div>
    <h3 class="text-center">Secure SUI and earn <br/>rewards without your funds <br/>locked in</h3>

    <h5 class="text-center">Simplified and secure participation in SUI staking</h5>

    <div class="text-center q-pt-md">

        <q-btn color="primary" label="Start stacking SUI" size="lg" unelevated />

    </div>
    

    <div class="q-pa-md row justify-center q-gutter-md">
    <q-card
      class="my-card col-12 col-md-4 q-mt-xl"
      bordered
      flat
    >
      <q-card-section class="rewards_simulator">
        <div class="text-h6 text-center">Rewards simulator</div>

        <div class="q-pt-md">

            <q-input outlined v-model="simulator_input" placeholder="Sui">
            <template v-slot:prepend>
            <q-icon name="water_drop" color="primary" /><span class="text-primary">SUI</span> 
            </template>
            </q-input>

        </div>

        <div class="text-h6 text-center  q-mt-md">
            Rewards summary
        </div>
        <div class="text-h6 text-subtitle2 text-center">
            With staking rewards compounding, the value of iSUI grows,<br/>resulting in a greater amount of SUI per iSUI over time.
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none">
        {{ lorem }}
      </q-card-section>
    </q-card>
    </div>
  </div>

</template>

<script>

export default {
	name: 'Home',
    path: '/',
	props: {
	},
    components: {
    },
	data() {
		return {
            chain: 'sui:mainnet',
            simulator_input: '10.00'
		}
	},
    watch: {
    },
	methods: {
        async switchTo(chainName) {
            this.chain = null;
            await new Promise((res)=>setTimeout(res, 500));
            this.chain = chainName;
        }
	},
    computed: {
    },
    beforeMount() {
    },
    mounted() {
    },
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style>
    h6 {
        font-size: 16px;
        font-weight: bold;
        margin: 0 0 16px 0;
    }

    h5 {
        margin: 0 0 16px 0;
    }

    .active_one {
        font-weight: bold;
    }

    .rewards_simulator .q-field__native {
        text-align: right;
        color: var(--text-color) !important;
        font-weight: bold !important;
        font-size: 20px !important;
    }
    .rewards_simulator .q-field__control .text-primary {
        font-size: 16px;
    }

</style>

