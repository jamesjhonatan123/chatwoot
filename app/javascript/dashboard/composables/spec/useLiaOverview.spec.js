// Revisão do Gemini no PR #18. Formas de falhar:
// - duas atualizações ao mesmo tempo (foco + relógio) e a resposta mais antiga chega
//   por último: a faixa volta a mostrar a LIA parada logo depois de religada;
// - ao sair do painel (logout), o título da aba fica com o "(2) " para sempre.
import { defineComponent, h } from 'vue';
import { mount } from '@vue/test-utils';
import LiaOverviewAPI from 'dashboard/api/liaOverview';
import {
  refreshLiaOverview,
  useLiaOverview,
} from 'dashboard/composables/useLiaOverview';

vi.mock('dashboard/api/liaOverview', () => ({ default: { get: vi.fn() } }));

const adiado = () => {
  let resolve;
  const promise = new Promise(r => {
    resolve = r;
  });
  return { promise, resolve };
};
const tick = () =>
  new Promise(r => {
    setTimeout(r, 0);
  });
const resposta = count => ({ data: { waiting: { count }, stores: [] } });

const Consumidor = defineComponent({
  setup() {
    return useLiaOverview();
  },
  render() {
    return h('div', String(this.waitingCount));
  },
});

describe('useLiaOverview', () => {
  beforeEach(() => {
    document.title = 'Chatwoot';
    LiaOverviewAPI.get.mockReset();
  });

  it('ignora a resposta mais antiga que chega depois da mais nova', async () => {
    const velha = adiado();
    const nova = adiado();
    LiaOverviewAPI.get
      .mockReturnValueOnce(velha.promise)
      .mockReturnValueOnce(nova.promise);
    const wrapper = mount(Consumidor);
    const segunda = refreshLiaOverview();

    nova.resolve(resposta(0));
    await segunda;
    velha.resolve(resposta(2));
    await tick();

    expect(wrapper.vm.waitingCount).toBe(0);
    expect(document.title).toBe('Chatwoot');
    wrapper.unmount();
  });

  it('tira o contador do título ao sair do painel', async () => {
    LiaOverviewAPI.get.mockResolvedValue(resposta(2));
    const wrapper = mount(Consumidor);
    await tick();
    expect(document.title).toBe('(2) Chatwoot');

    wrapper.unmount();

    expect(document.title).toBe('Chatwoot');
  });
});
