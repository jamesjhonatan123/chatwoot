<script setup>
import { ref, computed, onMounted } from 'vue';
import { useEventListener } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const { modalType, closeOnBackdropClick, onClose } = defineProps({
  closeOnBackdropClick: { type: Boolean, default: true },
  showCloseButton: { type: Boolean, default: true },
  onClose: { type: Function, default: null },
  fullWidth: { type: Boolean, default: false },
  modalType: { type: String, default: 'centered' },
  size: { type: String, default: '' },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });

const modalClassName = computed(() => {
  const modalClassNameMap = {
    centered: '',
    'right-aligned': 'right-aligned',
  };

  return `modal-mask skip-context-menu ${modalClassNameMap[modalType] || ''}`;
});

// [TODO] Revisit this logic to use outside click directive
const mousedDownOnBackdrop = ref(false);

const handleMouseDown = () => {
  mousedDownOnBackdrop.value = true;
};

const close = () => {
  if (!show.value) return;
  show.value = false;
  emit('close');
  onClose?.();
};

const onMouseUp = () => {
  if (!show.value || !mousedDownOnBackdrop.value) {
    mousedDownOnBackdrop.value = false;
    return;
  }

  mousedDownOnBackdrop.value = false;
  if (closeOnBackdropClick) {
    close();
  }
};

const onKeydown = e => {
  if (show.value && e.code === 'Escape') {
    close();
    e.stopPropagation();
  }
};

useEventListener(document.body, 'mouseup', onMouseUp);
useEventListener(document, 'keydown', onKeydown);

onMounted(() => {
  if (import.meta.env.DEV && onClose && typeof onClose === 'function') {
    // eslint-disable-next-line no-console
    console.warn(
      "[DEPRECATED] The 'onClose' prop is deprecated. Please use the 'close' event instead."
    );
  }
});
</script>

<template>
  <TeleportWithDirection to="body">
    <transition name="modal-fade">
      <div
        v-if="show"
        :class="modalClassName"
        transition="modal"
        @mousedown="handleMouseDown"
      >
        <div
          class="relative overflow-auto bg-n-alpha-3 shadow-md modal-container rtl:text-right skip-context-menu"
          :class="{
            'rounded-xl w-full max-w-[37.5rem] my-auto': !fullWidth,
            'items-center rounded-none flex h-full justify-center w-full':
              fullWidth,
            [size]: true,
          }"
          @mousedown="event => event.stopPropagation()"
        >
          <Button
            v-if="showCloseButton"
            ghost
            slate
            icon="i-lucide-x"
            class="absolute z-50 ltr:right-2 rtl:left-2 top-2"
            @click.stop="close"
          />
          <slot />
        </div>
      </div>
    </transition>
  </TeleportWithDirection>
</template>

<style lang="scss">
.modal-mask {
  /* Use overflow + my-auto centering so tall modals scroll instead of clipping on mobile */
  @apply flex justify-center bg-n-alpha-black2 backdrop-blur-[4px] z-[9990] fixed inset-0 w-full overflow-y-auto overscroll-contain p-4;

  .modal-container {
    &.medium {
      @apply max-w-[80%] w-[56.25rem];
    }

    .content {
      @apply p-4 sm:p-8;
    }

    form,
    .modal-content {
      @apply pt-4 pb-6 px-4 sm:pb-8 sm:px-8 self-center;

      a {
        @apply p-4;
      }

      .ProseMirror a {
        @apply p-0;
      }
    }
  }
}

.modal-big {
  @apply w-full max-w-4xl;
}

.modal-mask.right-aligned {
  @apply justify-end p-0;

  .modal-container {
    @apply rounded-none h-full max-h-none w-full max-w-[30rem] my-0;
  }
}

.modal-enter,
.modal-leave {
  @apply opacity-0;
}

.modal-enter .modal-container,
.modal-leave .modal-container {
  transform: scale(1.1);
}
</style>
