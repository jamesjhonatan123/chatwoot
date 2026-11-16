// Um so pedido a cada minuto para a faixa, o contador do menu e a fila: os tres
// leem o mesmo estado. Enquanto algum estiver na tela, atualiza; sem nenhum, para.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import LiaOverviewAPI from 'dashboard/api/liaOverview';
import { titleWithCount } from 'dashboard/helper/liaOverview';

const REFRESH_MS = 60000;
const overview = ref(null);
const loading = ref(false);
let users = 0;
let timer = null;

const applyTitle = () => {
  if (typeof document === 'undefined') return;
  document.title = titleWithCount(
    document.title,
    overview.value?.waiting?.count || 0
  );
};

export const refreshLiaOverview = async () => {
  loading.value = true;
  try {
    const { data } = await LiaOverviewAPI.get();
    overview.value = data;
  } catch {
    // Sem resposta, mantem o ultimo estado: a faixa nao pisca a cada falha de rede.
  } finally {
    loading.value = false;
    applyTitle();
  }
};

const onFocus = () => refreshLiaOverview();

export function useLiaOverview() {
  onMounted(() => {
    users += 1;
    if (users === 1) {
      refreshLiaOverview();
      timer = setInterval(refreshLiaOverview, REFRESH_MS);
      window.addEventListener('focus', onFocus);
    }
  });
  onBeforeUnmount(() => {
    users -= 1;
    if (users === 0) {
      clearInterval(timer);
      window.removeEventListener('focus', onFocus);
    }
  });

  return {
    overview,
    loading,
    waitingCount: computed(() => overview.value?.waiting?.count || 0),
    refresh: refreshLiaOverview,
  };
}
