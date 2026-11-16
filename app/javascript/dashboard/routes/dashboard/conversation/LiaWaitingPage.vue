<script setup>
// Fila "Esperando a equipe": quem escreveu e esta sem resposta ha mais de 15 min,
// do mais antigo para o mais novo, com o motivo de a LIA nao ter respondido.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useLiaOverview } from 'dashboard/composables/useLiaOverview';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { REASON_KEYS, waitingFor } from 'dashboard/helper/liaOverview';

const { t } = useI18n();
const route = useRoute();
const { overview } = useLiaOverview();

const minutes = computed(() => overview.value?.threshold_minutes || 15);
const count = computed(() => overview.value?.waiting?.count || 0);
const rows = computed(() =>
  (overview.value?.waiting?.conversations || []).map(row => ({
    ...row,
    wait: waitingFor(row.waiting_since),
    url: frontendURL(
      conversationUrl({ accountId: route.params.accountId, id: row.id })
    ),
  }))
);

const REASON_CLASS = {
  lia_transferiu: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6',
  lia_parada: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6',
  sem_resposta: 'bg-n-alpha-2 text-n-slate-11 border-n-weak',
};
</script>

<template>
  <section class="flex flex-col flex-1 h-full min-w-0 overflow-y-auto">
    <header class="px-6 pt-6 pb-4 border-b border-n-weak">
      <h1 class="flex items-center gap-2 text-lg font-medium text-n-slate-12">
        {{ t('LIA_OVERVIEW.TITLE') }}
        <span
          v-if="count"
          class="px-2 rounded-full text-xs leading-5 text-white bg-n-ruby-9"
        >
          {{ count }}
        </span>
      </h1>
      <p class="mt-1 text-sm text-n-slate-11 max-w-3xl">
        {{ t('LIA_OVERVIEW.SUBTITLE', { minutes }) }}
      </p>
      <p
        v-if="overview && !overview.lia_available"
        class="mt-2 text-xs text-n-amber-11"
      >
        {{ t('LIA_OVERVIEW.LIA_UNAVAILABLE') }}
      </p>
    </header>

    <div
      v-if="overview && !rows.length"
      class="flex flex-col items-center justify-center flex-1 gap-1 p-10 text-center"
      data-test-id="lia-waiting-empty"
    >
      <span class="i-lucide-check-circle size-8 text-n-teal-9" />
      <p class="text-base font-medium text-n-slate-12">
        {{ t('LIA_OVERVIEW.EMPTY_TITLE') }}
      </p>
      <p class="text-sm text-n-slate-11">
        {{ t('LIA_OVERVIEW.EMPTY_TEXT', { minutes }) }}
      </p>
    </div>

    <ul v-else class="divide-y divide-n-weak" data-test-id="lia-waiting-list">
      <li v-for="row in rows" :key="row.id">
        <router-link
          :to="row.url"
          class="flex items-start gap-4 px-6 py-3 hover:bg-n-alpha-1"
          :data-test-id="`lia-waiting-${row.id}`"
        >
          <span
            class="w-20 shrink-0 pt-0.5 text-sm font-medium tabular-nums"
            :class="
              row.wait.tone === 'red' ? 'text-n-ruby-11' : 'text-n-amber-11'
            "
          >
            {{ t('LIA_OVERVIEW.WAITING_FOR', { wait: row.wait.text }) }}
          </span>
          <span class="flex flex-col flex-1 min-w-0 gap-1">
            <span class="flex flex-wrap items-center gap-2">
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ row.contact_name || t('LIA_OVERVIEW.NO_NAME') }}
              </span>
              <span class="text-xs text-n-slate-10">{{ row.inbox_name }}</span>
              <span
                class="px-1.5 rounded border text-xs leading-5"
                :class="REASON_CLASS[row.reason]"
              >
                {{ t(REASON_KEYS[row.reason] || REASON_KEYS.sem_resposta) }}
              </span>
            </span>
            <span class="text-sm text-n-slate-11 truncate">
              {{ row.last_message }}
            </span>
          </span>
        </router-link>
      </li>
    </ul>
    <p v-if="count > rows.length" class="px-6 py-3 text-xs text-n-slate-10">
      {{ t('LIA_OVERVIEW.MORE', { shown: rows.length, count }) }}
    </p>
  </section>
</template>
