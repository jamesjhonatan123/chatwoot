import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import MediaLibraryIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/media-library'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'media_library_wrapper',
          component: MediaLibraryIndex,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
      ],
    },
  ],
};
