<script setup>
import { computed, ref, watch } from 'vue';
import Icon from 'next/icon/Icon.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  active: {
    type: Boolean,
    default: false,
  },
  inbox: {
    type: Object,
    required: true,
  },
  badgeCount: {
    type: [Number, String],
    default: 0,
  },
});

const reauthorizationRequired = computed(() => {
  return props.inbox.reauthorization_required;
});

const isAvatarValid = ref(true);

const channelAvatarUrl = computed(() => props.inbox.avatar_url);

const showChannelAvatar = computed(() => {
  return channelAvatarUrl.value && isAvatarValid.value;
});

const invalidateAvatar = () => {
  isAvatarValid.value = false;
};

watch(
  () => props.inbox.avatar_url,
  () => {
    isAvatarValid.value = true;
  }
);
</script>

<template>
  <span
    class="size-4 grid place-content-center rounded-full overflow-hidden bg-n-alpha-2 flex-shrink-0"
  >
    <img
      v-if="showChannelAvatar"
      :src="channelAvatarUrl"
      :alt="label"
      loading="lazy"
      decoding="async"
      class="size-full object-cover"
      @error="invalidateAvatar"
    />
    <ChannelIcon v-else :inbox="inbox" class="size-4" />
  </span>
  <div class="flex-1 truncate min-w-0">{{ label }}</div>
  <SidebarUnreadBadge :count="badgeCount" />
  <div
    v-if="reauthorizationRequired"
    v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
    class="grid place-content-center size-5 bg-n-ruby-5/60 rounded-full"
  >
    <Icon icon="i-woot-alert" class="size-3 text-n-ruby-9" />
  </div>
</template>
