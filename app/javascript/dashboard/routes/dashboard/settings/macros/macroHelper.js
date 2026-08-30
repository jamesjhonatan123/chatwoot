import { MACRO_ACTION_TYPES as macroActionTypes } from 'dashboard/routes/dashboard/settings/macros/constants.js';
export const emptyMacro = {
  name: '',
  actions: [
    {
      action_name: 'assign_team',
      action_params: [],
    },
  ],
  visibility: 'global',
};

export const resolveActionName = key =>
  macroActionTypes.find(i => i.key === key)?.label ?? key.toUpperCase();

export const getFileName = (id, actionType, files) => {
  if (!id) return '';
  if (actionType === 'send_attachment') {
    if (typeof id === 'object' && id.media_asset_id) {
      return id.caption || `Media #${id.media_asset_id}`;
    }
    if (!files) return '';
    const file = files.find(item => item.blob_id === id);
    if (file) return file.filename.toString();
  }
  return '';
};
