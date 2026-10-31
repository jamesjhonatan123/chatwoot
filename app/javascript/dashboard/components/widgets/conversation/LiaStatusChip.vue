<script setup>
// Selo da LIA no cabecalho da conversa: ela esta respondendo na loja desta
// caixa? Clicar abre o motivo completo e o botao de ligar/desligar, que vale
// para a loja inteira. Em 31/10/2026 a LIA ficou o dia calada porque quem
// desligou nao tinha como ver nem religar dali.
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { onClickOutside } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import {
  liaStatusActionKey,
  liaStatusChip,
  liaStatusTone,
} from 'dashboard/helper/liaStatus';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const REFRESH_MS = 60000;
const status = ref(null);
const open = ref(false);
const busy = ref(false);
const message = ref('');
const root = ref(null);
let timer = null;

const tone = computed(() => liaStatusTone(status.value));
const chip = computed(() => {
  const { key, until } = liaStatusChip(status.value);
  return t(key, { until });
});
const actionText = computed(() => {
  const key = liaStatusActionKey(status.value);
  return key ? t(key) : '';
});
const hasStore = computed(() => Boolean(status.value?.store_id));

const load = async () => {
  try {
    const { data } = await ConversationAPI.getLiaStatus(props.conversationId);
    status.value = data;
  } catch {
    status.value = { state: null, label: '' };
  }
};

const toggle = async () => {
  if (!status.value?.action) return;
  busy.value = true;
  message.value = '';
  try {
    const { data } = await ConversationAPI.toggleLiaStatus(
      props.conversationId,
      status.value.action
    );
    status.value = data;
  } catch (error) {
    const data = error?.response?.data || {};
    message.value = data.message || t('LIA_STATUS.ERROR');
    if (data.state) status.value = data;
  } finally {
    busy.value = false;
  }
};

onClickOutside(root, () => {
  open.value = false;
});

watch(
  () => props.conversationId,
  () => {
    open.value = false;
    message.value = '';
    load();
    clearInterval(timer);
    timer = setInterval(load, REFRESH_MS);
  },
  { immediate: true }
);

onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <div v-if="status && status.error !== 'disabled'" ref="root" class="relative">
    <button
      type="button"
      data-test-id="lia-status-chip"
      class="flex items-center gap-1.5 h-8 px-2.5 rounded-lg text-xs font-medium border whitespace-nowrap"
      :class="{
        'border-n-teal-6 text-n-teal-11 bg-n-teal-2': tone === 'ok',
        'border-n-amber-6 text-n-amber-11 bg-n-amber-2': tone === 'warn',
        'border-n-ruby-6 text-n-ruby-11 bg-n-ruby-2': tone === 'danger',
        'border-n-weak text-n-slate-11': tone === 'off',
      }"
      :aria-expanded="open"
      @click="open = !open"
    >
      <span
        class="size-2 rounded-full"
        :class="{
          'bg-n-teal-9': tone === 'ok',
          'bg-n-amber-9': tone === 'warn',
          'bg-n-ruby-9': tone === 'danger',
          'bg-n-slate-8': tone === 'off',
        }"
      />
      {{ chip }}
    </button>
    <div
      v-if="open"
      data-test-id="lia-status-panel"
      class="absolute z-50 mt-1 end-0 w-72 p-3 rounded-xl border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg grid gap-2"
    >
      <p class="m-0 text-sm text-n-slate-12" data-test-id="lia-status-label">
        {{ status.label }}
      </p>
      <p v-if="hasStore" class="m-0 text-xs text-n-slate-11">
        {{ $t('LIA_STATUS.WHOLE_STORE') }}
      </p>
      <button
        v-if="hasStore && actionText"
        type="button"
        data-test-id="lia-status-toggle"
        class="h-8 px-3 rounded-lg text-sm font-medium"
        :class="
          status.action === 'ligar'
            ? 'bg-n-brand text-white'
            : 'border border-n-weak text-n-slate-12'
        "
        :disabled="busy"
        @click="toggle"
      >
        {{ busy ? $t('LIA_STATUS.SAVING') : actionText }}
      </button>
      <p
        v-if="message"
        class="m-0 text-xs text-n-ruby-11"
        data-test-id="lia-status-message"
      >
        {{ message }}
      </p>
    </div>
  </div>
</template>
