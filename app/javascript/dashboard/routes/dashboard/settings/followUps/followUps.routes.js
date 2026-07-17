import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsContent from '../Wrapper.vue';
import SettingsWrapper from '../SettingsWrapper.vue';
import FollowUpsIndex from './Index.vue';
import FollowUpEditor from './FollowUpEditor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/follow-ups'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'follow_ups_wrapper',
          component: FollowUpsIndex,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/follow-ups'),
      component: SettingsContent,
      props: () => ({
        headerTitle: 'FOLLOW_UPS.HEADER',
        icon: 'arrow-redo',
        showBackButton: true,
      }),
      children: [
        {
          path: 'new',
          name: 'follow_ups_new',
          component: FollowUpEditor,
          meta: {
            permissions: [...ROLES],
          },
        },
        {
          path: ':workflowId/edit',
          name: 'follow_ups_edit',
          component: FollowUpEditor,
          meta: {
            permissions: [...ROLES],
          },
        },
      ],
    },
  ],
};
