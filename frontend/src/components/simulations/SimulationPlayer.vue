<template>

    <div class="q-pa-md">
        
        <q-item>
            <q-item-section avatar>

                <q-btn size="15px" round color="primary" :icon="isPlaying ? 'pause_arrow' : 'play_arrow'" @click="onClickPlay" />

            </q-item-section>
            <q-item-section>
                <q-slider v-model="curEpoch" :min="0" :max="maxEpoch"  :label-value="'Epoch: '+curEpoch" label label-always />
            </q-item-section>
        </q-item>

    </div>

</template>

<script>


export default {
name: 'SimulationPlayer',
props: {
    simulation1: Object,
    epoch: {
        type: Number,
        default: -1,
    },
},
data() {
    return {
        curEpoch: 0,
        maxEpoch: 0,

        isPlaying: false,
    }
},
computed: {
},
components: {
},
watch:{
    curEpoch: function() {
        this.$emit('epoch', this.curEpoch);
    },
    simulation1: function() {
        this.updateRange();
    }
},
mounted() {
    this.updateRange();

    this.__playInterval = setInterval(this.interval, 500);
},
unmounted() {
    clearInterval(this.__playInterval);
},
methods: {
    interval() {
        if (this.isPlaying) {
            if (this.curEpoch == this.maxEpoch) {
                this.isPlaying = false;
            } else {
                this.curEpoch++;
            }
        }
    },
    onClickPlay() {
        if (!this.isPlaying && this.curEpoch == this.maxEpoch) {
            this.curEpoch = 0;
        }
        this.isPlaying = !this.isPlaying;
    },
    updateRange() {
        if (this.simulation1) {
            if (this.simulation1.epochs && this.simulation1.epochs.length) {
                this.maxEpoch = parseInt(this.simulation1.epochs[this.simulation1.epochs.length - 1].epoch, 10);
                this.curEpoch = this.maxEpoch;
            } else {
                this.maxEpoch = 0;
                this.curEpoch = 0;
            }
        } else {
            this.maxEpoch = 0;
            this.curEpoch = 0;
        }
    }
},
beforeCreate() {
}
}
</script>

<style >


</style>