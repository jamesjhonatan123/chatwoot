<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const search = ref('');
const fileType = ref('all');
const fileInput = ref(null);

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

const fetchAssets = () => store.dispatch('mediaAssets/get');

onMounted(fetchAssets);

const openUpload = () => fileInput.value?.click();

const onUpload = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;

  try {
    await store.dispatch('mediaAssets/create', { file });
    useAlert(t('MEDIA_LIBRARY.UPLOAD_SUCCESS'));
  } catch (error) {
    useAlert(t('MEDIA_LIBRARY.UPLOAD_ERROR'));
  }
};

const onDelete = async asset => {
  try {
    await store.dispatch('mediaAssets/delete', asset.id);
    useAlert(t('MEDIA_LIBRARY.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('MEDIA_LIBRARY.DELETE_ERROR'));
  }
};

const formatBytes = bytes => {
  if (!bytes) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = bytes;
  let unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  return `${size.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <BaseSettingsHeader
      :title="$t('MEDIA_LIBRARY.HEADER')"
      :description="$t('MEDIA_LIBRARY.DESCRIPTION')"
    >
      <template #actions>
        <NextButton
          solid
          blue
          sm
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
      </template>
    </BaseSettingsHeader>

    <div class="flex flex-wrap items-center gap-2">
      <input
        v-model="search"
        type="search"
        class="flex-1 min-w-[200px] px-3 py-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
        :placeholder="$t('MEDIA_LIBRARY.SEARCH_PLACEHOLDER')"
      />
      <NextButton
        xs
        :solid="fileType === 'all'"
        :faded="fileType !== 'all'"
        :slate="fileType !== 'all'"
        :label="$t('MEDIA_LIBRARY.FILTERS.ALL')"
        @click="fileType = 'all'"
      />
      <NextButton
        xs
        :solid="fileType === 'image'"
        :faded="fileType !== 'image'"
        :slate="fileType !== 'image'"
        :label="$t('MEDIA_LIBRARY.FILTERS.IMAGE')"
        @click="fileType = 'image'"
      />
      <NextButton
        xs
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

    <p v-else-if="!filteredAssets.length" class="mb-0 text-sm text-n-slate-11">
      {{ $t('MEDIA_LIBRARY.EMPTY') }}
    </p>

    <div
      v-else
      class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
    >
      <div
        v-for="asset in filteredAssets"
        :key="asset.id"
        class="flex flex-col overflow-hidden rounded-lg outline outline-1 outline-n-weak bg-n-solid-1"
      >
        <div class="flex items-center justify-center h-32 bg-n-alpha-black2">
          <img
            v-if="
              asset.file_type === 'image' && (asset.thumb_url || asset.file_url)
            "
            :src="asset.thumb_url || asset.file_url"
            :alt="asset.file_name"
            class="object-cover w-full h-full"
          />
          <span v-else class="text-xs font-medium uppercase text-n-slate-11">
            {{ asset.file_type }}
          </span>
        </div>
        <div class="flex flex-col gap-2 p-3">
          <p class="mb-0 text-sm font-medium truncate text-n-slate-12">
            {{ asset.title || asset.file_name }}
          </p>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ formatBytes(asset.byte_size) }}
          </p>
          <NextButton
            xs
            faded
            ruby
            :label="$t('MEDIA_LIBRARY.DELETE')"
            @click="onDelete(asset)"
          />
        </div>
      </div>
    </div>
  </div>
</template>
