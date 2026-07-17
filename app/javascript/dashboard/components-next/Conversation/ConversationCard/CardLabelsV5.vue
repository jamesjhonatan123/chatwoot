<script setup>
import { computed, useSlots, useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  labels: {
    type: Array,
    default: () => [],
  },
});

defineOptions({ inheritAttrs: false });

const attrs = useAttrs();
const slots = useSlots();

const accountLabels = useMapGetter('labels/getLabels');

const activeLabels = computed(() => {
  return accountLabels.value.filter(({ title }) =>
    props.labels.includes(title)
  );
});

const showSection = computed(
  () => activeLabels.value.length > 0 || !!slots.before
);
</script>

<template>
  <div
    v-if="showSection"
    v-bind="attrs"
    data-labels-container
    class="flex items-center flex-wrap min-w-0 min-h-6 gap-x-1.5 gap-y-1 [&:not(:has([data-label],[data-before-slot]))]:hidden"
  >
    <slot name="before" />

    <Label
      v-for="(label, index) in activeLabels"
      :key="label ? label.id : index"
      data-label
      :label="label"
      compact
    />
  </div>
  <template v-else />
</template>
