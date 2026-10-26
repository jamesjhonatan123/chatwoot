<script setup>
// Aproveitamento da sugestao pronta da LIA e as negadas, para aprimorar.
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import LiaSuggestionMetricsAPI from 'dashboard/api/liaSuggestionMetrics';

const { t } = useI18n();
const route = useRoute();

const days = ref(7);
const loading = ref(false);
const failed = ref(false);
const data = ref(null);
const releasing = ref('');

const totals = computed(() => data.value?.totals || {});
const percent = value =>
  value === null || value === undefined ? '—' : `${Math.round(value * 100)}%`;

const sourceLabel = source =>
  ({
    canned: t('LIA_SUGGESTION.REPORT.SOURCES.CANNED'),
    quick_reply: t('LIA_SUGGESTION.REPORT.SOURCES.QUICK_REPLY'),
    history: t('LIA_SUGGESTION.REPORT.SOURCES.HISTORY'),
    lia_draft: t('LIA_SUGGESTION.REPORT.SOURCES.LIA_DRAFT'),
    system: t('LIA_SUGGESTION.REPORT.SOURCES.SYSTEM'),
  })[source] || source;

const cards = computed(() => [
  {
    key: 'shown',
    label: t('LIA_SUGGESTION.REPORT.SHOWN'),
    value: totals.value.shown,
  },
  {
    key: 'used',
    label: t('LIA_SUGGESTION.REPORT.USED'),
    value: totals.value.used,
  },
  {
    key: 'edited',
    label: t('LIA_SUGGESTION.REPORT.EDITED'),
    value: totals.value.edited,
  },
  {
    key: 'ignored',
    label: t('LIA_SUGGESTION.REPORT.IGNORED'),
    value: totals.value.ignored,
  },
  {
    key: 'dismissed',
    label: t('LIA_SUGGESTION.REPORT.DISMISSED'),
    value: totals.value.dismissed,
  },
  {
    key: 'rate',
    label: t('LIA_SUGGESTION.REPORT.RATE'),
    value: percent(totals.value.rate),
  },
]);

const conversationPath = id =>
  `/app/accounts/${route.params.accountId}/conversations/${id}`;

const fetchData = async () => {
  loading.value = true;
  failed.value = false;
  try {
    const response = await LiaSuggestionMetricsAPI.get(days.value);
    data.value = response.data?.error ? null : response.data;
    failed.value = !!response.data?.error;
  } catch (error) {
    failed.value = true;
  } finally {
    loading.value = false;
  }
};

const release = async item => {
  releasing.value = item.text_key;
  try {
    await LiaSuggestionMetricsAPI.release(item.text_key);
    await fetchData();
  } finally {
    releasing.value = '';
  }
};

watch(days, fetchData);
onMounted(fetchData);
</script>

<template>
  <div class="flex flex-col w-full gap-6 p-6 overflow-auto">
    <div class="flex items-center justify-between gap-4">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('LIA_SUGGESTION.REPORT.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('LIA_SUGGESTION.REPORT.SUBTITLE') }}
        </p>
      </div>
      <select
        v-model.number="days"
        class="w-auto px-3 py-1.5 text-sm rounded-md bg-n-alpha-black2 text-n-slate-12"
        :aria-label="t('LIA_SUGGESTION.REPORT.PERIOD')"
      >
        <option :value="1">{{ t('LIA_SUGGESTION.REPORT.LAST_DAY') }}</option>
        <option :value="7">{{ t('LIA_SUGGESTION.REPORT.LAST_7') }}</option>
        <option :value="30">{{ t('LIA_SUGGESTION.REPORT.LAST_30') }}</option>
      </select>
    </div>

    <p v-if="failed" class="text-sm text-n-ruby-11">
      {{ t('LIA_SUGGESTION.REPORT.FAILED') }}
    </p>
    <p v-else-if="loading && !data" class="text-sm text-n-slate-11">
      {{ t('LIA_SUGGESTION.REPORT.LOADING') }}
    </p>

    <template v-if="data">
      <div class="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
        <div
          v-for="card in cards"
          :key="card.key"
          class="p-4 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <p class="text-xs text-n-slate-11">{{ card.label }}</p>
          <p class="mt-1 text-2xl font-medium text-n-slate-12">
            {{ card.value ?? 0 }}
          </p>
        </div>
      </div>
      <p class="text-xs text-n-slate-10">
        {{ t('LIA_SUGGESTION.REPORT.RATE_HINT') }}
      </p>

      <div class="grid gap-6 lg:grid-cols-2">
        <section
          v-for="table in [
            {
              key: 'by_source',
              title: t('LIA_SUGGESTION.REPORT.BY_SOURCE'),
              label: row => sourceLabel(row.source),
            },
            {
              key: 'by_agent',
              title: t('LIA_SUGGESTION.REPORT.BY_AGENT'),
              label: row => row.agent,
            },
          ]"
          :key="table.key"
          class="rounded-lg border border-n-weak"
        >
          <h2
            class="px-4 py-3 text-sm font-medium border-b border-n-weak text-n-slate-12"
          >
            {{ table.title }}
          </h2>
          <table class="w-full text-sm">
            <thead class="text-xs text-n-slate-11">
              <tr>
                <th class="px-4 py-2 font-normal text-left" />
                <th class="px-2 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.SHOWN') }}
                </th>
                <th class="px-2 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.USED') }}
                </th>
                <th class="px-2 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.EDITED') }}
                </th>
                <th class="px-2 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.IGNORED') }}
                </th>
                <th class="px-2 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.DISMISSED') }}
                </th>
                <th class="px-4 py-2 font-normal text-right">
                  {{ t('LIA_SUGGESTION.REPORT.RATE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in data[table.key]"
                :key="table.label(row)"
                class="border-t border-n-weak text-n-slate-12"
              >
                <td class="px-4 py-2">{{ table.label(row) }}</td>
                <td class="px-2 py-2 text-right">{{ row.shown }}</td>
                <td class="px-2 py-2 text-right">{{ row.used }}</td>
                <td class="px-2 py-2 text-right">{{ row.edited }}</td>
                <td class="px-2 py-2 text-right">{{ row.ignored }}</td>
                <td class="px-2 py-2 text-right">{{ row.dismissed }}</td>
                <td class="px-4 py-2 text-right">{{ percent(row.rate) }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <section class="rounded-lg border border-n-weak">
        <h2
          class="px-4 py-3 text-sm font-medium border-b border-n-weak text-n-slate-12"
        >
          {{
            t('LIA_SUGGESTION.REPORT.REJECTED_TITLE', {
              count: data.rejected.length,
            })
          }}
        </h2>
        <p
          v-if="!data.rejected.length"
          class="px-4 py-3 text-sm text-n-slate-11"
        >
          {{ t('LIA_SUGGESTION.REPORT.NO_REJECTED') }}
        </p>
        <article
          v-for="item in data.rejected"
          :key="item.id"
          class="grid gap-2 px-4 py-3 text-sm border-t border-n-weak first:border-t-0"
        >
          <div
            class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11"
          >
            <span>{{ new Date(item.at).toLocaleString() }}</span>
            <router-link
              v-if="item.conversation_id"
              :to="conversationPath(item.conversation_id)"
              class="text-n-blue-text hover:underline"
            >
              #{{ item.conversation_id }}
            </router-link>
            <span>· {{ sourceLabel(item.source) }}</span>
            <span
              >· {{ item.how
              }}<template v-if="item.dismissed_by">
                ({{ item.dismissed_by }})</template
              ></span
            >
            <span
              v-if="item.blocked"
              class="px-1.5 py-0.5 rounded bg-n-ruby-3 text-n-ruby-11"
            >
              {{
                t('LIA_SUGGESTION.REPORT.BLOCKED', { count: item.rejections })
              }}
            </span>
          </div>
          <p class="text-n-slate-11">
            <span class="font-medium text-n-slate-12"
              >{{ t('LIA_SUGGESTION.REPORT.QUESTION') }}:</span
            >
            {{ item.question }}
          </p>
          <p class="text-n-slate-11">
            <span class="font-medium text-n-slate-12"
              >{{ t('LIA_SUGGESTION.REPORT.SUGGESTED') }}:</span
            >
            {{ item.suggestion }}
            <template v-if="item.options > 1">
              ({{
                t('LIA_SUGGESTION.REPORT.OPTIONS', { count: item.options })
              }})
            </template>
          </p>
          <p v-if="item.sent_text" class="text-n-slate-11">
            <span class="font-medium text-n-slate-12"
              >{{ t('LIA_SUGGESTION.REPORT.SENT_INSTEAD')
              }}<template v-if="item.sent_by"> ({{ item.sent_by }})</template
              >:</span
            >
            {{ item.sent_text }}
          </p>
          <div v-if="item.blocked">
            <button
              type="button"
              class="px-3 py-1 text-xs rounded-md bg-n-alpha-black2 text-n-slate-12 hover:bg-n-alpha-black1 disabled:opacity-50"
              :disabled="releasing === item.text_key"
              @click="release(item)"
            >
              {{ t('LIA_SUGGESTION.REPORT.RELEASE') }}
            </button>
          </div>
        </article>
      </section>
    </template>
  </div>
</template>
