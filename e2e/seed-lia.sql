-- Fixture da LIA para o E2E (sem dump de homologação: semeado direto).
DELETE FROM reply_suggestions; DELETE FROM api_call_logs; DELETE FROM conversation_messages; DELETE FROM conversation_flow_status;
INSERT INTO conversation_flow_status (id, session_id, phone_number, store_id, flow_name, current_step, sector, is_interrupted, interruption_reason, interrupted_at, last_activity, flow_data, created_at, updated_at)
VALUES ('11111111-1111-4111-8111-111111111111','e2e-ana','5583999990000','7','atendimento','inicio','vendas',true,'human','now()',now(),
 '{"push_name":"Ana Souza","chatwoot_conversation_id":1,"chatwoot_account_id":3,"chatwoot_inbox_id":2}'::jsonb, now(), now());
INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES
 ('22222222-2222-4222-8222-222222222221','11111111-1111-4111-8111-111111111111','assistant','Oi Ana! Sou a assistente da Locfit. Como posso ajudar?', now()-interval '2 minutes'),
 ('22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111','user','Qual o prazo de entrega da bike depois que eu assino?', now()-interval '1 minute');
