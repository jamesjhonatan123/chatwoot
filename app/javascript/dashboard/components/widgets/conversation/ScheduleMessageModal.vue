<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import MediaLibraryPicker from 'dashboard/components/widgets/mediaLibrary/MediaLibraryPicker.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
  // Prefill from reply box or template modal
  content: {
    type: String,
    default: '',
  },
  isPrivate: {
    type: Boolean,
    default: false,
  },
  templateParams: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'scheduled']);

const { t } = useI18n();
const store = useStore();

const scheduledAt = ref('');
const showMediaPicker = ref(false);
const selectedMedia = ref(null);
const captionOverride = ref('');

const localShow = computed({
  get: () => props.show,
  set: value => {
    if (!value) emit('close');
  },
});

const uiFlags = useMapGetter('scheduledMessages/getUIFlags');
const getScheduledMessages = useMapGetter(
  'scheduledMessages/getScheduledMessagesByConversation'
);

const isCreating = computed(() => uiFlags.value.isCreating);
const isFetching = computed(() => uiFlags.value.isFetching);
const messages = computed(() =>
  getScheduledMessages.value(props.conversationId)
);

const minDateTime = computed(() => {
  const date = new Date();
  date.setMinutes(date.getMinutes() + 1);
  date.setSeconds(0, 0);
  const offset = date.getTimezoneOffset();
  const local = new Date(date.getTime() - offset * 60_000);
  return local.toISOString().slice(0, 16);
});

const previewContent = computed(() => {
  if (selectedMedia.value) {
    return (captionOverride.value || props.content || '').trim();
  }
  return props.content?.trim() || '';
});

const canSubmit = computed(
  () =>
    (previewContent.value.length > 0 || selectedMedia.value) &&
    scheduledAt.value &&
    !isCreating.value
);

const formatScheduledAt = timestamp => {
  if (!timestamp) return '';
  return new Date(timestamp * 1000).toLocaleString();
};

const isTemplate = computed(
  () => props.templateParams && Object.keys(props.templateParams).length > 0
);

const isMessagePrivate = message =>
  Boolean(message?.is_private ?? message?.private);

watch(
  () => props.show,
  visible => {
    if (!visible) return;
    scheduledAt.value = minDateTime.value;
    selectedMedia.value = null;
    captionOverride.value = props.content || '';
    store.dispatch('scheduledMessages/get', {
      conversationId: props.conversationId,
    });
  }
);

const onClose = () => emit('close');

const onMediaSelected = ({ mediaAssetId, caption, asset }) => {
  selectedMedia.value = {
    id: mediaAssetId,
    caption,
    ...asset,
  };
  captionOverride.value = caption || captionOverride.value;
};

const clearMedia = () => {
  selectedMedia.value = null;
};

const onConfirm = async () => {
  if (!canSubmit.value) return;

  try {
    await store.dispatch('scheduledMessages/create', {
      conversationId: props.conversationId,
      content: previewContent.value,
      private: props.isPrivate,
      scheduledAt: new Date(scheduledAt.value).toISOString(),
      templateParams: props.templateParams || {},
      mediaAssetIds: selectedMedia.value ? [selectedMedia.value.id] : [],
    });
    useAlert(t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CREATE_SUCCESS'));
    emit('scheduled');
    onClose();
  } catch (error) {
    useAlert(t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CREATE_ERROR'));
  }
};

const onCancel = async id => {
  try {
    await store.dispatch('scheduledMessages/delete', {
      conversationId: props.conversationId,
      id,
    });
    useAlert(t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CANCEL_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CANCEL_ERROR'));
  }
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="medium">
    <woot-modal-header
      :header-title="$t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.MODAL_TITLE')"
      :header-content="
        isPrivate
          ? $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.MODAL_SUBTITLE_PRIVATE')
          : $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.MODAL_SUBTITLE')
      "
    />
    <div class="flex flex-col gap-4 px-4 pb-6 sm:px-8">
      <div
        v-if="previewContent || selectedMedia"
        class="p-3 text-sm whitespace-pre-wrap break-words rounded-lg text-n-slate-12"
        :class="
          isPrivate
            ? 'bg-n-amber-3/60 outline outline-1 outline-n-amber-6'
            : 'bg-n-alpha-black2'
        "
      >
        <div class="flex flex-wrap gap-1.5 mb-2">
          <span
            v-if="isPrivate"
            class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded bg-n-amber-9/15 text-n-amber-11"
          >
            <span class="i-lucide-lock size-3" />
            {{ $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.PRIVATE_BADGE') }}
          </span>
          <span
            v-if="isTemplate"
            class="inline-block px-2 py-0.5 text-xs rounded bg-n-brand/10 text-n-blue-11"
          >
            {{ $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.TEMPLATE_BADGE') }}
          </span>
        </div>
        <div v-if="selectedMedia" class="flex items-center gap-2 mb-2">
          <img
            v-if="
              selectedMedia.file_type === 'image' &&
              (selectedMedia.thumb_url || selectedMedia.file_url)
            "
            :src="selectedMedia.thumb_url || selectedMedia.file_url"
            :alt="selectedMedia.file_name"
            class="object-cover w-12 h-12 rounded"
          />
          <span class="text-sm text-n-slate-12">
            {{
              $t('MEDIA_LIBRARY.SELECTED', {
                name: selectedMedia.file_name || `#${selectedMedia.id}`,
              })
            }}
          </span>
          <NextButton
            xs
            faded
            ruby
            :label="$t('MEDIA_LIBRARY.REMOVE')"
            @click="clearMedia"
          />
        </div>
        {{ previewContent }}
      </div>

      <div v-if="!isTemplate" class="flex flex-wrap gap-2">
        <NextButton
          xs
          faded
          slate
          icon="i-lucide-images"
          :label="$t('MEDIA_LIBRARY.ATTACH')"
          @click="showMediaPicker = true"
        />
      </div>

      <div v-if="selectedMedia && !isTemplate" class="flex flex-col gap-1">
        <label class="text-xs text-n-slate-11">
          {{ $t('MEDIA_LIBRARY.CAPTION_LABEL') }}
        </label>
        <textarea
          v-model="captionOverride"
          rows="3"
          class="px-3 py-2 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12"
          :placeholder="$t('MEDIA_LIBRARY.CAPTION_PLACEHOLDER')"
        />
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.DATETIME_LABEL') }}
        </label>
        <input
          v-model="scheduledAt"
          type="datetime-local"
          :min="minDateTime"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand"
        />
      </div>

      <div class="flex justify-end gap-2">
        <NextButton
          faded
          slate
          :label="$t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CANCEL')"
          @click="onClose"
        />
        <NextButton
          solid
          :color="isPrivate ? 'amber' : 'blue'"
          icon="i-lucide-calendar-clock"
          :disabled="!canSubmit"
          :is-loading="isCreating"
          :label="$t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CONFIRM')"
          @click="onConfirm"
        />
      </div>

      <div class="pt-2 border-t border-n-weak">
        <h4 class="mb-2 text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.PENDING_TITLE') }}
        </h4>
        <div v-if="isFetching" class="flex justify-center py-4">
          <Spinner />
        </div>
        <p v-else-if="!messages.length" class="mb-0 text-sm text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.EMPTY') }}
        </p>
        <ul v-else class="flex flex-col gap-2 m-0 list-none">
          <li
            v-for="message in messages"
            :key="message.id"
            class="flex items-start justify-between gap-2 p-3 rounded-lg outline outline-1"
            :class="
              isMessagePrivate(message)
                ? 'outline-n-amber-6 bg-n-amber-3/40'
                : 'outline-n-weak'
            "
          >
            <div class="flex flex-col gap-1 min-w-0">
              <div class="flex flex-wrap items-center gap-1.5">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ formatScheduledAt(message.scheduled_at) }}
                </span>
                <span
                  v-if="isMessagePrivate(message)"
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 text-xs font-medium rounded bg-n-amber-9/20 text-n-amber-11"
                >
                  <span class="i-lucide-lock size-3" />
                  {{
                    $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.PRIVATE_BADGE')
                  }}
                </span>
                <span
                  v-if="
                    message.template_params &&
                    Object.keys(message.template_params).length
                  "
                  class="inline-block px-1.5 py-0.5 text-xs rounded bg-n-brand/10 text-n-blue-11"
                >
                  {{
                    $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.TEMPLATE_BADGE')
                  }}
                </span>
                <span
                  v-if="message.media_asset_ids?.length"
                  class="inline-block px-1.5 py-0.5 text-xs rounded bg-n-slate-3 text-n-slate-11"
                >
                  {{ $t('MEDIA_LIBRARY.ATTACH') }}
                </span>
              </div>
              <p
                class="mb-0 text-sm whitespace-pre-wrap break-words text-n-slate-12"
              >
                {{ message.content }}
              </p>
            </div>
            <NextButton
              xs
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="
                $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.CANCEL_SCHEDULE')
              "
              @click="onCancel(message.id)"
            />
          </li>
        </ul>
      </div>
    </div>
  </woot-modal>

  <MediaLibraryPicker
    v-if="showMediaPicker"
    :show="showMediaPicker"
    :initial-caption="captionOverride || content"
    :selected-media-asset-id="selectedMedia?.id"
    @close="showMediaPicker = false"
    @select="onMediaSelected"
  />
</template>
