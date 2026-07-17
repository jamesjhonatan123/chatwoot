<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  conversationLabels: {
    type: Array,
    required: true,
  },
});

const accountLabels = useMapGetter('labels/getLabels');

const activeLabels = computed(() => {
  return accountLabels.value.filter(({ title }) =>
    props.conversationLabels.includes(title)
  );
});
</script>

<template>
  <div>
    <div
      v-if="activeLabels.length || $slots.before"
      class="flex items-end flex-wrap min-w-0 gap-y-1"
    >
      <slot name="before" />
      <woot-label
        v-for="(label, index) in activeLabels"
        :key="label ? label.id : index"
        :title="label.title"
        :description="label.description"
        :color="label.color"
        variant="smooth"
        class="!mb-0 max-w-[calc(100%-0.5rem)]"
        small
      />
    </div>
  </div>
</template>
