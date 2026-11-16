"""Faz a passagem para a equipe com o código da LIA contra o Chatwoot do E2E.

É o mesmo `team_handoff.announce` que o turno da LIA chama quando ela usa
`interrupt_flow`; aqui ele roda sozinho, sem o Gemini, para a prova não depender
de o modelo decidir transferir. Uso (o lia-avisos.spec.mjs chama):
  python lia-passagem.py <chatwoot_url> <token> <account_id> <conversation_display_id>
"""

import asyncio
import json
import sys

from src.api.whatsapp import EvolutionAPIClient
from src.services import team_handoff


async def main(url: str, token: str, account_id: str, conversation_id: str) -> None:
    client = EvolutionAPIClient(base_url=url, api_key=token)
    contexto = {"chatwoot_account_id": int(account_id), "chatwoot_conversation_id": int(conversation_id)}
    nota = team_handoff.note_text(
        "Cliente quer saber da entrega em Joinville e pediu uma pessoa",
        "vendas",
        "Vocês entregam em Joinville?",
        "Vou te passar para a equipe, que continua por aqui.",
    )
    resultado = await team_handoff.announce(client, "e2e", contexto, conversation_id, nota)
    print(json.dumps(resultado))


if __name__ == "__main__":
    asyncio.run(main(*sys.argv[1:5]))
