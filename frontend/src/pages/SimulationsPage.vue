<template>

	<div>
		<h5 class="text-primary">Simulations</h5>

		<Simulations />
	</div>

</template>

<script>
import Simulations from 'components/simulations/Simulations.vue';

export default {
	name: 'SimulationsPage',
	title: 'Simulations',
	authRequired: false,
	path: '/simulations',

	props: {
	},
	components: {
		Simulations,
	},
	data() {
		return {
			isActive: false,
		}
	},
	methods: {
	},
	mounted() {
	}
}
</script>
<style scoped>

</style>

