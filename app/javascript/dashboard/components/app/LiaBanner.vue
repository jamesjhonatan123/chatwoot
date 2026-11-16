<script setup>
// Faixa no topo de todas as telas quando a LIA esta parada numa loja. Em 16/11/2026
// a LIA ficou desligada numa loja das 13h10 a meia-noite e so via quem abria uma
// conversa daquela loja. Nao tem botao de fechar: some sozinha quando a LIA volta.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import LiaOverviewAPI from 'dashboard/api/liaOverview';
import { useLiaOverview } from 'dashboard/composables/useLiaOverview';
import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  bannerStores,
  bannerTone,
  waitingFor,
} from 'dashboard/helper/liaOverview';

const { t } = useI18n();
const route = useRoute();
const { overview, refresh } = useLiaOverview();
const busy = ref(false);
const error = ref('');

const stores = computed(() => bannerStores(overview.value));
const tone = computed(() => bannerTone(stores.value));
const waiting = computed(() =>
  stores.value.reduce((total, store) => total + (store.waiting_count || 0), 0)
);
const oldest = computed(() => {
  const dates = stores.value
    .map(store => store.oldest_waiting_since)
    .filter(Boolean)
    .sort();
  return dates.length ? waitingFor(dates[0]).text : '';
});
const single = computed(() =>
  stores.value.length === 1 ? stores.value[0] : null
);
const headline = computed(() =>
  single.value
    ? t('LIA_OVERVIEW.BANNER_ONE', { name: single.value.name })
    : t('LIA_OVERVIEW.BANNER_MANY', { count: stores.value.length })
);
// "Em silêncio até meia-noite: desligada por Brenda. · 7 clientes esperando, o mais
// antigo há 1h 14." O estado vem pronto da LIA.
const detail = computed(() => {
  const state = single.value
    ? `${single.value.label}.`
    : `${stores.value.map(store => `${store.name} (${store.label})`).join('; ')}.`;
  if (!waiting.value) return `${state} · ${t('LIA_OVERVIEW.BANNER_NOBODY')}`;
  const count = t(
    'LIA_OVERVIEW.BANNER_WAITING',
    { count: waiting.value },
    waiting.value
  );
  const oldestText = oldest.value
    ? `, ${t('LIA_OVERVIEW.BANNER_OLDEST', { wait: oldest.value })}`
    : '';
  return `${state} · ${count}${oldestText}.`;
});
const waitingUrl = computed(() =>
  frontendURL(`accounts/${route.params.accountId}/lia-waiting`)
);

const turnOn = async store => {
  busy.value = true;
  error.value = '';
  try {
    await LiaOverviewAPI.toggle(store.store_id, 'ligar');
    await refresh();
  } catch {
    error.value = t('LIA_OVERVIEW.TURN_ON_ERROR');
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <div
    v-if="stores.length"
    data-test-id="lia-banner"
    :role="tone === 'red' ? 'alert' : 'status'"
    class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-2 text-sm border-b"
    :class="
      tone === 'red'
        ? 'bg-n-ruby-3 border-n-ruby-6 text-n-ruby-11'
        : 'bg-n-amber-3 border-n-amber-6 text-n-amber-11'
    "
  >
    <span
      class="size-2 rounded-full shrink-0"
      :class="tone === 'red' ? 'bg-n-ruby-9' : 'bg-n-amber-9'"
    />
    <span class="flex-1 min-w-[15rem]" data-test-id="lia-banner-text">
      <strong class="text-n-slate-12">{{ headline }}</strong>
      {{ `· ${detail}` }}
      <span v-if="error" class="ms-2 font-medium">{{ error }}</span>
    </span>
    <router-link
      v-if="waiting"
      :to="waitingUrl"
      class="inline-flex items-center h-7 px-3 rounded-lg text-xs font-medium text-white bg-n-ruby-9 hover:opacity-90"
    >
      {{ t('LIA_OVERVIEW.SEE_WAITING') }}
    </router-link>
    <button
      v-if="single && single.action === 'ligar'"
      type="button"
      :disabled="busy"
      class="inline-flex items-center h-7 px-3 rounded-lg text-xs font-medium border border-n-strong text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-60"
      @click="turnOn(single)"
    >
      {{ t('LIA_OVERVIEW.TURN_ON') }}
    </button>
  </div>
</template>
