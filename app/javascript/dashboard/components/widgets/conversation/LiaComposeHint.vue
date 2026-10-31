<script setup>
// Autocompletar da LIA: acha como o texto que o atendente começou a digitar termina
// no repertório da loja. O restante aparece apagado no cursor (Editor.vue, pelo
// ghostText); aqui fica só a linha discreta "Tab para completar". Tab aceita, Esc
// esconde.
// Sem nada que continue a frase, uma mensagem curta é lida como atalho: "rede social"
// aponta a resposta pronta que tem essas palavras, e o Tab põe ela inteira no lugar.
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { resolveVariablesInMessage } from 'dashboard/helper/editorHelper';
import { findCompletion, findShortcut } from 'dashboard/helper/liaCompose';

const props = defineProps({
  conversationId: { type: Number, required: true },
  // Texto do editor sem a assinatura.
  typed: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  // Variáveis da conversa ({{contact.name}}…), resolvidas ao usar uma resposta pronta.
  variables: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const store = useStore();
const cannedResponses = useMapGetter('getCannedResponses');
onMounted(() => {
  if (!cannedResponses.value?.length) store.dispatch('getCannedResponse');
});

const library = ref([]);
// Texto que o atendente escondeu com Esc: não volta enquanto for o mesmo.
const dismissedText = ref('');
let requestToken = 0;

const loadLibrary = async () => {
  requestToken += 1;
  const token = requestToken;
  library.value = [];
  dismissedText.value = '';
  try {
    const { data } = await ConversationApi.getLiaComposeLibrary(
      props.conversationId
    );
    if (token === requestToken) library.value = data?.texts || [];
  } catch (error) {
    // Sem repertório o editor segue normal.
  }
};

watch(() => props.conversationId, loadLibrary, { immediate: true });
onBeforeUnmount(() => {
  requestToken += 1;
});

const completion = computed(() => {
  if (props.disabled) return null;
  const found =
    findCompletion(library.value, props.typed) ||
    findShortcut(cannedResponses.value, props.typed);
  return found && found.text !== dismissedText.value ? found : null;
});

const sourceLabel = computed(() => {
  switch (completion.value?.source) {
    case 'quick_reply':
      return t('LIA_SUGGESTION.OPTION_SOURCE_QUICK_REPLY');
    case 'canned':
    case 'canned_keyword':
      return t('LIA_SUGGESTION.OPTION_SOURCE_CANNED');
    case 'history':
      return t('LIA_SUGGESTION.OPTION_SOURCE_HISTORY');
    default:
      return '';
  }
});

// O começo da resposta pronta, numa linha, para conferir antes do Tab.
const preview = computed(() =>
  (
    resolveVariablesInMessage(completion.value?.full || '', props.variables) ||
    ''
  )
    .replace(/[*_~`]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
);

// Devolve o texto completo e o que registrar no envio, ou null sem completar.
const accept = () => {
  const found = completion.value;
  if (!found) return null;
  const message = found.shortCode
    ? resolveVariablesInMessage(found.full, props.variables)
    : found.full;
  return {
    message,
    usage: {
      completion: message,
      source: found.source,
      typed_chars: props.typed.trim().length,
    },
  };
};

const dismiss = () => {
  if (!completion.value) return false;
  dismissedText.value = completion.value.text;
  return true;
};

defineExpose({ completion, accept, dismiss });
</script>

<template>
  <div
    v-if="completion"
    class="mt-1.5 flex items-center gap-1.5 px-3 text-xs text-n-slate-10"
    role="status"
    data-test-id="lia-compose-hint"
    :aria-label="t('LIA_SUGGESTION.COMPOSE_TITLE')"
  >
    <kbd
      class="rounded border border-n-violet-6 bg-n-violet-3 px-1 text-[10px] font-medium text-n-violet-11"
    >
      {{ t('LIA_SUGGESTION.KEY_TAB') }}
    </kbd>
    <template v-if="completion.shortCode">
      <span class="shrink-0">{{
        t('LIA_SUGGESTION.COMPOSE_SHORTCUT_ACCEPT')
      }}</span>
      <span
        class="shrink-0 font-medium text-n-slate-12"
        data-test-id="lia-compose-shortcut"
      >
        {{ completion.shortCode }}
      </span>
      <span class="min-w-0 truncate text-n-slate-9">{{ preview }}</span>
    </template>
    <template v-else>
      <span>{{ t('LIA_SUGGESTION.COMPOSE_ACCEPT') }}</span>
      <span v-if="sourceLabel" class="text-n-slate-9">{{ sourceLabel }}</span>
      <!-- O restante aparece apagado dentro do editor; aqui só para leitor de tela. -->
      <span class="sr-only">{{ completion.rest }}</span>
    </template>
  </div>
</template>
