<script setup>
import { ref, computed, onMounted, toRef } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import WhatsappTemplateCategoriesAPI from 'dashboard/api/whatsappTemplateCategories';
import {
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
} from 'dashboard/helper/templateHelper';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const emit = defineEmits(['onSelect']);

const { t } = useI18n();
const store = useStore();
const query = ref('');
const isRefreshing = ref(false);
const categories = ref([]);
const selectedCategoryId = ref('all');

// Categorias proprias da conta — as mesmas de Configuracoes -> Templates. Nao
// confundir com `template.category`, que e a da Meta (UTILITY/MARKETING) e
// aparece no corpo do card. Leitura e liberada para atendente pela policy.
const categoryByTemplateName = computed(() => {
  const map = new Map();
  categories.value.forEach(category => {
    (category.template_names || []).forEach(name => map.set(name, category));
  });
  return map;
});

const categoryFor = template => categoryByTemplateName.value.get(template.name);

const categoryOptions = computed(() => [
  { value: 'all', label: t('WHATSAPP_TEMPLATES.PICKER.LABELS.ALL_CATEGORIES') },
  ...categories.value.map(item => ({
    value: String(item.id),
    label: item.name,
  })),
  { value: 'none', label: t('WHATSAPP_TEMPLATES.PICKER.LABELS.NO_CATEGORY') },
]);

onMounted(async () => {
  try {
    const { data } = await WhatsappTemplateCategoriesAPI.get();
    categories.value = data.payload || [];
  } catch (error) {
    // Sem categorias a tela segue igual ao que era: o filtro some e os cards
    // ficam sem etiqueta. Nao vale interromper o atendimento por isso.
    categories.value = [];
  }
});

const whatsAppTemplateMessages = useFunctionGetter(
  'inboxes/getFilteredWhatsAppTemplates',
  toRef(props, 'inboxId')
);

const filteredTemplateMessages = computed(() => {
  const term = query.value.toLowerCase();

  return whatsAppTemplateMessages.value.filter(template => {
    const category = categoryFor(template);

    if (selectedCategoryId.value === 'none' && category) return false;
    if (
      selectedCategoryId.value !== 'all' &&
      selectedCategoryId.value !== 'none' &&
      String(category?.id) !== selectedCategoryId.value
    ) {
      return false;
    }

    // A busca tambem acha pelo nome da categoria: quem digita "cobranca" quer
    // os templates daquela area, e nao so os que tem a palavra no nome.
    return (
      template.name.toLowerCase().includes(term) ||
      (category?.name || '').toLowerCase().includes(term)
    );
  });
});

const getTemplateBody = template => {
  return findComponentByType(template, COMPONENT_TYPES.BODY)?.text || '';
};

const getTemplateHeader = template => {
  return findComponentByType(template, COMPONENT_TYPES.HEADER);
};

const getTemplateFooter = template => {
  return findComponentByType(template, COMPONENT_TYPES.FOOTER);
};

const getTemplateButtons = template => {
  return findComponentByType(template, COMPONENT_TYPES.BUTTONS);
};

const hasMediaContent = template => {
  const header = getTemplateHeader(template);
  return header && MEDIA_FORMATS.includes(header.format);
};

const refreshTemplates = async () => {
  isRefreshing.value = true;
  try {
    await store.dispatch('inboxes/syncTemplates', props.inboxId);
    useAlert(t('WHATSAPP_TEMPLATES.PICKER.REFRESH_SUCCESS'));
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATES.PICKER.REFRESH_ERROR'));
  } finally {
    isRefreshing.value = false;
  }
};
</script>

<template>
  <div class="w-full">
    <div class="flex gap-2 mb-2.5">
      <div
        class="flex flex-1 gap-1 items-center px-2.5 py-0 min-w-0 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 focus-within:outline-n-brand dark:focus-within:outline-n-brand"
      >
        <fluent-icon icon="search" class="text-n-slate-12" size="16" />
        <input
          v-model="query"
          type="search"
          :placeholder="t('WHATSAPP_TEMPLATES.PICKER.SEARCH_PLACEHOLDER')"
          class="reset-base w-full h-9 bg-transparent text-n-slate-12 !text-sm !outline-0"
        />
      </div>
      <!-- ComboBox e nao <select>: com muitas categorias, achar a certa numa
           lista nativa vira rolagem. Ele ja traz busca embutida. -->
      <!-- A largura vai no wrapper: a raiz do ComboBox tem `w-full` cravado,
           entao passar `w-40` para ele nao adianta — ele ocupava a linha toda e
           espremia a busca e o botao de atualizar. -->
      <div v-if="categories.length" class="w-48 shrink-0">
        <ComboBox
          v-model="selectedCategoryId"
          :options="categoryOptions"
          :search-placeholder="
            t('WHATSAPP_TEMPLATES.PICKER.LABELS.SEARCH_CATEGORY')
          "
          :empty-state="t('WHATSAPP_TEMPLATES.PICKER.LABELS.NO_CATEGORY_FOUND')"
        />
      </div>
      <button
        :disabled="isRefreshing"
        class="flex justify-center items-center w-9 h-9 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 hover:bg-n-alpha-2 dark:hover:bg-n-solid-2 disabled:opacity-50 disabled:cursor-not-allowed"
        :title="t('WHATSAPP_TEMPLATES.PICKER.REFRESH_BUTTON')"
        @click="refreshTemplates"
      >
        <Icon
          icon="i-lucide-refresh-ccw"
          class="text-n-slate-12 size-4"
          :class="{ 'animate-spin': isRefreshing }"
        />
      </button>
    </div>
    <div
      class="bg-n-background outline-n-container outline outline-1 rounded-lg max-h-[min(18.75rem,50dvh)] overflow-y-auto p-2.5"
    >
      <div v-for="(template, i) in filteredTemplateMessages" :key="template.id">
        <button
          class="block p-2.5 w-full text-left rounded-lg cursor-pointer hover:bg-n-alpha-2 dark:hover:bg-n-solid-2"
          @click="emit('onSelect', template)"
        >
          <div>
            <div class="flex justify-between items-center gap-2 mb-2.5">
              <p class="text-sm min-w-0 truncate">
                {{ template.name }}
              </p>
              <span
                v-if="categoryFor(template)"
                class="inline-flex gap-1.5 items-center px-2 py-1 text-xs leading-none rounded-lg cursor-default shrink-0 bg-n-slate-3 text-n-slate-12"
              >
                <span
                  class="rounded-full size-2 shrink-0"
                  :style="{
                    backgroundColor: categoryFor(template).color || '#1f93ff',
                  }"
                />
                {{ categoryFor(template).name }}
              </span>
              <span
                class="inline-block px-2 py-1 text-xs leading-none rounded-lg cursor-default shrink-0 bg-n-slate-3 text-n-slate-12"
              >
                {{
                  `${t('WHATSAPP_TEMPLATES.PICKER.LABELS.LANGUAGE')}: ${template.language}`
                }}
              </span>
            </div>
            <!-- Header -->
            <div v-if="getTemplateHeader(template)" class="mb-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.HEADER') || 'HEADER' }}
              </p>
              <div
                v-if="getTemplateHeader(template).format === 'TEXT'"
                class="text-sm label-body"
              >
                {{ getTemplateHeader(template).text }}
              </div>
              <div
                v-else-if="hasMediaContent(template)"
                class="text-sm italic text-n-slate-11"
              >
                {{
                  t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT', {
                    format: getTemplateHeader(template).format,
                  }) ||
                  `${getTemplateHeader(template).format} ${t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT_FALLBACK')}`
                }}
              </div>
            </div>

            <!-- Body -->
            <div>
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BODY') || 'BODY' }}
              </p>
              <p class="text-sm label-body">{{ getTemplateBody(template) }}</p>
            </div>

            <!-- Footer -->
            <div v-if="getTemplateFooter(template)" class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.FOOTER') || 'FOOTER' }}
              </p>
              <p class="text-sm label-body">
                {{ getTemplateFooter(template).text }}
              </p>
            </div>

            <!-- Buttons -->
            <div v-if="getTemplateButtons(template)" class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BUTTONS') || 'BUTTONS' }}
              </p>
              <div class="flex flex-wrap gap-1 mt-1">
                <span
                  v-for="button in getTemplateButtons(template).buttons"
                  :key="button.text"
                  class="px-2 py-1 text-xs rounded bg-n-slate-3 text-n-slate-12"
                >
                  {{ button.text }}
                </span>
              </div>
            </div>

            <div class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.CATEGORY') || 'CATEGORY' }}
              </p>
              <p class="text-sm">{{ template.category }}</p>
            </div>
          </div>
        </button>
        <hr
          v-if="i != filteredTemplateMessages.length - 1"
          :key="`hr-${i}`"
          class="border-b border-solid border-n-weak my-2.5 mx-auto max-w-[95%]"
        />
      </div>
      <div v-if="!filteredTemplateMessages.length" class="py-8 text-center">
        <div v-if="query && whatsAppTemplateMessages.length">
          <p>
            {{ t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_FOUND') }}
            <strong>{{ query }}</strong>
          </p>
        </div>
        <div v-else-if="!whatsAppTemplateMessages.length" class="space-y-4">
          <p class="text-n-slate-11">
            {{ t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_AVAILABLE') }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.label-body {
  font-family: monospace;
}
</style>
