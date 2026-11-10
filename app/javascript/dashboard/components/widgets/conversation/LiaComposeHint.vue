<script setup>
// Autocompletar da LIA: acha como o texto que o atendente começou a digitar termina
// no repertório da loja. O restante aparece apagado no cursor (Editor.vue, pelo
// ghostText); aqui fica só a linha discreta "Tab para completar". Tab aceita, Esc
// esconde.
// Sem nada que continue a frase, uma mensagem curta é lida como atalho: "rede social"
// aponta a resposta pronta que tem essas palavras, e o Tab põe ela inteira no lugar.
// Quando nem o repertório nem o atalho servem e a loja tem o autocompletar escrito
// pela LIA, o painel pede a continuação à LIA depois de uma pausa na digitação: ela
// lê a conversa e devolve o texto do time que encaixa no que foi começado.
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { resolveVariablesInMessage } from 'dashboard/helper/editorHelper';
import {
  findCompletion,
  findShortcut,
  continueGenerated,
  MIN_GENERATED_CHARS,
} from 'dashboard/helper/liaCompose';

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
// A loja tem o autocompletar escrito pela LIA (vem junto com o repertório).
const generative = ref(false);
// Última continuação que a LIA devolveu: { typed, rest }.
const generated = ref(null);
// Texto que o atendente escondeu com Esc: não volta enquanto for o mesmo.
const dismissedText = ref('');
let requestToken = 0;
let generateToken = 0;

const loadLibrary = async () => {
  requestToken += 1;
  generateToken += 1;
  const token = requestToken;
  library.value = [];
  generative.value = false;
  generated.value = null;
  dismissedText.value = '';
  try {
    const { data } = await ConversationApi.getLiaComposeLibrary(
      props.conversationId
    );
    if (token !== requestToken) return;
    library.value = data?.texts || [];
    generative.value = data?.generative === true;
  } catch (error) {
    // Sem repertório o editor segue normal.
  }
};

watch(() => props.conversationId, loadLibrary, { immediate: true });
onBeforeUnmount(() => {
  requestToken += 1;
  generateToken += 1;
});

// O que o repertório e o atalho já resolvem no navegador, sem ida ao servidor.
const local = computed(
  () =>
    findCompletion(library.value, props.typed) ||
    findShortcut(cannedResponses.value, props.typed)
);

const completion = computed(() => {
  if (props.disabled) return null;
  const found =
    local.value || continueGenerated(generated.value, props.typed) || null;
  return found && found.text !== dismissedText.value ? found : null;
});

// Pausa de digitação antes de pedir à LIA: cada pedido é uma chamada de modelo.
const GENERATE_PAUSE_MS = 450;

const requestGenerated = useDebounceFn(async () => {
  const typed = props.typed;
  if (
    !generative.value ||
    props.disabled ||
    local.value ||
    typed.trim().length < MIN_GENERATED_CHARS ||
    continueGenerated(generated.value, typed)
  ) {
    return;
  }
  generateToken += 1;
  const token = generateToken;
  const conversationId = props.conversationId;
  try {
    const { data } = await ConversationApi.completeLiaCompose(
      conversationId,
      typed
    );
    // O texto mudou (ou a conversa) enquanto a LIA respondia: a resposta não vale mais.
    if (token !== generateToken || conversationId !== props.conversationId) {
      return;
    }
    generated.value = data?.completion
      ? { typed, rest: data.completion }
      : null;
  } catch (error) {
    // Sem a LIA o editor segue normal.
  }
}, GENERATE_PAUSE_MS);

watch(
  () => props.typed,
  typed => {
    // Continuação que não bate mais com o que foi digitado some na hora.
    if (generated.value && !continueGenerated(generated.value, typed)) {
      generated.value = null;
      generateToken += 1;
    }
    if (generative.value) requestGenerated();
  }
);

const sourceLabel = computed(() => {
  switch (completion.value?.source) {
    case 'quick_reply':
      return t('LIA_SUGGESTION.OPTION_SOURCE_QUICK_REPLY');
    case 'canned':
    case 'canned_keyword':
      return t('LIA_SUGGESTION.OPTION_SOURCE_CANNED');
    case 'history':
      return t('LIA_SUGGESTION.OPTION_SOURCE_HISTORY');
    case 'lia':
      return t('LIA_SUGGESTION.COMPOSE_SOURCE_LIA');
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
