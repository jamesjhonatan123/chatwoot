<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  initialCaption: {
    type: String,
    default: '',
  },
  selectedMediaAssetId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['close', 'select']);

const { t } = useI18n();
const store = useStore();

const search = ref('');
const fileType = ref('all');
const caption = ref('');
const selectedId = ref(null);
const fileInput = ref(null);
const isConfirming = ref(false);

const uiFlags = useMapGetter('mediaAssets/getUIFlags');
const assets = useMapGetter('mediaAssets/getMediaAssets');

const isFetching = computed(() => uiFlags.value.isFetching);
const isCreating = computed(() => uiFlags.value.isCreating);

const filteredAssets = computed(() => {
  let list = assets.value || [];
  if (fileType.value === 'image') {
    list = list.filter(item => item.file_type === 'image');
  } else if (fileType.value === 'file') {
    list = list.filter(item => item.file_type !== 'image');
  }
  if (!search.value.trim()) return list;
  const query = search.value.trim().toLowerCase();
  return list.filter(item =>
    [item.file_name, item.title]
      .filter(Boolean)
      .some(value => value.toLowerCase().includes(query))
  );
});

const selectedAsset = computed(() =>
  (assets.value || []).find(
    item => Number(item.id) === Number(selectedId.value)
  )
);

const canConfirm = computed(
  () => Boolean(selectedAsset.value) && !isConfirming.value
);

watch(
  () => props.show,
  visible => {
    if (!visible) {
      isConfirming.value = false;
      return;
    }
    caption.value = props.initialCaption || '';
    selectedId.value = props.selectedMediaAssetId || null;
    isConfirming.value = false;
    store.dispatch('mediaAssets/get');
  },
  { immediate: true }
);

const onClose = () => {
  isConfirming.value = false;
  emit('close');
};

const openUpload = () => fileInput.value?.click();

const selectAsset = asset => {
  selectedId.value = asset.id;
};

const onUpload = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;

  try {
    const asset = await store.dispatch('mediaAssets/create', { file });
    selectedId.value = asset.id;
    useAlert(t('MEDIA_LIBRARY.UPLOAD_SUCCESS'));
  } catch (error) {
    useAlert(t('MEDIA_LIBRARY.UPLOAD_ERROR'));
  }
};

const onConfirm = () => {
  if (!selectedAsset.value || isConfirming.value) {
    if (!selectedAsset.value) useAlert(t('MEDIA_LIBRARY.NO_SELECTION'));
    return;
  }

  isConfirming.value = true;

  const payload = {
    mediaAssetId: selectedAsset.value.id,
    caption: caption.value,
    asset: { ...selectedAsset.value },
  };

  // Close first so the modal unmounts before the parent handles the selection.
  emit('close');
  emit('select', payload);
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="onClose"
    size="medium"
    @update:show="value => !value && onClose()"
  >
    <woot-modal-header
      :header-title="$t('MEDIA_LIBRARY.PICKER_TITLE')"
      :header-content="$t('MEDIA_LIBRARY.PICKER_SUBTITLE')"
    />
    <div class="flex flex-col gap-4 px-4 pb-6 sm:px-8">
      <div class="flex flex-wrap items-center gap-2">
        <input
          v-model="search"
          type="search"
          class="flex-1 min-w-[160px] px-3 py-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
          :placeholder="$t('MEDIA_LIBRARY.SEARCH_PLACEHOLDER')"
        />
        <NextButton
          xs
          solid
          blue
          type="button"
          :label="$t('MEDIA_LIBRARY.HEADER_BTN_TXT')"
          :is-loading="isCreating"
          @click="openUpload"
        />
        <input
          ref="fileInput"
          type="file"
          class="hidden"
          accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.csv,.txt,.zip"
          @change="onUpload"
        />
      </div>

      <div class="flex flex-wrap gap-2">
        <NextButton
          xs
          type="button"
          :solid="fileType === 'all'"
          :faded="fileType !== 'all'"
          :slate="fileType !== 'all'"
          :label="$t('MEDIA_LIBRARY.FILTERS.ALL')"
          @click="fileType = 'all'"
        />
        <NextButton
          xs
          type="button"
          :solid="fileType === 'image'"
          :faded="fileType !== 'image'"
          :slate="fileType !== 'image'"
          :label="$t('MEDIA_LIBRARY.FILTERS.IMAGE')"
          @click="fileType = 'image'"
        />
        <NextButton
          xs
          type="button"
          :solid="fileType === 'file'"
          :faded="fileType !== 'file'"
          :slate="fileType !== 'file'"
          :label="$t('MEDIA_LIBRARY.FILTERS.FILE')"
          @click="fileType = 'file'"
        />
      </div>

      <div v-if="isFetching" class="flex justify-center py-8">
        <Spinner />
      </div>

      <p
        v-else-if="!filteredAssets.length"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ $t('MEDIA_LIBRARY.EMPTY') }}
      </p>

      <div
        v-else
        class="grid grid-cols-2 gap-2 overflow-y-auto max-h-72 sm:grid-cols-3"
      >
        <button
          v-for="asset in filteredAssets"
          :key="asset.id"
          type="button"
          class="flex flex-col overflow-hidden text-left rounded-lg outline outline-1 transition-colors"
          :class="
            Number(selectedId) === Number(asset.id)
              ? 'outline-n-brand bg-n-alpha-2'
              : 'outline-n-weak bg-n-solid-1'
          "
          @click="selectAsset(asset)"
        >
          <div class="flex items-center justify-center h-24 bg-n-alpha-black2">
            <img
              v-if="
                asset.file_type === 'image' &&
                (asset.thumb_url || asset.file_url)
              "
              :src="asset.thumb_url || asset.file_url"
              :alt="asset.file_name"
              class="object-cover w-full h-full"
            />
            <span v-else class="text-xs font-medium uppercase text-n-slate-11">
              {{ asset.file_type }}
            </span>
          </div>
          <span class="p-2 text-xs truncate text-n-slate-12">
            {{ asset.title || asset.file_name }}
          </span>
        </button>
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-xs text-n-slate-11">
          {{ $t('MEDIA_LIBRARY.CAPTION_LABEL') }}
        </label>
        <textarea
          v-model="caption"
          rows="3"
          class="px-3 py-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
          :placeholder="$t('MEDIA_LIBRARY.CAPTION_PLACEHOLDER')"
        />
      </div>

      <div class="flex justify-end gap-2">
        <NextButton
          sm
          faded
          slate
          type="button"
          :label="$t('MEDIA_LIBRARY.PICKER_CANCEL')"
          @click="onClose"
        />
        <NextButton
          sm
          solid
          blue
          type="button"
          :label="$t('MEDIA_LIBRARY.PICKER_CONFIRM')"
          :disabled="!canConfirm"
          :is-loading="isConfirming"
          @click="onConfirm"
        />
      </div>
    </div>
  </woot-modal>
</template>
