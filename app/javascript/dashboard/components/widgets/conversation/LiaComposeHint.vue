<script setup>
// Autocompletar da LIA: mostra, logo abaixo do editor, como o texto que o atendente
// começou a digitar termina no repertório da loja. Tab aceita, Esc esconde.
import { computed, ref, watch, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { findCompletion } from 'dashboard/helper/liaCompose';

const props = defineProps({
  conversationId: { type: Number, required: true },
  // Texto do editor sem a assinatura.
  typed: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const { t } = useI18n();

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
  const found = findCompletion(library.value, props.typed);
  return found && found.text !== dismissedText.value ? found : null;
});

const sourceLabel = computed(() => {
  switch (completion.value?.source) {
    case 'quick_reply':
      return t('LIA_SUGGESTION.OPTION_SOURCE_QUICK_REPLY');
    case 'canned':
      return t('LIA_SUGGESTION.OPTION_SOURCE_CANNED');
    case 'history':
      return t('LIA_SUGGESTION.OPTION_SOURCE_HISTORY');
    default:
      return '';
  }
});

// Devolve o texto completo e o que registrar no envio, ou null sem completar.
const accept = () => {
  const found = completion.value;
  if (!found) return null;
  return {
    message: found.full,
    usage: {
      completion: found.full,
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
    class="mt-2 flex items-start gap-2 rounded-md border border-dashed border-n-violet-5 px-2.5 py-1.5"
    role="status"
    data-test-id="lia-compose-hint"
    :aria-label="t('LIA_SUGGESTION.COMPOSE_TITLE')"
  >
    <kbd
      class="mt-0.5 flex-shrink-0 rounded border border-n-violet-6 bg-n-violet-3 px-1 text-[10px] font-medium text-n-violet-11"
    >
      {{ t('LIA_SUGGESTION.KEY_TAB') }}
    </kbd>
    <p
      class="m-0 min-w-0 flex-1 line-clamp-2 whitespace-pre-line break-words text-sm text-n-slate-10 before:text-n-slate-9 before:content-['…']"
      :title="completion.text"
    >
      {{ completion.rest }}
    </p>
    <span
      v-if="sourceLabel"
      class="mt-0.5 flex-shrink-0 text-[11px] text-n-slate-10"
    >
      {{ sourceLabel }}
    </span>
  </div>
</template>
