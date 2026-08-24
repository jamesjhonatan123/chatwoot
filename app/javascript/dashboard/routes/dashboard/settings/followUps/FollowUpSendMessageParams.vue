<script setup>
import { ref, computed } from 'vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FollowUpWhatsAppTemplateModal from './FollowUpWhatsAppTemplateModal.vue';
import MediaLibraryPicker from 'dashboard/components/widgets/mediaLibrary/MediaLibraryPicker.vue';

const action = defineModel({
  type: Object,
  required: true,
});

const showTemplateModal = ref(false);
const showMediaPicker = ref(false);

const isTemplateMessage = computed(() => {
  const params = action.value.action_params;
  return Boolean(
    params &&
      typeof params === 'object' &&
      !Array.isArray(params) &&
      params.template_params
  );
});

const mediaAssetId = computed(
  () => action.value.action_params?.media_asset_id || null
);

const mediaPreview = computed(
  () => action.value.action_params?.media_preview || null
);

const textContent = computed({
  get() {
    const params = action.value.action_params;
    if (typeof params === 'string') return params;
    if (Array.isArray(params)) return params[0] || '';
    if (params && typeof params === 'object') return params.message || '';
    return '';
  },
  set(value) {
    const params = action.value.action_params;
    if (params && typeof params === 'object' && !Array.isArray(params)) {
      action.value = {
        ...action.value,
        action_params: {
          ...params,
          message: value,
        },
      };
      return;
    }
    action.value = {
      ...action.value,
      action_params: value,
    };
  },
});

const templateName = computed(
  () => action.value.action_params?.template_params?.name || ''
);

const openTemplateModal = () => {
  showTemplateModal.value = true;
};

const onTemplateSelected = payload => {
  action.value = {
    ...action.value,
    action_params: {
      message: payload.message,
      template_params: payload.template_params,
      inbox_id: payload.inbox_id,
    },
  };
};

const clearTemplate = () => {
  if (!isTemplateMessage.value) return;
  action.value = {
    ...action.value,
    action_params: action.value.action_params.message || '',
  };
};

const onMediaSelected = ({ mediaAssetId: id, caption, asset }) => {
  action.value = {
    ...action.value,
    action_params: {
      message: caption || textContent.value || '',
      media_asset_id: id,
      media_preview: {
        file_name: asset?.file_name,
        thumb_url: asset?.thumb_url,
        file_url: asset?.file_url,
        file_type: asset?.file_type,
      },
    },
  };
};

const clearMedia = () => {
  const params = action.value.action_params;
  if (!params || typeof params !== 'object' || Array.isArray(params)) return;
  const { media_asset_id: _id, media_preview: _preview, ...rest } = params;
  action.value = {
    ...action.value,
    action_params: rest.message || rest.template_params ? rest : '',
  };
};
</script>

<template>
  <div class="flex flex-col gap-2 pl-0">
    <div class="flex flex-wrap gap-2">
      <NextButton
        xs
        :solid="!isTemplateMessage"
        :faded="isTemplateMessage"
        :slate="isTemplateMessage"
        :label="$t('FOLLOW_UPS.SEND_AS_TEXT')"
        @click="clearTemplate"
      />
      <NextButton
        xs
        :solid="isTemplateMessage"
        :faded="!isTemplateMessage"
        :slate="!isTemplateMessage"
        icon="i-ri-whatsapp-line"
        :label="$t('FOLLOW_UPS.SEND_AS_WHATSAPP_TEMPLATE')"
        @click="openTemplateModal"
      />
      <NextButton
        v-if="!isTemplateMessage"
        xs
        faded
        slate
        icon="i-lucide-images"
        :label="$t('MEDIA_LIBRARY.ATTACH')"
        @click="showMediaPicker = true"
      />
    </div>

    <div
      v-if="isTemplateMessage"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            $t('FOLLOW_UPS.TEMPLATE_SELECTED', {
              name: templateName,
            })
          }}
        </span>
        <NextButton
          xs
          faded
          slate
          :label="$t('FOLLOW_UPS.CHANGE_WHATSAPP_TEMPLATE')"
          @click="openTemplateModal"
        />
      </div>
      <p class="mb-0 text-sm whitespace-pre-wrap text-n-slate-11">
        {{ textContent }}
      </p>
    </div>

    <template v-else>
      <div
        v-if="mediaAssetId"
        class="flex items-center gap-2 p-3 rounded-lg bg-n-alpha-black2"
      >
        <img
          v-if="
            mediaPreview?.file_type === 'image' &&
            (mediaPreview.thumb_url || mediaPreview.file_url)
          "
          :src="mediaPreview.thumb_url || mediaPreview.file_url"
          :alt="mediaPreview.file_name"
          class="object-cover w-12 h-12 rounded"
        />
        <div class="flex-1 min-w-0">
          <p class="mb-0 text-sm truncate text-n-slate-12">
            {{
              $t('MEDIA_LIBRARY.SELECTED', {
                name: mediaPreview?.file_name || `#${mediaAssetId}`,
              })
            }}
          </p>
        </div>
        <NextButton
          xs
          faded
          slate
          :label="$t('MEDIA_LIBRARY.CHANGE')"
          @click="showMediaPicker = true"
        />
        <NextButton
          xs
          faded
          ruby
          :label="$t('MEDIA_LIBRARY.REMOVE')"
          @click="clearMedia"
        />
      </div>

      <WootMessageEditor
        v-model="textContent"
        rows="4"
        enable-variables
        :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
        class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
      />
    </template>

    <FollowUpWhatsAppTemplateModal
      v-model:show="showTemplateModal"
      @close="showTemplateModal = false"
      @select="onTemplateSelected"
    />
    <MediaLibraryPicker
      v-if="showMediaPicker"
      :show="showMediaPicker"
      :initial-caption="textContent"
      :selected-media-asset-id="mediaAssetId"
      @close="showMediaPicker = false"
      @select="onMediaSelected"
    />
  </div>
</template>
