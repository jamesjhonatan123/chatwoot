<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MediaLibraryPicker from './MediaLibraryPicker.vue';

const props = defineProps({
  initialFileName: {
    type: String,
    default: '',
  },
  // When true, emit legacy-compatible object for macros send_attachment
  asAttachmentAction: {
    type: Boolean,
    default: false,
  },
});

const model = defineModel({
  type: [Array, Object, String, Number],
  default: null,
});

const store = useStore();
const showPicker = ref(false);
const getMediaAsset = useMapGetter('mediaAssets/getMediaAsset');
const assets = useMapGetter('mediaAssets/getMediaAssets');

const parsedSelection = computed(() => {
  const value = model.value;
  if (!value) return null;

  if (Array.isArray(value) && value.length) {
    const first = value[0];
    if (first && typeof first === 'object') {
      return {
        mediaAssetId: first.media_asset_id || first.mediaAssetId,
        caption: first.caption || '',
      };
    }
    // Legacy numeric blob id
    return { mediaAssetId: null, caption: '', legacyBlobId: first };
  }

  if (typeof value === 'object') {
    return {
      mediaAssetId: value.media_asset_id || value.mediaAssetId,
      caption: value.caption || value.message || '',
    };
  }

  return null;
});

const selectedAsset = computed(() => {
  const id = parsedSelection.value?.mediaAssetId;
  if (!id) return null;
  return getMediaAsset.value(id);
});

const displayName = computed(() => {
  if (selectedAsset.value) {
    return selectedAsset.value.title || selectedAsset.value.file_name;
  }
  if (parsedSelection.value?.legacyBlobId) {
    return props.initialFileName || String(parsedSelection.value.legacyBlobId);
  }
  return props.initialFileName || '';
});

const openPicker = () => {
  showPicker.value = true;
};

const onSelect = ({ mediaAssetId, caption, asset }) => {
  if (props.asAttachmentAction) {
    model.value = [
      {
        media_asset_id: mediaAssetId,
        caption: caption || '',
      },
    ];
    return;
  }

  model.value = {
    ...(typeof model.value === 'object' &&
    model.value !== null &&
    !Array.isArray(model.value)
      ? model.value
      : {}),
    media_asset_id: mediaAssetId,
    message: caption || '',
    media_preview: {
      file_name: asset?.file_name,
      thumb_url: asset?.thumb_url,
      file_url: asset?.file_url,
      file_type: asset?.file_type,
    },
  };
};

const clearSelection = () => {
  model.value = props.asAttachmentAction ? [] : null;
};

const ensureAssetsLoaded = () => {
  if ((assets.value || []).length) return;
  store.dispatch('mediaAssets/get');
};

onMounted(ensureAssetsLoaded);
watch(
  () => parsedSelection.value?.mediaAssetId,
  id => {
    if (id) ensureAssetsLoaded();
  }
);
</script>

<template>
  <div class="flex flex-col gap-2 min-w-0">
    <div
      v-if="displayName"
      class="flex items-center gap-2 p-2 rounded-lg bg-n-alpha-black2"
    >
      <img
        v-if="
          selectedAsset?.file_type === 'image' &&
          (selectedAsset.thumb_url || selectedAsset.file_url)
        "
        :src="selectedAsset.thumb_url || selectedAsset.file_url"
        :alt="displayName"
        class="object-cover w-10 h-10 rounded"
      />
      <div class="flex-1 min-w-0">
        <p class="mb-0 text-sm truncate text-n-slate-12">
          {{
            $t('MEDIA_LIBRARY.SELECTED', {
              name: displayName,
            })
          }}
        </p>
        <p
          v-if="parsedSelection?.caption"
          class="mb-0 text-xs truncate text-n-slate-11"
        >
          {{ parsedSelection.caption }}
        </p>
      </div>
      <NextButton
        xs
        faded
        slate
        :label="$t('MEDIA_LIBRARY.CHANGE')"
        @click="openPicker"
      />
      <NextButton
        xs
        faded
        ruby
        :label="$t('MEDIA_LIBRARY.REMOVE')"
        @click="clearSelection"
      />
    </div>
    <NextButton
      v-else
      xs
      faded
      slate
      icon="i-lucide-images"
      :label="$t('MEDIA_LIBRARY.ATTACH')"
      @click="openPicker"
    />

    <MediaLibraryPicker
      v-if="showPicker"
      :show="showPicker"
      :initial-caption="parsedSelection?.caption || ''"
      :selected-media-asset-id="parsedSelection?.mediaAssetId"
      @close="showPicker = false"
      @select="onSelect"
    />
  </div>
</template>
