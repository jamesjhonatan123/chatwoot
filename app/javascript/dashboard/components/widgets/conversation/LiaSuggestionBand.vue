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
import { splitBySlots, hasSlots } from 'dashboard/helper/liaSlots';

const props = defineProps({
  conversationId: { type: Number, required: true },
  // Id da ultima mensagem recebida do contato; muda quando chega mensagem nova.
  lastIncomingId: { type: Number, default: null },
  isResolved: { type: Boolean, default: false },
  isPrivateNote: { type: Boolean, default: false },
  hasContent: { type: Boolean, default: false },
});

const emit = defineEmits(['use']);

const SLOT_CHIP = 'rounded bg-n-amber-3 px-1 text-n-amber-12';

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
    // Texto montado pela LIA com dado conferido no sistema (cobertura, pedido).
    case 'system':
      return t('LIA_SUGGESTION.SOURCE_SYSTEM');
    // Rascunho escrito pela LIA (uma vez por tipo de pergunta) e conferido pela Jev.
    case 'lia_draft':
      return t('LIA_SUGGESTION.SOURCE_LIA_DRAFT');
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
    case 'lia_draft':
      return t('LIA_SUGGESTION.OPTION_SOURCE_LIA_DRAFT');
    default:
      return '';
  }
};

// A faixa só avisa quando a sugestão (ou alguma opção) traz lacuna permitida.
const suggestionParts = computed(() =>
  splitBySlots(suggestion.value?.text || '')
);
const suggestionHasSlots = computed(() => hasSlots(suggestion.value?.text));
const optionsHaveSlots = computed(() =>
  options.value.some(option => hasSlots(option.text))
);

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

// A LIA escreve o rascunho em segundo plano: a faixa avisa e pergunta de novo.
const isDraftingShown = computed(
  () =>
    !suggestion.value &&
    options.value.length === 0 &&
    reason.value === 'drafting' &&
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

const DRAFT_RETRY_MS = 6000;
const DRAFT_MAX_RETRIES = 10;
let draftTimer = null;

const clearDraftTimer = () => {
  if (draftTimer) clearTimeout(draftTimer);
  draftTimer = null;
};

const fetchSuggestion = async (attempt = 0) => {
  clearDraftTimer();
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
    if (reason.value === 'drafting' && attempt < DRAFT_MAX_RETRIES) {
      draftTimer = setTimeout(
        () => fetchSuggestion(attempt + 1),
        DRAFT_RETRY_MS
      );
    }
  } catch (error) {
    if (token === requestToken) resetState();
  }
};

const debouncedFetch = useDebounceFn(() => fetchSuggestion(0), 800);

watch(
  () => props.conversationId,
  () => {
    requestToken += 1;
    clearDraftTimer();
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
  clearDraftTimer();
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

// Ate duas outras respostas da LIA ao lado da sugestao; clique usa a escolhida.
const alternatives = computed(() => suggestion.value?.alternatives || []);

const useAlternative = alternative => {
  if (!isShown.value) return;
  markHandled(suggestion.value.id);
  emit('use', alternative.text);
};

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
        <span
          v-if="optionsHaveSlots"
          class="ms-1 text-n-amber-11 before:me-1 before:content-['·']"
          data-test-id="lia-slots-hint"
        >
          {{ t('LIA_SUGGESTION.FILL_SLOTS') }}
        </span>
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
              <template
                v-for="(part, partIndex) in splitBySlots(option.text)"
                :key="partIndex"
              >
                <span v-if="part.isSlot" :class="SLOT_CHIP">{{
                  part.text
                }}</span>
                <template v-else>{{ part.text }}</template>
              </template>
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
  <p v-else-if="isDraftingShown" class="mt-2 mb-0 text-xs text-n-slate-10">
    {{ t('LIA_SUGGESTION.DRAFTING') }}
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
        <span
          v-if="suggestionHasSlots"
          class="ms-1 text-n-amber-11 before:me-1 before:content-['·']"
          data-test-id="lia-slots-hint"
        >
          {{ t('LIA_SUGGESTION.FILL_SLOTS') }}
        </span>
      </div>
      <p
        class="mt-0.5 mb-0 line-clamp-4 whitespace-pre-line break-words text-sm text-n-slate-12 hover:line-clamp-none"
        :title="suggestion.text"
      >
        <template v-for="(part, partIndex) in suggestionParts" :key="partIndex">
          <span v-if="part.isSlot" :class="SLOT_CHIP">{{ part.text }}</span>
          <template v-else>{{ part.text }}</template>
        </template>
      </p>
      <div
        v-if="alternatives.length"
        class="mt-1.5 flex flex-col gap-1"
        data-test-id="lia-alternatives"
      >
        <span class="text-[11px] text-n-slate-10">
          {{ t('LIA_SUGGESTION.ALTERNATIVES_TITLE') }}
        </span>
        <button
          v-for="(alternative, index) in alternatives"
          :key="index"
          type="button"
          class="w-full rounded border border-n-violet-4 bg-n-solid-1 px-2 py-0.5 text-start text-sm text-n-slate-12 hover:border-n-violet-6"
          :title="alternative.text"
          @click="useAlternative(alternative)"
        >
          <span class="line-clamp-1 break-words">
            <template
              v-for="(part, partIndex) in splitBySlots(alternative.text)"
              :key="partIndex"
            >
              <span v-if="part.isSlot" :class="SLOT_CHIP">{{ part.text }}</span>
              <template v-else>{{ part.text }}</template>
            </template>
          </span>
        </button>
      </div>
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
