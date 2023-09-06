<template>

	<span>
		<span v-if="isStateCalculated">
			<q-chip :style="{backgroundColor: color}">
				<q-avatar>
					<img :src="avatar" v-if="avatar">
				</q-avatar>
				{{ userName }}
			</q-chip>
			{{ suiBalance }} SUI, {{ tokenBalance }} TOKEN ( ~ {{ tokenInSui }} SUI), +{{ amountNotFulfilled }} SUI in {{ countNotFulfilled }} Promises, total: ~ {{ totalInSui }} SUI</span>
		<span v-if="!isStateCalculated">...</span>
	</span>

</template>
<script>

export default {
	props: {
		row: Object,
		arr: Array,
		epochs: Array,
		col: Object,
		value: [String, Object],
		id: String,
	},
	data() {
		return {
			isStateCalculated: false,

			suiBalance: 0,
			tokenBalance: 0,
			tokenInSui: 0,
			totalInSui: 0,

			amountNotFulfilled: 0,
			countNotFulfilled: 0,

			userName: '',
			userN: 0,
			avatar: null,

			color: '#f5e',
		}
	},
	watch: {
	},
	methods: {
        onClick() {
        },
		// hashCode(str) {
		// 	let hash = 0;
		// 	let chr = 0;
		// 	let i = 0;
		// 	if (str.length === 0) return hash;
		// 	for (i = 0; i < str.length; i++) {
		// 		chr = str.charCodeAt(i);
		// 		hash = ((hash << 5) - hash) + chr;
		// 		hash |= 0; // Convert to 32bit integer
		// 	}
		// 	return hash;
		// },
		calculateState() {
			const thisTime = parseInt(this.id, 10);

			let user = ''+this.row.user;
			const userNames = ['Alice', 'Eve', 'Kate', 'Sapyada', 'Nadine'];

			if (!window.__simulationNameToN) {
				window.__simulationNameToN = {};
			}

			let userN = 0;
			if (window.__simulationNameToN[user] !== undefined) {
				userN = window.__simulationNameToN[user];
			} else {
				for (const key in window.__simulationNameToN) {
					if (window.__simulationNameToN[key] == userN) {
						userN++;
					}
				}
				window.__simulationNameToN[user] = userN;
			}

			const avatars = [
				'data:image/png;base64,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',
				'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAC8VBMVEX/suP/suP7+vb/suP/suP/suP/suP/suP/suP/suP+17/01HrDqmLz03ruz3fgw3DFq2Hbvm37+fXdwG7oynTTt2nvyrTjxnHx0Xjy03nZvWzYu2zy8e3Wumv607rStmjf39vv7uv39vLGrGPqzHX+seL50rvoos7tznaul1bgnMfOs2efilDQ0M23n1urlVX7r+DMsWb30bnPzsvKsGW9pF7myHP917/jwKrIrWT81b3KjLPDqWDCqWH0qtna2te5oFyrkYC/v7zrx7HewW+8o123trTm5eKkjlKqqaXd3Nrvp9XRkbn12o745a7WlL75+PTs6+jj4t7incmrk2rBqGHz8u+dnJvFxMHX1tPgvajzzrfJqZaxmlm/pl/Yt6KzsrCDckO3ur/al8Hh4N2oeI6kil2vrqy8g6f23ZrFx8irk1rMy8i9wMO1t72WgkqfiFvloMzJyszcuqStllq8vcCbhk+iiXebmJCGdlbavW2QjouTe2ymkVP+4dCleoakepTGibC0m1u4gaKteZehhWTJyMf34qfCooz2rNucmpf1z7ixs7jk4+Dq6eW8u7ivlYWbf2Wegmugn5u1nVv4z7XAw8qpk1TlyH/SspuKgWyJd0OljH67nYu3m4lbUEHp6OTDw8SzqZ/T08+xfZr4rd2wlnb01oO0fZ7VvYHv1IvasJv01HvzxKnoxK7QtWefenXqpc6+oYTkyImldY761sJpWzHRtKesrKndwnj+2sSNekh5aTuXf3Drz42ckInOrpqbg3GYkpJ+akfg0cGmo6Lyz6VlXluzg6FbTVDr1JmddnujfnrdmsTx1ILDqZrYp47s16S6r6mij1zswajkqoq2m3vir5ODfXmmmpJ2bFKoop27oXK9o2x5d3LwrNDevZb9s91Ye5SilZRNS0dyaGOhiW5BWm0+NB+GcGN+nbReZXG1jIuDcUtkVTN+eHp8VG318/ChfnbCo5Hmx5bXyau8sZehr7qusLM4dptWeI/HGlpxAAAACnRSTlP+1v//8erh/fr2e71dJQAABbxJREFUWMPF1nVUG0kYAHBuene925kkRCABsoUogYQkWPDgFLfiLsVKkZYWCVaD9tpS6i7UndTd9azn7u7ud3/dJIFA7x7ZFN69+/7ZvH3z/Xbmm9lvY2NjM2k8YTN58mOPP/zIow+NL32UMG5gWBg/MCRMADAJEwGMwoQALEwQwMIEgUk2/zsw6T8GJAnTylPKXdXjA7TzuyujfZxJfXDjHvWDA9o9tWwaHAqnRQkPCiRWciDUOLLFRoCmX9Dt+iCA5IAthAxHDhwJ3oJqifXAQj2UkTJ4fzh1q60FyqOhhm16Lt2Ua8QYFVYC6g6ahmHI5p43LULmRhqvnkHWAYl6MRNCutPBp/dDuJ/nQNMrRKZV9Oy1CniGZgch5+CLyTVJSTXPcWhkSEOIxgjo5lsDaN0YMgb9ZE3N4uTk5ENRdD2q3YecHYzCMWuAIJJkyjjwSNLi5MUbSYYIZS4ZXCt3NAK1e60AKuhyLo12JOlQ0hV5gE9mg2+GlMhAzlEQRsGQWdSApIdtB8U8LptDIoQK21QZ9gTRpLT1FEMdjUykBhLC5Fyu2M5Zbkjft0RxwovA8ZrIKYDG5rGDqIEUuyI2IwAhZe2cd5tWtvgTxrCfI+f6esqYVgD3RJk+tmjOZwX5Uz54x54YjhOI4aniOKdYMYMzbghltHza/vU2P0Om18mNG6/c8WuK9mRsoCuPUwOLFGuRatO2qV99/tGm4cdPufNLvsqWroSNakpAsuqiEjXnS+3Pfjx7JUHkE4R/x92t/vbrYm1pel4F9UFyjVYoi1qIri4/qVcesYwgIm//+dfvd4ulnT7Q0SeRGqjWBIsWhBOEn+HhuAJE3q1dN3qzI/0LSbrujDs18BPUiWO3GjL9TOvPJwIDL9gTK4u43C2x1ECCEpIw4/LQ5p++QBBSL+J0V5f02wAHHyfRNEqgmgtJ3vYOE1BcHDkoxddAgrimYEInaEsNHIOQjGKuHto+r8E8qelXB+JxNFYArmG4ATrCRvxMv5FTSBCDW6IccFtDs6iAA7jzOLKhHh8hacHzh49OIbyM79L1EI1DtBWAZBVuGiTuHY145uvOxod6v7QkEuf7X2Ly7DJ51IA7MrRg3BG5LTjt6KsvHH490FDEL30ZDmFIDJErBbAIfwYQzxf3ns7thm18ZZ2xlNdLRXgCiAODKQB1Jf566GhrIV2EYsMDTfULLGgr7NTxwhAGlAmWgRRnCIMhg6tz21LatuOyoZdEbttRqlJEy+QhBsDtCctABQ/qGGKS/YlLFgDnvArCw8N/Li4J9WiVc1QoGtegU20RkPTgCjgENMdNrwIAvG1aQZ4HALsYvy51UyA6rJRYBFyLIIPptHkqADneALw5dJxzQc7m8/zU1mZEgz2Wv41BTIg0mXEACMG5dLDVBFxzyY357RYAERd9IHzWMnCKRw8IQJsByOILl3qHm4CCkjjWLj4ArQpc4VOWgVVQL0cb3hMCkCbIemPoVfC/kSrIBYDVXqqD4oUWgQ+bId7sUjwasNIEgqvLjDVcI+SvSMW30t/iQrbl/wfvu8k2oNi4/iohYAFBmuBqk9R+e0mqQMBigdSIqphCmuc9i8BxX09f33YWmJrdKxTyBfF9vXExfTtLBPwfhbuXxgOQ+7JKaxFwDw4LaQjFswW5a/pXZJUtHxAKd5b1ZQlysr0NiwDxT6ktAyJVQ5sQGGOgf037+piciLLsuOyS6SzTTeAyz+JJnKaKvdkKzMGv/yM9oqxPCEbF9HkSC4DrpW9Wx4wa3Vs3sHMuuD9c/iWMArRfuN/0GD14vcfcGeCfwpOSsQ/SD9rv0oD3wPBYYf3sUUCayWbFLxwbcNfuSAUz0805y+tmjCwhPWLox+7qsfuB5HsAvF3MOXV1s5eP1K/XXJv5Y7e02xgINefUz8it55sXP9N8PydxLEDbjwGPkX30cFlvXlB81UglY8pHcv4Gt7iCBBqKw18AAAAASUVORK5CYII=',
				'data:image/png;base64,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',
				'data:image/png;base64,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',
				'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAC91BMVEX/mwD/mwD/mwD/mwD/mwD/mwD/mwD/mwD/mwD/mwD+mgD/mwD/mwDOfADnjAC0bAD/mwD/mwD7mACPVAD/mwBMKgD/mwDEdQCmYwDchQD/mwD3lgD/mwD/mwD/mwD/mwD/mwD/mwDMegDSfwA8IQDdhQDzlADliwDCdQCiYQDQfQA5FyuoZACHTwBXMQBoPABZMgDkigDVgQC0bADJeQDbhADfhwD/mwD/mwCqZQCaWwAwGAD/mwA8IQD/mwBNKwD/mwABAADgiAD/mwD/mwBkOgD/mwCqZQD/mwD/mwC9cQB+SgD/mwA0HADTfwCiYABiOAD2lQDgiAD28u8zMzP/mwCZM5kAAAAsLCweHh4bGxsqKiooKCgBAQEwMDAWFhYyMjILCwsnJyckJCQPDw8ZGRkvLy8FBQUgICAxMTETExOPL4/18e4uLi7w7OkYGBiSMJIiIiIDAwP8mQAWCAAICAh8KHyKLYp3dXOnpKKYM5ju6uc4DTjz7+wmJibp5uPSfwClYgDHw8HEwb/OysiEgYC+u7mbmJZDQkHk4N2GhILCdQCzsK1/KX/2lgAKCgoNBACGK4bXggDLyMWwraupZAA/ED8RERHa1tRQFlA3NjWCKoLx7evh3tuTkI9VGVWenJpyJHJjHmOWWQC1srDBvrzrjgC4tbPfhwCwaQBWMQDPfABxQgDpjQAhCCF6SACYlZOin51dNQC9cgDW09DFdwAxCzHd2dbvkQBIKAD5lwDRzctLFUtvI297eXeILYhwI3BsIWwIAQXIeAAWAxZZV1YdBB1hX15HE0czGwAcDQB3RQD0lADg3NlmY2KGTwCcXQCAfXxMS0rSz8xgHWB/SgBhNwCNLo1JSEc9PDtdHF12JXaloqDn4+AoByiQjYytq6jchQCXMpdoZmVQLQCNUwA4HgA9IQCsZgBwbmyDK4N5J3kVCABFJgA3LjWVk5HligBNKwCRVgAuGACMLoxoPABoIGhIR0ZQT058SAAiEAC7uLW4bgD1tE7iAAAA53RSTlP74u3o8PLX/f7526Dr/v7+yfWN7d790OLs3+XVxfdoS4ZQ/vL5+ObFz9y1/vjn4PH72d3n9Lfnda5z7/2+vqnyL/56q7ePk61bfj3Vfdvl8Pvz+f////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////4rAzKPAAAGd0lEQVRYw41XZ1gTWRQdEETRtXfFtr336vbe2yS5mfTeEEMCATQgTQEpUqRLUYqKICLYe1mxgW3toq5Yt/e+P/ZNZiaZzEzE+yPfl5l3zrvlvPvmYmIh60pp+uXQzwUAENu+un5oUZfgqgHIwjABdMchhASDzU4QhExtywcouLZiY4wgiZhHsOxoLJhluiiRzzRSvVGJnDl1MnXPxj4IFpYUgF2hEfHMKlVY1C7kWMu6zbcguLwS7FJRYDPp1QCbcmICEeQU5MtFfZiJcELLKmGCm6BWifo2lQwOpAgRNIFMI7otU5hhD59gHchEt2tSLUwPQypgE6yIVWtum0Bk0n53d8TAgRgyRj0rtVb/SOV6grDbZYRebhXywTn6ngn9BgeHMAT1Snb55IQWWGaw8Gurg5GTho0ZE04TFIHDt7cDCUZZemJp3I74+Pi88ydKEYeOx2CEBwYNeu5FiiDmlIFJgNXihN21cdESlkXnwVx+GpSPTH526iCKIAcYASnyoXOXH5q0QhAQCAHPT5k8wkOweZOaPjYEKOuiIwu5BLvKhCqhfOnVae9hlANUkqxqSCyU7PiDi5ck6oVqaXzt/SkfegjaaQfQSXkQ6vb3cvHxECVEIIe3pk3FPCVQeB5EkSVzfvEbz4FtIHxEXR+9+zZJUJ9PP7AQOrlrKQ8v2R+AgIDXySosPGjxNR/DVj6+V7NPIRKO4Z03EEEzi9/YGckn2Naz3SFIoIEP3kQE9VqWPs/z8ZE/JC9RC58p2yuTEMH3hFfE5goy54tPs/FzthbjjUprgCRMxMRDQMEOoLcClaKUFciufVX4BRAUgmguPIOJ93hlKoedEkmesvZcIsR58Yu15TiOb9eqFHodzw0pPIWJU70pKEtEEjpNltHnwI7OBoTH0wBdDGDm6skEQzHx33bmHLH29WrwYhuJx5P2gswiU/KqCamY+DqTQ0MpD1/YOr/KQ4BcQB2T3/NcR7AYJj9yvgN5ndk0HscTQEhMttXYKqbZGNfPocrmxe+EzCQGj1cbXQI9Qb0SG0L3EhVs86hmq7OC6ifRtVCMsywXBNQkO4itoIWsB5T6um/Wo2RXeMq3vnKeF4wCcWfIwCGgJCyFJjDuR6g6qgtHSqLPQcIF3+6ZG8rPkC/kAgR30ARmJCJJHEXw7eKLUQ1JLPeXA+F5YTbxCaZT3cYEZCOspQgSjZkX2OHjs/T0DVHGqaTsH8YDKfRKopfuppYluHF/W+S9Y2S8KtA5kCZK8loP06sSOHh8Pv1i92GOGpAOiigCTWvrV92NAQjcSsaB7kqXXxDma94yGrJwfHYAgnneCGZuUev9WlIJIyQVXMLxJfSy+RyCYgYvwvG1WaxaRkEORvcTPaTj+I/0uh4OwRqG4BiZD4L1qQIpzFkwONy+hYs4BDUMQS7J5muhaNtVWJfn4lVAJnrXQJeKW0UmNKj2iErF0lEMhpHH2ZovW4DelVPLMrlVZJKbTWnClwTb72JEYCEvRergfU0uO5uMC+tI203+6QaH1wVnvRiLiCVQAPMp5VcfB8gq5+Jxd6U3A0jWYGYIVDBUjIXcQATZzMlxp6e5cb5lkPjZ9J8zLt/V1izGgq4SIt0VPKDNpKR0qW0t8yTb6LsWfhJjw0YjAkgOhF+7AefJUuErwmYx9vIMAgkqlxf2l+TvguwM7ovkLJ8O7JvQl+oIQMoynOVG7iZz2ahazsUnbWedR8NJD4GDDKaGuzJ9b1LP8S28kJaAkX2tIIKnPVK2Ac/Xqg09/ILMBoOGdbF1IIKxnuNsMhu24H1bD2hV7A8UNDZgD4HndMmV8j4ZqmpAy+6qDliGCA7R94UOyjJuja++AgYWXkVAOzkvxB75lbrbFE6ocd9i+1wdqL0fCBo5Gp1WkzMgdrmrg/6SRmPIn41JwvCk9L2gpC4mk1RnUTsBrq6LYUaeVHpYssoA9jXO4sOTG/5CAwBhIdQ2F3Uw7xp550DWzNQEBqqzSm0AlW3z/CLpXn4M7fcY01NmPPrw/ffdO2xUKMYeupoPKC0KaRTyQ25Hi5SH24rT0xalpf+75pgI/b/+wvj+48eNe3LsE49P7E9aeFBwRJjf1LasheJXmg1+ww6yTz/5ODx8VFBQ0IQJ/dCQFBwSEhoaOjwCG+A/9sU0FzUdabmBRuyDaOpvP9pxsyS1pOS/6Z9/FjyYRCHM8IgIckwLo4zGi/8HZfDLOIkWJMwAAAAASUVORK5CYII=',
			];

			const colors = [
				'#0fb8b3',
				'#ffb2e3',
				'#6bf836',
				'#d5debf',
				'#ff9b00',
			];

			this.userName = userNames[userN];
			this.userN = userN;

			this.color = colors[userN];
			this.avatar = avatars[userN];

			let token = 0;
			let sui = 0;
			for (let transaction of this.arr) {
				if (transaction.time <= thisTime && (''+transaction.user) == user) {
					if (transaction.type == 'deposit') {
						sui = sui - parseFloat(transaction.send, 10);
						token = token + (parseFloat(transaction.received, 10) / 1000000000);
					}
					if (transaction.type == 'withdraw') {
						token = token - (parseFloat(transaction.send, 10) / 1000000000);
					}
					if (transaction.type == 'fulfill') {
						sui = sui + (parseFloat(transaction.received, 10) / 1000000000);
					}
				}
			}

			this.suiBalance = sui.toFixed(2);
			this.tokenBalance = token.toFixed(2);
            
			try {
				let countNotFulfilled = 0;
				let amountNotFulfilled = 0;

				for (const transaction of this.arr) {
					if ( (''+transaction.user) == user && transaction.type == 'withdraw' && parseInt(transaction.time, 10) <= this.row.time) {
						const promiseId = transaction.promiseId;
						let foundFulfilled = false;
						for (const findTransaction of this.arr) {
							if (parseInt(findTransaction.epoch, 10) <= this.row.epoch) {
								if (findTransaction.type == 'fulfill' && findTransaction.promiseId && findTransaction.promiseId == promiseId) {
									foundFulfilled = true;
								}
							}
						}

						if (!foundFulfilled) {
							countNotFulfilled++;
							amountNotFulfilled = amountNotFulfilled + parseFloat(transaction.received, 10);
						}
					}    
				}

				this.amountNotFulfilled = (parseFloat(amountNotFulfilled, 10) / 1000000000);
				this.countNotFulfilled = countNotFulfilled;
			} catch(e) {
				console.error(e);
			}

			// try to find price
			try {
				let bestDistance = Infinity;
				let bestEpoch = this.epochs[this.epochs.length - 1];

				this.epochs.forEach((epoch)=>{
					let distance = Math.abs( parseInt(epoch.epoch, 10) - parseInt(this.row.epoch, 10) );
					if (distance < bestDistance) {
						bestDistance = distance;
						bestEpoch = epoch;
					}
				});

				if (bestEpoch) {
					this.tokenInSui = token * bestEpoch.price_calculated;
					this.totalInSui = this.tokenInSui + sui + this.amountNotFulfilled;

					this.totalInSui = this.totalInSui.toFixed(2);
					this.tokenInSui = this.tokenInSui.toFixed(2);
					this.amountNotFulfilled = this.amountNotFulfilled.toFixed(2);
				}


			} catch (e) {
				console.error(e);
			}





			this.isStateCalculated = true;
		},
	},
	computed: {
	},
	unmounted: function() {
		clearTimeout(this.__calculateTimeout);
	},
	mounted: function(){
		const tm = 500 + parseInt(this.row.epoch, 10)*100;
		this.__calculateTimeout = setTimeout(this.calculateState, tm);
	}
}
</script>
<style lang="css">



</style>