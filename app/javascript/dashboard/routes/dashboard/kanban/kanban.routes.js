import { frontendURL } from 'dashboard/helper/URLHelper';
import Kanban from './Kanban.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_dashboard',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: Kanban,
  },
];
