#!/usr/bin/env bash
# Sobe um Chatwoot de verdade (a imagem em CHATWOOT_IMAGE) e a LIA de verdade (o código em
# LIA_DIR), cada um com o seu banco descartável, semeia os dois e roda o Playwright.
# Nada aponta para produção: Chatwoot, Evolution e WooCommerce da LIA vão para endereços
# locais, e tudo é apagado no fim, mesmo se o teste falhar. CHATWOOT_DOCKER_ARGS acrescenta
# opções ao container (ex.: -v de um arquivo corrigido, para provar antes de reconstruir).
#
# Máquina em que o container não alcança o host (firewall barra a rede do Docker, o
# Chatwoot dá Net::OpenTimeout ao chamar a LIA) ou em que o Docker gastou as faixas de
# rede ("all predefined address pools have been fully subnetted"): rode com
# LIA_E2E_HOST_NETWORK=1. O Chatwoot usa a rede do host e fala com a LIA, o Postgres e o
# Redis por 127.0.0.1; nenhuma rede do Docker é criada.
#
#   CHATWOOT_IMAGE=chatwoot-locfit:autocompletar LIA_DIR=../LIA-2.0-falha \
#     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh
# A chave do Gemini é a de homologação: a LIA a exige ao importar, e a sugestão por
# pergunta, que o painel pede ao abrir a conversa, a usa de verdade.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${CHATWOOT_IMAGE:?informe CHATWOOT_IMAGE}"
LIA_DIR="$(cd "${LIA_DIR:?informe LIA_DIR (raiz do LIA-2.0)}" && pwd)"
PYTHON="${LIA_PYTHON:-$LIA_DIR/../LIA-2.0/.venv/bin/python}"
TAG="$(echo "$IMAGE" | tr ':/' '__')"
OUT="${E2E_OUT:-$HERE/artifacts/$TAG-$(date +%Y%m%d-%H%M%S)}"
NET=lia-e2e
CW=lia-e2e-chatwoot
CW_PORT=3998
LIA_PORT=8011
LIA_PG_PORT=5546
CW_PG_PORT=5547
CW_REDIS_PORT=6397
HOSTNET="${LIA_E2E_HOST_NETWORK:-}"
if [ -n "$HOSTNET" ]; then
  GATEWAY=127.0.0.1
else
  GATEWAY="$(docker network inspect bridge -f "{{(index .IPAM.Config 0).Gateway}}")"
fi
mkdir -p "$OUT"

cleanup() {
  set +e
  docker logs "$CW" > "$OUT/chatwoot.log" 2>&1
  [ -n "${LIA_PID:-}" ] && kill "$LIA_PID" 2>/dev/null
  docker rm -f "$CW" lia-e2e-cw-pg lia-e2e-redis lia-e2e-lia-pg > /dev/null 2>&1
  docker network rm "$NET" > /dev/null 2>&1
}
trap cleanup EXIT
cleanup > /dev/null 2>&1 || true
if curl -s -o /dev/null "http://$GATEWAY:$LIA_PORT/health"; then
  echo "a porta $LIA_PORT já está em uso (LIA de outra rodada?)"; exit 1
fi

if [ -n "$HOSTNET" ]; then
  docker run -d --name lia-e2e-cw-pg -p 127.0.0.1:$CW_PG_PORT:5432 -e POSTGRES_PASSWORD=pg pgvector/pgvector:pg17 > /dev/null
  docker run -d --name lia-e2e-redis -p 127.0.0.1:$CW_REDIS_PORT:6379 redis:7-alpine > /dev/null
  CW_NET_ARGS=(--network host -e POSTGRES_HOST=127.0.0.1 -e POSTGRES_PORT=$CW_PG_PORT
               -e REDIS_URL="redis://127.0.0.1:$CW_REDIS_PORT" -e LIA_API_URL="http://127.0.0.1:$LIA_PORT")
  CW_BIND=127.0.0.1
else
  docker network create "$NET" > /dev/null
  docker run -d --name lia-e2e-cw-pg --network "$NET" -e POSTGRES_PASSWORD=pg pgvector/pgvector:pg17 > /dev/null
  docker run -d --name lia-e2e-redis --network "$NET" redis:7-alpine > /dev/null
  CW_NET_ARGS=(--network "$NET" -p 127.0.0.1:$CW_PORT:3000 --add-host host.docker.internal:host-gateway
               -e POSTGRES_HOST=lia-e2e-cw-pg -e POSTGRES_PORT=5432
               -e REDIS_URL=redis://lia-e2e-redis:6379 -e LIA_API_URL="http://host.docker.internal:$LIA_PORT")
  CW_BIND=0.0.0.0
fi
docker run -d --name lia-e2e-lia-pg -p 127.0.0.1:$LIA_PG_PORT:5432 \
  -e POSTGRES_USER=lia -e POSTGRES_PASSWORD=lia_e2e -e POSTGRES_DB=lia_e2e pgvector/pgvector:pg17 > /dev/null
until docker exec lia-e2e-lia-pg pg_isready -U lia -d lia_e2e > /dev/null 2>&1; do sleep 1; done

echo "== LIA ($LIA_DIR)"
LIA_ENV=(
  DATABASE_URL="postgresql+asyncpg://lia:lia_e2e@127.0.0.1:$LIA_PG_PORT/lia_e2e"
  ADMIN_API_TOKEN=e2e-token
  CHATWOOT_BASE_URL="http://127.0.0.1:$CW_PORT" CHATWOOT_API_ACCESS_TOKEN=e2e-sem-acesso
  EVOLUTION_API_URL=http://127.0.0.1:9 EVOLUTION_API_KEY=e2e
  WOOCOMMERCE_URL=http://127.0.0.1:9 GOOGLE_API_KEY="${GOOGLE_API_KEY:?rode com: cofre run GOOGLE_API_KEY=gemini-homolog -- $0}"
  OPENAI_API_KEY= DEEPSEEK_API_KEY=
  TELEGRAM_BOT_TOKEN= CLICKUP_TOKEN= PYTHONPATH="$LIA_DIR"
)
# A Jev decide se alguma resposta pronta serve à mensagem (faixa-na-hora.spec.mjs espera
# o "sem sugestão segura" dela). A chave vem do ambiente ou de ~/jev.key e nunca é impressa;
# sem ela a decisão falha e a faixa fica vazia.
JEV_KEY="${JEV_API_KEY:-}"
if [ -z "$JEV_KEY" ] && [ -r "$HOME/jev.key" ]; then JEV_KEY="$(tr -d '[:space:]' < "$HOME/jev.key")"; fi
LIA_ENV+=(JEV_API_KEY="$JEV_KEY")
# Roda fora da raiz da LIA para não ler um .env que aponte para produção.
(cd "$OUT" && exec env "${LIA_ENV[@]}" "$PYTHON" -m uvicorn src.api.main:app \
  --host "$GATEWAY" --port $LIA_PORT > "$OUT/lia.log" 2>&1) &
LIA_PID=$!
until curl -sf "http://$GATEWAY:$LIA_PORT/health" > /dev/null 2>&1; do
  kill -0 "$LIA_PID" 2>/dev/null || { tail -30 "$OUT/lia.log"; exit 1; }
  sleep 1
done
(cd "$LIA_DIR" && env "${LIA_ENV[@]}" "$PYTHON" -m alembic upgrade head > "$OUT/alembic.log" 2>&1)

echo "== Chatwoot ($IMAGE)"
# O Sidekiq sobe junto: é ele que entrega à tela, em tempo real, a mensagem que chega
# (faixa-na-hora.spec.mjs depende disso).
CW_LISTEN=3000
[ -n "$HOSTNET" ] && CW_LISTEN=$CW_PORT
docker run -d --name "$CW" "${CW_NET_ARGS[@]}" \
  -e RAILS_ENV=production -e NODE_ENV=production -e RAILS_LOG_TO_STDOUT=true \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" -e FRONTEND_URL="http://127.0.0.1:$CW_PORT" \
  -e FORCE_SSL=false -e ENABLE_ACCOUNT_SIGNUP=false \
  -e POSTGRES_USERNAME=postgres -e POSTGRES_PASSWORD=pg -e POSTGRES_DATABASE=chatwoot \
  -e LIA_ADMIN_API_TOKEN=e2e-token \
  ${CHATWOOT_DOCKER_ARGS:-} --entrypoint docker/entrypoints/rails.sh "$IMAGE" \
  sh -c "bundle exec rails db:chatwoot_prepare && (bundle exec sidekiq -C config/sidekiq.yml > /tmp/sidekiq.log 2>&1 &) && bundle exec rails s -b $CW_BIND -p $CW_LISTEN" > /dev/null
for _ in $(seq 1 180); do
  curl -sf "http://127.0.0.1:$CW_PORT/api" > /dev/null 2>&1 && break
  sleep 2
done
curl -sf "http://127.0.0.1:$CW_PORT/api" > /dev/null || { docker logs --tail 50 "$CW"; exit 1; }

# A primeira página cria as chaves de notificação (VAPID_KEYS); com os testes em
# paralelo, duas visitas ao mesmo tempo batem na chave única e uma recebe 500.
curl -sf -o /dev/null "http://127.0.0.1:$CW_PORT/app/login" || { docker logs --tail 50 "$CW"; exit 1; }

docker cp "$HERE/seed.rb" "$CW:/tmp/seed.rb"
SEED="$(docker exec "$CW" bundle exec rails runner /tmp/seed.rb 2> "$OUT/seed.err" | tail -1)"
echo "$SEED" > "$OUT/seed.json"
read -r ACCOUNT INBOX CONV ACCOUNT2 INBOX2 CONV2 ACCOUNT3 INBOX3 CONV3 ACCOUNT4 INBOX4 CONV4 ACCOUNT5 INBOX5 \
  ACCOUNT6 INBOX6 CONV6 ACCOUNT7 INBOX7 CONV7 < <(node -e '
  const s = JSON.parse(process.argv[1]);
  const a = s.apresentacao;
  const m = s.meio;
  const k = s.atalho;
  const e = s.estado;
  const f = s.faixa;
  const c = s.copiloto;
  console.log(s.account_id, s.inbox_id, s.conversation_id, a.account_id, a.inbox_id, a.conversation_id,
              m.account_id, m.inbox_id, m.conversation_id, k.account_id, k.inbox_id, k.conversation_id,
              e.account_id, e.inbox_id, f.account_id, f.inbox_id, f.conversation_id,
              c.account_id, c.inbox_id, c.conversation_id)' "$SEED")

# A conversa como a LIA a conhece (o Chatwoot a encontra pelo display_id) e a resposta
# rápida que o autocompletar deve oferecer.
docker exec -i lia-e2e-lia-pg psql -q -v ON_ERROR_STOP=1 -U lia -d lia_e2e <<SQL
INSERT INTO conversation_flow_status
  (id, session_id, phone_number, current_step, sector, is_interrupted, flow_data,
   created_at, updated_at, input_tokens, output_tokens, total_tokens)
VALUES (gen_random_uuid(), 'e2e-5511999990000', '5511999990000', 'ONBOARDING_AGENT', 'vendas',
        false, '{"chatwoot_account_id": $ACCOUNT, "chatwoot_inbox_id": $INBOX,
                 "chatwoot_conversation_id": $CONV, "push_name": "Paula Souza"}',
        now(), now(), 0, 0, 0),
       (gen_random_uuid(), 'e2e-5511999990001', '5511999990001', 'ONBOARDING_AGENT', 'vendas',
        false, '{"chatwoot_account_id": $ACCOUNT2, "chatwoot_inbox_id": $INBOX2,
                 "chatwoot_conversation_id": $CONV2, "push_name": "Paula Souza"}',
        now(), now(), 0, 0, 0),
       (gen_random_uuid(), 'e2e-5511999990002', '5511999990002', 'ONBOARDING_AGENT', 'vendas',
        false, '{"chatwoot_account_id": $ACCOUNT3, "chatwoot_inbox_id": $INBOX3,
                 "chatwoot_conversation_id": $CONV3, "push_name": "Paula Souza"}',
        now(), now(), 0, 0, 0),
       (gen_random_uuid(), 'e2e-5511999990003', '5511999990003', 'ONBOARDING_AGENT', 'vendas',
        false, '{"chatwoot_account_id": $ACCOUNT4, "chatwoot_inbox_id": $INBOX4,
                 "chatwoot_conversation_id": $CONV4, "push_name": "Paula Souza"}',
        now(), now(), 0, 0, 0);
INSERT INTO quick_replies (id, store_id, title, shortcut, body, description, active, created_at, updated_at)
VALUES (gen_random_uuid(), NULL, 'Planos', 'planos',
        'Temos planos de aluguel a partir de R\$ 189,90 por mês, com entrega e manutenção inclusas. Quer que eu te mande as opções?',
        'Preço dos planos', true, now(), now()),
-- Começa com "A": a atendente costuma digitar sem ele (autocompletar-meio).
       (gen_random_uuid(), NULL, 'Site', 'site',
        'A locação é feita pelo nosso site: https://loc.fit/loja. Lá você escolhe o plano e a data da entrega.',
        'Onde alugar', true, now(), now());
-- Apresentações de outras atendentes no histórico importado (autocompletar-apresentacao).
-- Numa conta do Chatwoot que não é de nenhum teste: não entram nas métricas do relatório.
INSERT INTO reply_history_pairs
  (id, store_id, question, reply, chatwoot_account_id, chatwoot_inbox_id,
   chatwoot_conversation_id, chatwoot_message_id, replied_at, created_at)
VALUES
  (gen_random_uuid(), NULL, 'oi', 'Bom dia Ana, tudo bem? Aqui é a Brenda, vou continuar seu atendimento hoje.',
   $((ACCOUNT + 1000)), 1, 900001, 900001, now() - interval '3 days', now()),
  (gen_random_uuid(), NULL, 'oi', 'Boa tarde Lucas, tudo bem? Aqui é a Brenda, vou continuar seu atendimento hoje.',
   $((ACCOUNT + 1000)), 1, 900002, 900002, now() - interval '2 days', now()),
  (gen_random_uuid(), NULL, 'oi', 'Bom dia Rui, tudo bem? Aqui é o Fernando, vou continuar seu atendimento hoje.',
   $((ACCOUNT + 1000)), 1, 900003, 900003, now() - interval '1 day', now());
-- faixa-na-hora: conversa atendida por humano (pausada), com a pergunta antiga da cliente
-- e a sugestão dela já decidida e à vista. A mensagem nova chega durante o teste.
WITH conversa AS (
  INSERT INTO conversation_flow_status
    (id, session_id, phone_number, current_step, sector, is_interrupted, interrupted_at, flow_data,
     created_at, updated_at, input_tokens, output_tokens, total_tokens)
  VALUES (gen_random_uuid(), 'e2e-5511999990005', '5511999990005', 'ONBOARDING_AGENT', 'vendas',
          true, now(), '{"chatwoot_account_id": $ACCOUNT6, "chatwoot_inbox_id": $INBOX6,
                         "chatwoot_conversation_id": $CONV6, "push_name": "Paula Souza"}',
          now(), now(), 0, 0, 0)
  RETURNING id
), pergunta AS (
  INSERT INTO conversation_messages (id, conversation_id, role, content, created_at)
  SELECT gen_random_uuid(), id, 'user', 'Oi, quero alugar uma bike. Quanto custa?', now() - interval '5 minutes'
  FROM conversa
  RETURNING id, conversation_id
)
INSERT INTO reply_suggestions
  (id, conversation_id, trigger_message_id, text, source, confidence, shown, outcome, created_at)
SELECT gen_random_uuid(), conversation_id, id, 'Sugestão da pergunta antiga: nossos planos começam em R\$ 189,90 por mês.',
       'history', 0.9, true, 'pending', now() - interval '4 minutes'
FROM pergunta;
-- autocompletar-lia: conversa da loja 778, a única com o autocompletar escrito pela LIA
-- ligado, e a resposta rápida dela (as outras lojas não a veem).
INSERT INTO conversation_flow_status
  (id, session_id, phone_number, current_step, sector, is_interrupted, interrupted_at, flow_data, store_id,
   created_at, updated_at, input_tokens, output_tokens, total_tokens)
VALUES (gen_random_uuid(), 'e2e-5511999990006', '5511999990006', 'ONBOARDING_AGENT', 'vendas',
        true, now(), '{"chatwoot_account_id": $ACCOUNT7, "chatwoot_inbox_id": $INBOX7,
                       "chatwoot_conversation_id": $CONV7, "push_name": "Paula Souza"}', '778',
        now(), now(), 0, 0, 0);
INSERT INTO conversation_messages (id, conversation_id, role, content, created_at)
SELECT gen_random_uuid(), id, 'user', 'Como funciona a locação?', now() - interval '2 minutes'
FROM conversation_flow_status WHERE phone_number = '5511999990006';
INSERT INTO quick_replies (id, store_id, title, shortcut, body, description, active, created_at, updated_at)
VALUES (gen_random_uuid(), '778', 'Processo', 'processo',
        'Todo o processo de locação é feito pelo nosso site: você escolhe o equipamento e o plano, cadastra o endereço de entrega e paga com cartão de crédito.',
        'Como funciona a locação', true, now(), now());
INSERT INTO system_settings (key, value, updated_at)
VALUES ('__store__:778:reply_compose_generative', 'true', now());
-- A caixa da "Loja E2E 5" pertence à loja 777 (lia-estado). As outras ficam sem loja.
INSERT INTO system_settings (key, value, updated_at)
VALUES ('chatwoot_inboxes', '[{"account_id": $ACCOUNT5, "inbox_id": $INBOX5, "store_id": 777}]', now());
SQL

echo "== Playwright -> $OUT"
cd "$HERE"
set +e
E2E_SEED="$SEED" E2E_OUT="$OUT" CHATWOOT_URL="http://127.0.0.1:$CW_PORT" \
  LIA_URL="http://$GATEWAY:$LIA_PORT" LIA_PG_CONTAINER=lia-e2e-lia-pg npx playwright test "$@" 2>&1 | tee "$OUT/playwright.log"
STATUS=${PIPESTATUS[0]}
echo "status=$STATUS" >> "$OUT/playwright.log"
exit "$STATUS"
