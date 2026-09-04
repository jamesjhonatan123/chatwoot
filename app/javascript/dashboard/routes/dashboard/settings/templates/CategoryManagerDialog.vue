<script setup>
/**
 * Criar, renomear, recolorir e excluir as categorias proprias de template.
 *
 * O backend das categorias ja existia inteiro desde o commit que criou a
 * funcionalidade — create, update, destroy, assign e unassign — mas a tela so
 * sabia LER: dava para filtrar e para mover um template entre categorias que ja
 * existissem, e nao havia lugar nenhum para criar a primeira. Elas so nasciam
 * por chamada direta a API.
 *
 * Escrita e restrita a administrador pela WhatsappTemplateCategoryPolicy; quem
 * abre este dialogo ja passou pela mesma checagem na tela de templates.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import WhatsappTemplateCategoriesAPI from 'dashboard/api/whatsappTemplateCategories';
import Button from 'dashboard/components-next/button/Button.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  categories: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['changed']);

const { t } = useI18n();

const DEFAULT_COLOR = '#1f93ff';

const dialogRef = ref(null);
const newName = ref('');
const newColor = ref(DEFAULT_COLOR);
const editingId = ref(null);
const editingName = ref('');
const editingColor = ref(DEFAULT_COLOR);
const confirmingDeleteId = ref(null);
const filtro = ref('');
const busyId = ref(null);
const isCreating = ref(false);

const sorted = computed(() => {
  const termo = filtro.value.trim().toLowerCase();

  return [...props.categories]
    .filter(item => !termo || String(item.name).toLowerCase().includes(termo))
    .sort((a, b) =>
      String(a.name).localeCompare(String(b.name), undefined, {
        sensitivity: 'base',
      })
    );
});

// Nome repetido volta como 422 do servidor; barrar aqui evita a ida perdida e
// diz o motivo antes de a pessoa clicar.
const duplicated = computed(() => {
  const name = newName.value.trim().toLowerCase();
  if (!name) return false;
  return props.categories.some(
    item => String(item.name).toLowerCase() === name
  );
});

const canCreate = computed(
  () => Boolean(newName.value.trim()) && !duplicated.value && !isCreating.value
);

const resetForms = () => {
  filtro.value = '';
  newName.value = '';
  newColor.value = DEFAULT_COLOR;
  editingId.value = null;
  confirmingDeleteId.value = null;
};

const open = () => {
  resetForms();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const create = async () => {
  if (!canCreate.value) return;
  isCreating.value = true;
  try {
    await WhatsappTemplateCategoriesAPI.create({
      whatsapp_template_category: {
        name: newName.value.trim(),
        color: newColor.value,
      },
    });
    newName.value = '';
    newColor.value = DEFAULT_COLOR;
    emit('changed');
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const startEdit = category => {
  confirmingDeleteId.value = null;
  editingId.value = category.id;
  editingName.value = category.name;
  editingColor.value = category.color || DEFAULT_COLOR;
};

const cancelEdit = () => {
  editingId.value = null;
};

const saveEdit = async category => {
  const name = editingName.value.trim();
  if (!name) return;
  busyId.value = category.id;
  try {
    await WhatsappTemplateCategoriesAPI.update(category.id, {
      whatsapp_template_category: { name, color: editingColor.value },
    });
    editingId.value = null;
    emit('changed');
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.UPDATE_ERROR'));
  } finally {
    busyId.value = null;
  }
};

const remove = async category => {
  busyId.value = category.id;
  try {
    await WhatsappTemplateCategoriesAPI.delete(category.id);
    confirmingDeleteId.value = null;
    emit('changed');
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DELETE_ERROR'));
  } finally {
    busyId.value = null;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.TITLE')"
    :description="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DONE')"
    width="md"
    overflow-y-auto
    @close="resetForms"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-if="categories.length > 5"
        v-model="filtro"
        size="sm"
        type="search"
        :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.SEARCH')"
      />

      <div v-if="sorted.length" class="flex flex-col divide-y divide-n-weak">
        <div
          v-for="category in sorted"
          :key="category.id"
          class="flex items-center gap-2 py-2 min-w-0"
        >
          <template v-if="editingId === category.id">
            <ColorPicker v-model="editingColor" />
            <Input
              v-model="editingName"
              class="flex-1 min-w-0"
              size="sm"
              @keyup.enter="saveEdit(category)"
              @keyup.esc="cancelEdit"
            />
            <Button
              icon="i-lucide-check"
              color="slate"
              size="sm"
              :is-loading="busyId === category.id"
              :disabled="!editingName.trim()"
              :title="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.SAVE')"
              @click="saveEdit(category)"
            />
            <Button
              icon="i-lucide-x"
              color="slate"
              variant="ghost"
              size="sm"
              :title="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.CANCEL')"
              @click="cancelEdit"
            />
          </template>

          <template v-else-if="confirmingDeleteId === category.id">
            <span class="flex-1 min-w-0 text-sm text-n-slate-11">
              {{
                $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DELETE_CONFIRM', {
                  name: category.name,
                })
              }}
            </span>
            <Button
              :label="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DELETE')"
              color="ruby"
              size="sm"
              :is-loading="busyId === category.id"
              @click="remove(category)"
            />
            <Button
              :label="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.CANCEL')"
              color="slate"
              variant="ghost"
              size="sm"
              @click="confirmingDeleteId = null"
            />
          </template>

          <template v-else>
            <span
              class="size-3 rounded-full shrink-0"
              :style="{ backgroundColor: category.color || DEFAULT_COLOR }"
            />
            <span class="flex-1 min-w-0 text-sm truncate text-n-slate-12">
              {{ category.name }}
            </span>
            <span class="text-xs shrink-0 text-n-slate-10">
              {{
                $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.IN_USE', {
                  n: (category.template_names || []).length,
                })
              }}
            </span>
            <Button
              icon="i-lucide-pencil"
              color="slate"
              variant="ghost"
              size="sm"
              :title="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.RENAME')"
              @click="startEdit(category)"
            />
            <Button
              icon="i-lucide-trash-2"
              color="ruby"
              variant="ghost"
              size="sm"
              :title="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DELETE')"
              @click="confirmingDeleteId = category.id"
            />
          </template>
        </div>
      </div>

      <p v-else class="mb-0 text-sm text-n-slate-11">
        {{
          filtro
            ? $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.NO_RESULTS')
            : $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.EMPTY')
        }}
      </p>

      <form class="flex items-start gap-2" @submit.prevent="create">
        <ColorPicker v-model="newColor" />
        <Input
          v-model="newName"
          class="flex-1 min-w-0"
          size="sm"
          :placeholder="
            $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.NAME_PLACEHOLDER')
          "
          :message="
            duplicated
              ? $t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.DUPLICATED')
              : ''
          "
          :message-type="duplicated ? 'error' : 'info'"
        />
        <Button
          type="submit"
          :label="$t('WHATSAPP_TEMPLATE_MGMT.CATEGORY_MANAGER.ADD')"
          size="sm"
          :is-loading="isCreating"
          :disabled="!canCreate"
        />
      </form>
    </div>
  </Dialog>
</template>
