<script setup>
// Painel da LIA (primeiro item do menu). Os numeros vem da LIA via lia_panels_controller.rb,
// so das caixas do atendente; a fila "Esperando a equipe" e a mesma da faixa (useLiaOverview).
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import LiaPanelAPI from 'dashboard/api/liaPanel';
import { useLiaOverview } from 'dashboard/composables/useLiaOverview';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { waitingFor } from 'dashboard/helper/liaOverview';
import {
  CATEGORY_KEYS,
  LINK_KEYS,
  STAGE_KEYS,
  TABS,
  ago,
  autonomyDelta,
  filterRows,
  minutesSince,
  pct,
  waitingForStore,
  waitingTotal,
  csvCell,
} from 'dashboard/helper/liaPanel';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const REFRESH_MS = 60000;
const PERIODS = ['hoje', '7d', '30d'];
const QUEUE_LIMIT = 8;

const { t } = useI18n();
const route = useRoute();
const { overview } = useLiaOverview();

const period = ref('hoje');
const storeId = ref('');
const panel = ref(null);
const loading = ref(false);
const tab = ref('all');
const stage = ref(null);
const query = ref('');
let timer = null;
let latest = 0;

const load = async () => {
  latest += 1;
  const mine = latest;
  loading.value = true;
  try {
    const { data } = await LiaPanelAPI.get({
      period: period.value,
      storeId: storeId.value,
    });
    if (mine === latest) panel.value = data;
  } catch {
    // Mantem o ultimo painel: a tela nao some a cada falha de rede.
  } finally {
    if (mine === latest) loading.value = false;
  }
};

onMounted(() => {
  load();
  timer = setInterval(load, REFRESH_MS);
});
onBeforeUnmount(() => clearInterval(timer));
watch([period, storeId], () => {
  stage.value = null;
  load();
});

const urlFor = id =>
  frontendURL(conversationUrl({ accountId: route.params.accountId, id }));

const stores = computed(() => overview.value?.stores || []);
const available = computed(() => panel.value?.lia_available !== false);
const summary = computed(() => panel.value?.summary || {});
const threshold = computed(() => overview.value?.threshold_minutes || 15);
const maxWaitDays = computed(() => overview.value?.max_wait_days || 7);
// As abandonadas há mais de 7 dias ficam fora da fila; a contagem é da conta toda.
const staleCount = computed(() =>
  storeId.value ? 0 : overview.value?.stale?.count || 0
);

const waiting = computed(() =>
  waitingForStore(overview.value, storeId.value).map(row => ({
    ...row,
    wait: waitingFor(row.waiting_since),
    url: urlFor(row.id),
  }))
);
const waitingCount = computed(() =>
  Math.max(waitingTotal(overview.value, storeId.value), waiting.value.length)
);
const live = computed(() =>
  (panel.value?.live || []).map(row => ({ ...row, url: urlFor(row.id) }))
);
const rows = computed(() =>
  (panel.value?.conversations || []).map(row => ({
    ...row,
    url: urlFor(row.id),
    minutes: minutesSince(row.last_activity_at),
  }))
);
const filtered = computed(() =>
  filterRows(rows.value, {
    tab: tab.value,
    stage: stage.value,
    query: query.value,
    live: live.value,
  })
);

const delta = computed(() => autonomyDelta(panel.value));
const links = computed(() => {
  const product = panel.value?.links?.product || {};
  const checkout = panel.value?.links?.checkout || {};
  const sum = key => (product[key] || 0) + (checkout[key] || 0);
  return {
    product,
    checkout,
    sent: sum('sent'),
    clicked: sum('clicked'),
    paid: sum('paid'),
  };
});

const funnel = computed(() => {
  const steps = panel.value?.funnel || [];
  const top = steps[0]?.count || 0;
  return steps.map((step, index) => ({
    ...step,
    rate: pct(step.count, top),
    stopped: index < steps.length - 1 ? step.count - steps[index + 1].count : 0,
  }));
});
const stalled = computed(() => panel.value?.stalled || []);
const stalledTotal = computed(() =>
  stalled.value.reduce((total, item) => total + item.count, 0)
);
const bottleneck = computed(() => stalled.value[0] || null);
const reasons = computed(() => panel.value?.handoff_reasons || []);
const reasonsTotal = computed(() =>
  reasons.value.reduce((total, item) => total + item.count, 0)
);
const outcomes = computed(() =>
  Object.keys(CATEGORY_KEYS)
    .map(key => ({ key, count: summary.value[key] || 0 }))
    .filter(item => item.count > 0)
);
const OUTCOME_COLOR = {
  lia_only: 'bg-n-teal-9',
  lia_and_team: 'bg-n-brand',
  team_only: 'bg-n-iris-9',
  handed_off: 'bg-n-ruby-9',
  campaign: 'bg-n-amber-9',
  unanswered: 'bg-n-slate-8',
};
const SERIES = [
  {
    key: 'conversations',
    label: 'LIA_PANEL.TREND_CONVERSATIONS',
    color: 'bg-n-slate-8',
  },
  { key: 'lia_only', label: 'LIA_PANEL.TREND_LIA', color: 'bg-n-teal-9' },
  { key: 'team', label: 'LIA_PANEL.TREND_TEAM', color: 'bg-n-amber-9' },
  { key: 'clicks', label: 'LIA_PANEL.TREND_CLICKS', color: 'bg-n-brand' },
];
const trend = computed(() => panel.value?.trend?.points || []);
const trendMax = computed(() =>
  Math.max(
    1,
    ...trend.value.flatMap(point => SERIES.map(s => point[s.key] || 0))
  )
);
const STAGE_CLASS = {
  conversou: 'text-n-slate-11 border-n-weak',
  lia_respondeu: 'text-n-blue-11 border-n-blue-6',
  recebeu_link: 'text-n-iris-11 border-n-iris-6',
  abriu_link: 'text-n-amber-11 border-n-amber-6',
  pagou: 'text-n-teal-11 border-n-teal-6',
};

const pickStage = key => {
  stage.value = stage.value === key ? null : key;
  tab.value = 'all';
};

const exportCsv = () => {
  const header = [
    'CLIENT',
    'INBOX',
    'SITUATION',
    'STAGE',
    'LINK',
    'ASSIGNEE',
    'LAST',
  ].map(key => t(`LIA_PANEL.COL.${key}`));
  const quote = csvCell;
  const lines = filtered.value.map(row =>
    [
      `${row.contact_name || ''} #${row.id}`,
      row.inbox_name,
      t(CATEGORY_KEYS[row.category] || CATEGORY_KEYS.unanswered),
      t(STAGE_KEYS[row.stage] || STAGE_KEYS.conversou),
      t(LINK_KEYS[row.link_state] || LINK_KEYS.none),
      row.assignee_name,
      row.last_activity_at,
    ]
      .map(quote)
      .join(';')
  );
  const blob = new Blob([[header.map(quote).join(';'), ...lines].join('\n')], {
    type: 'text/csv;charset=utf-8',
  });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = `painel-lia-${period.value}.csv`;
  link.click();
  URL.revokeObjectURL(link.href);
};
</script>

<template>
  <section
    class="flex flex-col flex-1 h-full min-w-0 overflow-y-auto bg-n-background"
    data-testid="lia-panel"
  >
    <header
      class="sticky top-0 z-10 flex flex-wrap items-center gap-3 px-6 py-4 border-b border-n-weak bg-n-background"
    >
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ t('LIA_PANEL.TITLE') }}
      </h1>
      <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
        <span
          class="size-2 rounded-full"
          :class="loading ? 'bg-n-amber-9' : 'bg-n-teal-9'"
        />
        {{ t('LIA_PANEL.UPDATES') }}
      </span>
      <div class="flex flex-wrap items-center gap-2 ml-auto">
        <div
          class="flex p-0.5 rounded-lg border border-n-weak"
          role="group"
          :aria-label="t('LIA_PANEL.TITLE')"
        >
          <button
            v-for="key in PERIODS"
            :key="key"
            type="button"
            class="px-3 py-1 text-sm rounded-md"
            :class="
              period === key
                ? 'bg-n-brand text-white'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            :aria-pressed="period === key"
            @click="period = key"
          >
            {{ t(`LIA_PANEL.PERIOD.${key}`) }}
          </button>
        </div>
        <select
          v-model="storeId"
          class="h-8 py-0 text-sm rounded-lg !mb-0 !w-auto"
          :aria-label="t('LIA_PANEL.STORE_FILTER')"
        >
          <option value="">{{ t('LIA_PANEL.ALL_STORES') }}</option>
          <option
            v-for="store in stores"
            :key="store.store_id"
            :value="store.store_id"
          >
            {{ store.name }}
          </option>
        </select>
        <button
          type="button"
          class="px-3 h-8 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
          @click="load"
        >
          {{ t('LIA_PANEL.REFRESH') }}
        </button>
      </div>
    </header>

    <div
      v-if="!panel"
      class="flex items-center justify-center flex-1 p-10 text-n-slate-11"
    >
      <Spinner />
    </div>

    <div v-else class="flex flex-col gap-4 p-6">
      <p
        v-if="!available"
        class="px-4 py-3 text-sm rounded-lg border border-n-amber-6 bg-n-amber-3 text-n-amber-11"
        role="status"
      >
        {{ t('LIA_PANEL.LIA_UNAVAILABLE') }}
      </p>

      <!-- Indicadores -->
      <div class="grid gap-3 grid-cols-1 sm:grid-cols-2 xl:grid-cols-5">
        <article
          v-if="available"
          class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-autonomy"
        >
          <h2 class="text-xs text-n-slate-11">
            {{ t('LIA_PANEL.KPI.AUTONOMY') }}
          </h2>
          <p class="mt-1 text-3xl font-semibold tabular-nums text-n-slate-12">
            {{ Math.round(summary.autonomy_pct || 0) }}%
          </p>
          <p class="mt-1 text-xs text-n-slate-11">
            {{
              t('LIA_PANEL.KPI.AUTONOMY_DETAIL', {
                lia: summary.lia_only || 0,
                base: summary.autonomy_base || 0,
              })
            }}
          </p>
          <p
            v-if="delta !== null"
            class="mt-1 text-xs"
            :class="delta >= 0 ? 'text-n-teal-11' : 'text-n-ruby-11'"
          >
            {{
              t('LIA_PANEL.KPI.AUTONOMY_DELTA', {
                delta: delta > 0 ? `+${delta}` : delta,
              })
            }}
          </p>
          <p v-if="summary.campaign" class="mt-1 text-xs text-n-slate-10">
            {{
              t(
                'LIA_PANEL.KPI.CAMPAIGNS',
                { count: summary.campaign },
                summary.campaign
              )
            }}
          </p>
        </article>
        <article
          v-if="available"
          class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-live-count"
        >
          <h2 class="text-xs text-n-slate-11">{{ t('LIA_PANEL.KPI.LIVE') }}</h2>
          <p class="mt-1 text-3xl font-semibold tabular-nums text-n-slate-12">
            {{ live.length }}
          </p>
          <p class="mt-1 text-xs text-n-slate-11">
            {{
              t('LIA_PANEL.KPI.LIVE_DETAIL', {
                count: live.filter(item => item.awaiting_lia).length,
              })
            }}
          </p>
        </article>
        <article
          class="p-4 rounded-xl border bg-n-solid-1"
          :class="waitingCount ? 'border-n-ruby-6' : 'border-n-weak'"
          data-testid="lia-panel-waiting-count"
        >
          <h2 class="text-xs text-n-slate-11">
            {{ t('LIA_PANEL.KPI.WAITING') }}
          </h2>
          <p
            class="mt-1 text-3xl font-semibold tabular-nums"
            :class="waitingCount ? 'text-n-ruby-11' : 'text-n-slate-12'"
          >
            {{ waitingCount }}
          </p>
          <p class="mt-1 text-xs text-n-slate-11">
            {{
              waiting.length
                ? t('LIA_PANEL.KPI.WAITING_DETAIL', {
                    wait: waiting[0].wait.text,
                  })
                : t('LIA_PANEL.KPI.WAITING_NONE')
            }}
          </p>
        </article>
        <article
          v-if="available"
          class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-links"
        >
          <h2 class="text-xs text-n-slate-11">
            {{ t('LIA_PANEL.KPI.LINKS') }}
          </h2>
          <p class="mt-1 text-3xl font-semibold tabular-nums text-n-slate-12">
            {{ `${links.sent} → ${links.clicked}` }}
          </p>
          <p class="mt-1 text-xs text-n-slate-11">
            {{
              t(
                'LIA_PANEL.KPI.LINKS_DETAIL',
                { paid: links.paid, rate: pct(links.clicked, links.sent) },
                links.paid
              )
            }}
          </p>
        </article>
        <article
          v-if="available"
          class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
        >
          <h2 class="text-xs text-n-slate-11">
            {{ t('LIA_PANEL.KPI.BOTTLENECK') }}
          </h2>
          <template v-if="bottleneck">
            <p class="mt-1 text-base font-semibold text-n-slate-12">
              {{ bottleneck.label }}
            </p>
            <p class="mt-1 text-xs text-n-slate-11">
              {{
                t(
                  'LIA_PANEL.KPI.BOTTLENECK_DETAIL',
                  {
                    count: bottleneck.count,
                    rate: pct(bottleneck.count, stalledTotal),
                  },
                  bottleneck.count
                )
              }}
            </p>
          </template>
          <p v-else class="mt-1 text-sm text-n-slate-11">
            {{ t('LIA_PANEL.KPI.BOTTLENECK_NONE') }}
          </p>
        </article>
      </div>

      <!-- Filas ao vivo -->
      <div class="grid gap-4 lg:grid-cols-2">
        <article
          class="flex flex-col p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-waiting"
        >
          <h2
            class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
          >
            {{ t('LIA_PANEL.WAITING_QUEUE') }}
            <span
              v-if="waitingCount"
              class="px-2 rounded-full text-xs leading-5 text-white bg-n-ruby-9"
            >
              {{ waitingCount }}
            </span>
          </h2>
          <p class="mb-3 text-xs text-n-slate-11">
            {{ t('LIA_PANEL.WAITING_QUEUE_HINT', { minutes: threshold }) }}
          </p>
          <p
            v-if="!waiting.length"
            class="py-6 text-sm text-center text-n-slate-11"
          >
            {{ t('LIA_PANEL.WAITING_EMPTY') }}
          </p>
          <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="row in waiting.slice(0, QUEUE_LIMIT)"
              :key="row.id"
              class="flex items-center gap-3 p-3 rounded-lg border-l-4 bg-n-alpha-1"
              :class="
                row.wait.tone === 'red' ? 'border-n-ruby-9' : 'border-n-amber-9'
              "
            >
              <span class="flex flex-col flex-1 min-w-0">
                <span class="text-sm font-medium truncate text-n-slate-12">
                  {{ row.contact_name || t('LIA_PANEL.NO_NAME') }}
                  <span class="ml-1 text-xs font-normal text-n-slate-10">
                    {{ row.inbox_name }}
                  </span>
                </span>
                <span class="text-xs truncate text-n-slate-11">
                  {{ row.last_message }}
                </span>
              </span>
              <span
                class="text-sm font-medium tabular-nums shrink-0"
                :class="
                  row.wait.tone === 'red' ? 'text-n-ruby-11' : 'text-n-amber-11'
                "
              >
                {{ row.wait.text }}
              </span>
              <router-link
                :to="row.url"
                class="px-3 py-1 text-xs rounded-md border border-n-weak shrink-0 text-n-slate-12 hover:bg-n-alpha-2"
              >
                {{ t('LIA_PANEL.OPEN') }}
              </router-link>
            </li>
          </ul>
          <router-link
            v-if="waitingCount > QUEUE_LIMIT"
            :to="frontendURL(`accounts/${route.params.accountId}/lia-waiting`)"
            class="mt-2 text-xs text-n-brand"
          >
            {{ t('LIA_PANEL.SEE_ALL', { count: waitingCount }) }}
          </router-link>
          <p
            v-if="staleCount"
            class="mt-2 text-xs text-n-slate-10"
            data-testid="lia-panel-stale"
          >
            {{
              t(
                'LIA_OVERVIEW.STALE',
                { count: staleCount, days: maxWaitDays },
                staleCount
              )
            }}
          </p>
        </article>

        <article
          v-if="available"
          class="flex flex-col p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-live"
        >
          <h2
            class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
          >
            {{ t('LIA_PANEL.LIVE_QUEUE') }}
            <span
              v-if="live.length"
              class="px-2 rounded-full text-xs leading-5 text-white bg-n-teal-9"
            >
              {{ live.length }}
            </span>
          </h2>
          <p class="mb-3 text-xs text-n-slate-11">
            {{ t('LIA_PANEL.LIVE_QUEUE_HINT') }}
          </p>
          <p
            v-if="!live.length"
            class="py-6 text-sm text-center text-n-slate-11"
          >
            {{ t('LIA_PANEL.LIVE_EMPTY') }}
          </p>
          <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="row in live.slice(0, QUEUE_LIMIT)"
              :key="row.id"
              class="flex items-center gap-3 p-3 rounded-lg border-l-4 border-n-teal-9 bg-n-alpha-1"
            >
              <span class="flex flex-col flex-1 min-w-0 gap-1">
                <span class="text-sm font-medium truncate text-n-slate-12">
                  {{ row.contact_name || t('LIA_PANEL.NO_NAME') }}
                  <span class="ml-1 text-xs font-normal text-n-slate-10">
                    {{ row.inbox_name }}
                  </span>
                </span>
                <span class="text-xs truncate text-n-slate-11">
                  {{ row.last_message }}
                </span>
                <span class="flex gap-1">
                  <span
                    class="px-1.5 rounded border text-xs leading-5"
                    :class="STAGE_CLASS[row.stage]"
                  >
                    {{ t(STAGE_KEYS[row.stage] || STAGE_KEYS.conversou) }}
                  </span>
                  <span
                    v-if="row.awaiting_lia"
                    class="px-1.5 rounded border text-xs leading-5 border-n-teal-6 text-n-teal-11"
                  >
                    {{ t('LIA_PANEL.AWAITING_LIA') }}
                  </span>
                </span>
              </span>
              <span class="text-sm tabular-nums shrink-0 text-n-teal-11">
                {{ ago(row.minutes_since_last) }}
              </span>
              <router-link
                :to="row.url"
                class="px-3 py-1 text-xs rounded-md border border-n-weak shrink-0 text-n-slate-12 hover:bg-n-alpha-2"
              >
                {{ t('LIA_PANEL.OPEN') }}
              </router-link>
            </li>
          </ul>
        </article>
      </div>

      <template v-if="available">
        <!-- Funil e gargalos -->
        <div class="grid gap-4 lg:grid-cols-2">
          <article
            class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
            data-testid="lia-panel-funnel"
          >
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.FUNNEL') }}
            </h2>
            <p class="mb-3 text-xs text-n-slate-11">
              {{ t('LIA_PANEL.FUNNEL_HINT') }}
            </p>
            <ol class="flex flex-col gap-3 p-0 m-0 list-none">
              <li v-for="(step, index) in funnel" :key="step.key">
                <button
                  type="button"
                  class="w-full text-left rounded-md p-1 -m-1 hover:bg-n-alpha-1"
                  :class="stage === step.key ? 'ring-1 ring-n-brand' : ''"
                  :aria-pressed="stage === step.key"
                  @click="pickStage(step.key)"
                >
                  <span class="flex justify-between text-sm text-n-slate-12">
                    <span>{{ index + 1 }}. {{ t(STAGE_KEYS[step.key]) }}</span>
                    <span class="tabular-nums">
                      {{ step.count }}
                      <span class="text-n-slate-10">· {{ step.rate }}%</span>
                    </span>
                  </span>
                  <span class="block h-2 mt-1 rounded-full bg-n-alpha-2">
                    <span
                      class="block h-2 rounded-full bg-n-brand"
                      :style="{ width: `${step.rate}%` }"
                    />
                  </span>
                  <span
                    v-if="step.stopped > 0"
                    class="block mt-1 text-xs text-n-slate-10"
                  >
                    {{
                      t(
                        'LIA_PANEL.FUNNEL_STOPPED',
                        { count: step.stopped },
                        step.stopped
                      )
                    }}
                  </span>
                </button>
              </li>
            </ol>
          </article>

          <article
            class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
            data-testid="lia-panel-stalled"
          >
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.STALLED') }}
            </h2>
            <p class="mb-3 text-xs text-n-slate-11">
              {{ t('LIA_PANEL.STALLED_HINT') }}
            </p>
            <p
              v-if="!stalled.length"
              class="py-6 text-sm text-center text-n-slate-11"
            >
              {{ t('LIA_PANEL.STALLED_EMPTY') }}
            </p>
            <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
              <li v-for="item in stalled" :key="item.key">
                <button
                  type="button"
                  class="flex items-center w-full gap-3 p-3 text-left rounded-lg border-l-4 border-n-amber-9 bg-n-alpha-1 hover:bg-n-alpha-2"
                  :aria-pressed="stage === item.key"
                  @click="pickStage(item.key)"
                >
                  <span class="flex-1 text-sm font-medium text-n-slate-12">
                    {{ item.label }}
                  </span>
                  <span class="text-right">
                    <span
                      class="block text-lg font-semibold tabular-nums text-n-slate-12"
                    >
                      {{ item.count }}
                    </span>
                    <span class="block text-xs text-n-slate-10">
                      {{ pct(item.count, stalledTotal) }}%
                    </span>
                  </span>
                </button>
              </li>
            </ul>
          </article>
        </div>

        <!-- Tendência, desfechos, motivos e links -->
        <div class="grid gap-4 lg:grid-cols-2 xl:grid-cols-4">
          <article
            class="p-4 rounded-xl border border-n-weak bg-n-solid-1 xl:col-span-2"
            data-testid="lia-panel-trend"
          >
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.TREND') }}
            </h2>
            <p class="flex flex-wrap gap-3 my-2 text-xs text-n-slate-11">
              <span
                v-for="serie in SERIES"
                :key="serie.key"
                class="flex items-center gap-1"
              >
                <span class="size-2 rounded-sm" :class="serie.color" />
                {{ t(serie.label) }}
              </span>
            </p>
            <div class="flex items-end gap-1 h-40 overflow-x-auto">
              <div
                v-for="point in trend"
                :key="point.label"
                class="flex flex-col items-center flex-1 min-w-[1.75rem] h-full"
              >
                <div class="flex items-end flex-1 w-full gap-px">
                  <span
                    v-for="serie in SERIES"
                    :key="serie.key"
                    class="flex-1 rounded-t-sm"
                    :class="serie.color"
                    :style="{
                      height: `${(100 * (point[serie.key] || 0)) / trendMax}%`,
                    }"
                    :title="`${t(serie.label)}: ${point[serie.key] || 0}`"
                  />
                </div>
                <span class="mt-1 text-[10px] text-n-slate-10 tabular-nums">
                  {{ point.label }}
                </span>
              </div>
            </div>
          </article>

          <article class="p-4 rounded-xl border border-n-weak bg-n-solid-1">
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.OUTCOMES') }}
            </h2>
            <ul class="flex flex-col gap-2 p-0 m-0 mt-3 list-none">
              <li v-for="item in outcomes" :key="item.key">
                <span class="flex justify-between text-xs text-n-slate-12">
                  <span>{{ t(CATEGORY_KEYS[item.key]) }}</span>
                  <span class="tabular-nums">
                    {{ item.count }} ·
                    {{ pct(item.count, summary.conversations) }}%
                  </span>
                </span>
                <span class="block h-1.5 mt-1 rounded-full bg-n-alpha-2">
                  <span
                    class="block h-1.5 rounded-full"
                    :class="OUTCOME_COLOR[item.key]"
                    :style="{
                      width: `${pct(item.count, summary.conversations)}%`,
                    }"
                  />
                </span>
              </li>
            </ul>
            <h2 class="mt-5 text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.REASONS') }}
            </h2>
            <p v-if="!reasons.length" class="mt-2 text-xs text-n-slate-11">
              {{ t('LIA_PANEL.REASONS_EMPTY') }}
            </p>
            <ul
              v-else
              class="flex flex-col gap-2 p-0 m-0 mt-3 list-none"
              data-testid="lia-panel-reasons"
            >
              <li v-for="item in reasons" :key="item.key" :title="item.example">
                <span class="flex justify-between text-xs text-n-slate-12">
                  <span>{{ item.label }}</span>
                  <span class="tabular-nums"
                    >{{ pct(item.count, reasonsTotal) }}%</span
                  >
                </span>
                <span class="block h-1.5 mt-1 rounded-full bg-n-alpha-2">
                  <span
                    class="block h-1.5 rounded-full bg-n-ruby-9"
                    :style="{ width: `${pct(item.count, reasonsTotal)}%` }"
                  />
                </span>
              </li>
            </ul>
          </article>

          <article class="p-4 rounded-xl border border-n-weak bg-n-solid-1">
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.LINKS') }}
            </h2>
            <div
              v-for="kind in ['checkout', 'product']"
              :key="kind"
              class="p-3 mt-3 rounded-lg border border-n-weak"
            >
              <p class="text-xs text-n-slate-11">
                {{
                  t(
                    kind === 'checkout'
                      ? 'LIA_PANEL.LINKS_CHECKOUT'
                      : 'LIA_PANEL.LINKS_PRODUCT'
                  )
                }}
              </p>
              <p class="flex gap-4 mt-1 text-sm text-n-slate-12 tabular-nums">
                <span>
                  <strong class="text-lg">{{ links[kind].sent || 0 }}</strong>
                  {{ t('LIA_PANEL.LINKS_SENT') }}
                </span>
                <span>
                  <strong class="text-lg">{{
                    links[kind].clicked || 0
                  }}</strong>
                  {{ t('LIA_PANEL.LINKS_CLICKED') }}
                </span>
                <span>
                  <strong class="text-lg">{{ links[kind].paid || 0 }}</strong>
                  {{ t('LIA_PANEL.LINKS_PAID') }}
                </span>
              </p>
            </div>
          </article>
        </div>

        <!-- Lista -->
        <article
          class="p-4 rounded-xl border border-n-weak bg-n-solid-1"
          data-testid="lia-panel-list"
        >
          <div class="flex flex-wrap items-center gap-2 mb-3">
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ t('LIA_PANEL.LIST') }}
            </h2>
            <span class="text-xs text-n-slate-10">
              {{
                t('LIA_PANEL.LIST_COUNT', {
                  shown: filtered.length,
                  count: rows.length,
                })
              }}
            </span>
            <span
              v-if="rows.length < (summary.conversations || 0)"
              class="text-xs text-n-amber-11"
            >
              {{
                t('LIA_PANEL.LIST_TRUNCATED', {
                  count: rows.length,
                  total: summary.conversations,
                })
              }}
            </span>
            <button
              v-if="stage"
              type="button"
              class="px-2 py-0.5 text-xs rounded-full border border-n-brand text-n-brand"
              @click="stage = null"
            >
              {{
                `${t('LIA_PANEL.CLEAR_STAGE', { stage: t(STAGE_KEYS[stage]) })} ✕`
              }}
            </button>
            <div class="flex flex-wrap items-center gap-2 ml-auto">
              <input
                v-model="query"
                type="search"
                class="h-8 text-sm rounded-lg !mb-0 !w-72 max-w-full"
                :placeholder="t('LIA_PANEL.SEARCH')"
                :aria-label="t('LIA_PANEL.SEARCH')"
              />
              <button
                type="button"
                class="px-3 h-8 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
                @click="exportCsv"
              >
                {{ t('LIA_PANEL.EXPORT') }}
              </button>
            </div>
          </div>
          <div class="flex flex-wrap gap-1 mb-3" role="tablist">
            <button
              v-for="key in TABS"
              :key="key"
              type="button"
              role="tab"
              class="px-3 py-1 text-xs rounded-md border"
              :class="
                tab === key
                  ? 'border-n-brand text-n-brand bg-n-alpha-1'
                  : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
              "
              :aria-selected="tab === key"
              @click="tab = key"
            >
              {{ t(`LIA_PANEL.TAB.${key}`) }}
            </button>
          </div>
          <p
            v-if="!filtered.length"
            class="py-8 text-sm text-center text-n-slate-11"
          >
            {{ t('LIA_PANEL.LIST_EMPTY') }}
          </p>
          <div v-else class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-xs text-left uppercase text-n-slate-10">
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.CLIENT') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.INBOX') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.SITUATION') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.STAGE') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.LINK') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.ASSIGNEE') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('LIA_PANEL.COL.LAST') }}
                  </th>
                  <th class="py-2 font-medium text-right">
                    {{ t('LIA_PANEL.COL.ACTION') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak">
                <tr
                  v-for="row in filtered"
                  :key="row.id"
                  :data-testid="`lia-panel-row-${row.id}`"
                >
                  <td class="py-2 pr-3">
                    <span class="font-medium text-n-slate-12">
                      {{ row.contact_name || t('LIA_PANEL.NO_NAME') }}
                    </span>
                    <span class="block text-xs text-n-slate-10"
                      >#{{ row.id }}</span
                    >
                  </td>
                  <td class="py-2 pr-3 text-n-slate-11">
                    {{ row.inbox_name }}
                  </td>
                  <td class="py-2 pr-3">
                    <span
                      class="px-1.5 rounded border text-xs leading-5"
                      :class="
                        row.waiting_team
                          ? 'border-n-ruby-6 text-n-ruby-11'
                          : 'border-n-weak text-n-slate-11'
                      "
                    >
                      {{
                        t(
                          CATEGORY_KEYS[row.category] ||
                            CATEGORY_KEYS.unanswered
                        )
                      }}
                    </span>
                    <span
                      v-if="row.handoff_reason"
                      class="block mt-1 text-xs truncate max-w-[16rem] text-n-slate-10"
                      :title="row.handoff_reason"
                    >
                      {{ row.handoff_reason }}
                    </span>
                  </td>
                  <td class="py-2 pr-3">
                    <span
                      class="px-1.5 rounded border text-xs leading-5"
                      :class="STAGE_CLASS[row.stage]"
                    >
                      {{ t(STAGE_KEYS[row.stage] || STAGE_KEYS.conversou) }}
                    </span>
                  </td>
                  <td class="py-2 pr-3 text-xs text-n-slate-11">
                    {{ t(LINK_KEYS[row.link_state] || LINK_KEYS.none) }}
                  </td>
                  <td class="py-2 pr-3 text-n-slate-11">
                    {{ row.assignee_name || t('LIA_PANEL.NOBODY') }}
                  </td>
                  <td class="py-2 pr-3 tabular-nums text-n-slate-11">
                    {{ ago(row.minutes) }}
                  </td>
                  <td class="py-2 text-right">
                    <router-link
                      :to="row.url"
                      class="px-3 py-1 text-xs rounded-md border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
                    >
                      {{ t('LIA_PANEL.OPEN') }} #{{ row.id }}
                    </router-link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>
      </template>
    </div>
  </section>
</template>
