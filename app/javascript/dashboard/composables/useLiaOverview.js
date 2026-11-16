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
// Cada pedido leva um numero; so o mais recente grava. Foco e relogio podem disparar
// juntos, e a resposta antiga chegando depois faria a faixa voltar ao estado velho.
let latest = 0;

const applyTitle = count => {
  if (typeof document === 'undefined') return;
  document.title = titleWithCount(document.title, count);
};

export const refreshLiaOverview = async () => {
  latest += 1;
  const mine = latest;
  loading.value = true;
  try {
    const { data } = await LiaOverviewAPI.get();
    if (mine !== latest) return;
    overview.value = data;
  } catch {
    // Sem resposta, mantem o ultimo estado: a faixa nao pisca a cada falha de rede.
  } finally {
    if (mine === latest) {
      loading.value = false;
      if (users > 0) applyTitle(overview.value?.waiting?.count || 0);
    }
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
      latest += 1;
      loading.value = false;
      applyTitle(0);
    }
  });

  return {
    overview,
    loading,
    waitingCount: computed(() => overview.value?.waiting?.count || 0),
    refresh: refreshLiaOverview,
  };
}
