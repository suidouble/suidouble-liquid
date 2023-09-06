
// import { useSessionUserStore } from './sessionUser.js';
// import { useApiStore } from './api.js';
import { useColorStore } from './color.js';

export default () => {
	return {
		color: useColorStore(),
		// api: useApiStore(),
		// sessionUser: useSessionUserStore(),
		// settings: useSettingsStore(),
	}
};