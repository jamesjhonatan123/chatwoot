<script>
// Ids ja usados ou descartados: sobrevivem a troca de conversa enquanto a aba estiver aberta.
const handledIds = new Set();
</script>

<script setup>
import { computed, ref, watch, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';

const props = defineProps({
  conversationId: { type: Number, required: true },
  // Id da ultima mensagem recebida do contato; muda quando chega mensagem nova.
  lastIncomingId: { type: Number, default: null },
  isResolved: { type: Boolean, default: false },
  isPrivateNote: { type: Boolean, default: false },
  hasContent: { type: Boolean, default: false },
});

const emit = defineEmits(['use']);

const { t } = useI18n();

const suggestion = ref(null);
const options = ref([]);
const optionsId = ref(null);
const reason = ref('');
const handledVersion = ref(0);
let requestToken = 0;

const sourceLabel = computed(() => {
  switch (suggestion.value?.source) {
    case 'canned':
      return t('LIA_SUGGESTION.SOURCE_CANNED');
    case 'quick_reply':
      return t('LIA_SUGGESTION.SOURCE_QUICK_REPLY');
    case 'history':
      return t('LIA_SUGGESTION.SOURCE_HISTORY');
    default:
      return '';
  }
});

const optionSourceLabel = source => {
  switch (source) {
    case 'canned':
      return t('LIA_SUGGESTION.OPTION_SOURCE_CANNED');
    case 'quick_reply':
      return t('LIA_SUGGESTION.OPTION_SOURCE_QUICK_REPLY');
    case 'history':
      return t('LIA_SUGGESTION.OPTION_SOURCE_HISTORY');
    default:
      return '';
  }
};

const canDisplay = computed(
  () => !props.isPrivateNote && !props.hasContent && !props.isResolved
);

const isShown = computed(() => {
  // handledVersion forca a reavaliacao quando o Set muda.
  const handled =
    handledVersion.value >= 0 && suggestion.value
      ? handledIds.has(suggestion.value.id)
      : false;
  return !!suggestion.value && !handled && canDisplay.value;
});

const isOptionsShown = computed(() => {
  const handled =
    handledVersion.value >= 0 && optionsId.value
      ? handledIds.has(optionsId.value)
      : false;
  return (
    !suggestion.value &&
    options.value.length > 0 &&
    !!optionsId.value &&
    !handled &&
    canDisplay.value
  );
});

const isNoticeShown = computed(
  () =>
    !suggestion.value &&
    options.value.length === 0 &&
    ['low_confidence', 'no_candidates'].includes(reason.value) &&
    canDisplay.value
);

const markHandled = id => {
  handledIds.add(id);
  handledVersion.value += 1;
};

const resetState = () => {
  suggestion.value = null;
  options.value = [];
  optionsId.value = null;
  reason.value = '';
};

const fetchSuggestion = async () => {
  requestToken += 1;
  const token = requestToken;
  const conversationId = props.conversationId;
  try {
    const { data } = await ConversationApi.getLiaSuggestion(conversationId);
    // Descarta resposta atrasada: a conversa ou a mensagem mudou enquanto esperava.
    if (token !== requestToken) return;
    suggestion.value = data?.suggestion || null;
    options.value = data?.options || [];
    optionsId.value = data?.options_id || null;
    reason.value = data?.reason || '';
  } catch (error) {
    if (token === requestToken) resetState();
  }
};

const debouncedFetch = useDebounceFn(fetchSuggestion, 800);

watch(
  () => props.conversationId,
  () => {
    requestToken += 1;
    resetState();
  }
);

watch(
  () => [props.conversationId, props.lastIncomingId],
  () => debouncedFetch(),
  { immediate: true }
);

onBeforeUnmount(() => {
  requestToken += 1;
});

// Devolve true quando a sugestao foi aplicada (o ReplyBox usa para consumir o Tab).
const useSuggestion = () => {
  if (!isShown.value) return false;
  const { id, text } = suggestion.value;
  markHandled(id);
  emit('use', text);
  return true;
};

const discard = async id => {
  const conversationId = props.conversationId;
  markHandled(id);
  try {
    await ConversationApi.dismissLiaSuggestion(conversationId, id);
  } catch (error) {
    // Falha ao avisar a LIA nao deve reaparecer na tela.
  }
};

const dismiss = () => (suggestion.value ? discard(suggestion.value.id) : null);

const dismissOptions = () =>
  optionsId.value ? discard(optionsId.value) : null;

// Clique numa opcao: insere o texto e esconde a faixa (sem Tab para opcoes).
const useOption = option => {
  if (!isOptionsShown.value) return;
  markHandled(optionsId.value);
  emit('use', option.text);
};

defineExpose({ isShown, useSuggestion });
</script>

<template>
  <div
    v-if="isOptionsShown"
    class="mt-2 flex items-start gap-2 rounded-md border border-n-weak bg-n-alpha-1 py-2 ps-2.5 pe-1.5"
    role="region"
    :aria-label="t('LIA_SUGGESTION.OPTIONS_TITLE')"
  >
    <span
      class="i-lucide-sparkles mt-0.5 size-4 flex-shrink-0 text-n-violet-9"
    />
    <div class="min-w-0 flex-1">
      <div class="text-xs font-medium text-n-slate-11">
        {{ t('LIA_SUGGESTION.OPTIONS_TITLE') }}
      </div>
      <ul class="m-0 mt-1 flex list-none flex-col gap-1 p-0">
        <li v-for="(option, index) in options" :key="index">
          <button
            type="button"
            class="w-full rounded border border-n-weak bg-n-solid-1 px-2 py-1 text-start hover:border-n-violet-6 hover:bg-n-violet-2"
            :title="option.text"
            @click="useOption(option)"
          >
            <span
              class="line-clamp-2 block whitespace-pre-line break-words text-sm text-n-slate-12"
            >
              {{ option.text }}
            </span>
            <span
              v-if="optionSourceLabel(option.source)"
              class="block text-[11px] text-n-slate-10"
            >
              {{ optionSourceLabel(option.source) }}
            </span>
          </button>
        </li>
      </ul>
    </div>
    <Button
      ghost
      xs
      slate
      icon="i-lucide-x"
      :aria-label="t('LIA_SUGGESTION.OPTIONS_DISMISS')"
      :title="t('LIA_SUGGESTION.OPTIONS_DISMISS')"
      @click="dismissOptions"
    />
  </div>
  <p v-else-if="isNoticeShown" class="mt-2 mb-0 text-xs text-n-slate-10">
    {{ t('LIA_SUGGESTION.NO_SAFE_SUGGESTION') }}
  </p>
  <div
    v-else-if="isShown"
    class="mt-2 flex items-start gap-2 rounded-md border border-n-violet-5 bg-n-violet-2 py-2 ps-2.5 pe-1.5"
    role="region"
    :aria-label="t('LIA_SUGGESTION.TITLE')"
  >
    <span
      class="i-lucide-sparkles mt-0.5 size-4 flex-shrink-0 text-n-violet-11"
    />
    <div class="min-w-0 flex-1">
      <div class="text-xs text-n-slate-11">
        <span class="font-medium text-n-violet-11">
          {{ t('LIA_SUGGESTION.TITLE') }}
        </span>
        <span v-if="sourceLabel"> · {{ sourceLabel }}</span>
      </div>
      <p
        class="mt-0.5 mb-0 line-clamp-4 whitespace-pre-line break-words text-sm text-n-slate-12 hover:line-clamp-none"
        :title="suggestion.text"
      >
        {{ suggestion.text }}
      </p>
    </div>
    <div class="flex flex-shrink-0 items-center gap-1">
      <Button
        xs
        solid
        color="blue"
        class="!bg-n-violet-9 !text-white"
        :label="t('LIA_SUGGESTION.USE')"
        @click="useSuggestion"
      />
      <kbd
        class="rounded border border-n-violet-6 bg-n-violet-3 px-1 text-[10px] font-medium text-n-violet-11"
      >
        {{ t('LIA_SUGGESTION.KEY_TAB') }}
      </kbd>
      <Button
        ghost
        xs
        slate
        icon="i-lucide-x"
        :aria-label="t('LIA_SUGGESTION.DISMISS')"
        :title="t('LIA_SUGGESTION.DISMISS')"
        @click="dismiss"
      />
    </div>
  </div>
</template>
