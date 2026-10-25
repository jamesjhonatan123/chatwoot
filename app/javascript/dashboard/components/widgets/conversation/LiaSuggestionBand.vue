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

const isShown = computed(() => {
  // handledVersion forca a reavaliacao quando o Set muda.
  const handled =
    handledVersion.value >= 0 && suggestion.value
      ? handledIds.has(suggestion.value.id)
      : false;
  return (
    !!suggestion.value &&
    !handled &&
    !props.isPrivateNote &&
    !props.hasContent &&
    !props.isResolved
  );
});

const markHandled = id => {
  handledIds.add(id);
  handledVersion.value += 1;
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
  } catch (error) {
    if (token === requestToken) suggestion.value = null;
  }
};

const debouncedFetch = useDebounceFn(fetchSuggestion, 800);

watch(
  () => props.conversationId,
  () => {
    requestToken += 1;
    suggestion.value = null;
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

const dismiss = async () => {
  if (!suggestion.value) return;
  const { id } = suggestion.value;
  const conversationId = props.conversationId;
  markHandled(id);
  try {
    await ConversationApi.dismissLiaSuggestion(conversationId, id);
  } catch (error) {
    // Falha ao avisar a LIA nao deve reaparecer na tela.
  }
};

defineExpose({ isShown, useSuggestion });
</script>

<template>
  <div
    v-if="isShown"
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
