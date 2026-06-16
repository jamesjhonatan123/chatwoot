<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SingleSelect from './SingleSelect.vue';

const props = defineProps({
  options: {
    type: Array,
    required: true,
  },
});

const selected = defineModel({
  type: Object,
  required: true,
});

const { t } = useI18n();

const attributeChangedOptions = computed(() => [
  { id: 'any', name: t('AUTOMATION.ATTRIBUTE_CHANGED.ANY_OPTION') },
  { id: 'nil', name: t('AUTOMATION.ATTRIBUTE_CHANGED.UNASSIGNED_OPTION') },
  ...props.options,
]);

const fromValue = computed({
  get: () => selected.value?.from || null,
  set: value => {
    selected.value = {
      ...(selected.value || {}),
      from: value,
      to: selected.value?.to || null,
    };
  },
});

const toValue = computed({
  get: () => selected.value?.to || null,
  set: value => {
    selected.value = {
      ...(selected.value || {}),
      from: selected.value?.from || null,
      to: value,
    };
  },
});
</script>

<template>
  <div class="flex items-center gap-2">
    <div class="flex items-center gap-1">
      <span class="text-sm text-n-slate-11">
        {{ t('AUTOMATION.ATTRIBUTE_CHANGED.FROM_LABEL') }}
      </span>
      <SingleSelect
        v-model="fromValue"
        :options="attributeChangedOptions"
        disable-deselect
        dropdown-max-height="max-h-64"
        :placeholder="t('AUTOMATION.ATTRIBUTE_CHANGED.FROM_PLACEHOLDER')"
      />
    </div>
    <div class="flex items-center gap-1">
      <span class="text-sm text-n-slate-11">
        {{ t('AUTOMATION.ATTRIBUTE_CHANGED.TO_LABEL') }}
      </span>
      <SingleSelect
        v-model="toValue"
        :options="attributeChangedOptions"
        disable-deselect
        dropdown-max-height="max-h-64"
        :placeholder="t('AUTOMATION.ATTRIBUTE_CHANGED.TO_PLACEHOLDER')"
      />
    </div>
  </div>
</template>
