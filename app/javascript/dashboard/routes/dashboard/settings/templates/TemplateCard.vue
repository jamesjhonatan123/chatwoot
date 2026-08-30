<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

import Button from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  formatTemplateLabel,
  formatTemplateLanguage,
  templateStatusClasses,
  templateTypeKey,
} from './templateUtils';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
  // Categoria propria da conta ("Vendas", "Cobranca"), nao a da Meta.
  category: {
    type: Object,
    default: null,
  },
  categories: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['preview', 'assignCategory']);
const { t } = useI18n();

const isCategoryMenuOpen = ref(false);

const closeCategoryMenu = () => {
  isCategoryMenuOpen.value = false;
};

const categoryMenuItems = computed(() => [
  ...props.categories.map(category => ({
    label: category.name,
    value: category.id,
    isSelected: category.id === props.category?.id,
  })),
  {
    label: t('WHATSAPP_TEMPLATE_MGMT.CATEGORY.REMOVE'),
    value: null,
    isSelected: !props.category,
  },
]);

const onCategoryAction = ({ value }) => {
  closeCategoryMenu();
  emit('assignCategory', value);
};

const showStatus = computed(
  () => props.template.status?.toLowerCase() !== 'approved'
);
const statusLabel = computed(() =>
  props.template.status?.toLowerCase() === 'unsubmitted'
    ? t('WHATSAPP_TEMPLATE_MGMT.STATUSES.UNSUBMITTED')
    : formatTemplateLabel(props.template.status)
);
</script>

<template>
  <div
    class="flex items-center justify-between gap-4 py-4 cursor-pointer group"
    role="button"
    tabindex="0"
    @click="emit('preview')"
    @keydown.enter="emit('preview')"
    @keydown.space.prevent="emit('preview')"
  >
    <div class="flex items-center min-w-0 gap-3">
      <span
        class="grid border rounded-xl shadow-sm size-10 shrink-0 place-items-center bg-n-alpha-3 border-n-strong ring ring-n-solid-1"
      >
        <ChannelIcon
          :inbox="template.inboxes[0]"
          class="size-5 text-n-slate-11"
        />
      </span>
      <div class="flex flex-col min-w-0 gap-1">
        <div class="flex items-center min-w-0 gap-2">
          <span class="truncate text-heading-3 text-n-slate-12">
            {{ template.name }}
          </span>
          <span
            v-if="showStatus"
            class="inline-flex shrink-0 px-2 py-0.5 text-xs font-medium rounded-md"
            :class="templateStatusClasses(template.status)"
          >
            {{ statusLabel }}
          </span>
        </div>
        <div
          class="flex flex-wrap items-center gap-2 text-body-main text-n-slate-11"
        >
          <span>
            {{
              $t(`WHATSAPP_TEMPLATE_MGMT.TYPES.${templateTypeKey(template)}`)
            }}
          </span>
          <div class="w-px h-3 rounded-lg bg-n-strong" />
          <span>{{ formatTemplateLanguage(template.language) }}</span>
          <div class="w-px h-3 rounded-lg bg-n-strong" />
          <span class="truncate">{{ template.inboxNames }}</span>
        </div>
      </div>
    </div>
    <div class="flex items-center gap-2 shrink-0">
      <div v-on-click-outside="closeCategoryMenu" class="relative">
        <button
          type="button"
          class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium border rounded-md border-n-weak text-n-slate-11 hover:bg-n-alpha-1"
          :aria-label="
            $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY.CHANGE', {
              name: template.name,
            })
          "
          @click.stop="isCategoryMenuOpen = !isCategoryMenuOpen"
        >
          <span
            v-if="category"
            class="rounded-full size-2 shrink-0"
            :style="{ backgroundColor: category.color }"
          />
          <span class="truncate max-w-32">
            {{
              category
                ? category.name
                : $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY.NONE')
            }}
          </span>
          <Icon icon="i-lucide-chevron-down" class="shrink-0 size-3" />
        </button>
        <DropdownMenu
          v-if="isCategoryMenuOpen"
          :menu-items="categoryMenuItems"
          class="mt-2 min-w-44 top-full ltr:right-0 rtl:left-0"
          @action="onCategoryAction"
          @click.stop
        />
      </div>
      <Button
        v-tooltip.top="$t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.TITLE')"
        icon="i-lucide-eye"
        color="slate"
        size="sm"
        class="shrink-0"
        :aria-label="
          $t('WHATSAPP_TEMPLATE_MGMT.PREVIEW.OPEN', { name: template.name })
        "
        @click.stop="emit('preview')"
      />
    </div>
  </div>
</template>
