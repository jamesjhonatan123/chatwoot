const allElementsString = arr => {
  return arr.every(elem => typeof elem === 'string');
};

const allElementsNumbers = arr => {
  return arr.every(elem => typeof elem === 'number');
};

const formatArray = params => {
  if (params.length <= 0) {
    return [];
  }
  if (allElementsString(params) || allElementsNumbers(params)) {
    return [...params];
  }

  // Preserve media library payloads used by send_attachment / send_message
  if (
    params.every(
      val => val && typeof val === 'object' && (val.media_asset_id || val.id)
    )
  ) {
    return params.map(val => {
      if (val.media_asset_id) {
        return {
          media_asset_id: val.media_asset_id,
          caption: val.caption || '',
        };
      }
      return val.id;
    });
  }

  return params.map(val => val.id);
};

const generatePayloadForObject = item => {
  if (item.action_params.id) {
    item.action_params = [item.action_params.id];
  } else {
    item.action_params = [item.action_params];
  }
  return item.action_params;
};

const generatePayload = data => {
  const actions = JSON.parse(JSON.stringify(data));
  let payload = actions.map(item => {
    if (Array.isArray(item.action_params)) {
      item.action_params = formatArray(item.action_params);
    } else if (typeof item.action_params === 'object') {
      item.action_params = generatePayloadForObject(item);
    } else if (!item.action_params) {
      item.action_params = [];
    } else {
      item.action_params = [item.action_params];
    }
    return item;
  });
  return payload;
};

export default generatePayload;
