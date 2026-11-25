# Correções após os testes da usuária

## Corrigido nos arquivos
- `monster_room_activation.gd`: tipagem explícita `MonsterConfig` para evitar falha de inferência.
- O Polvo (`room_1`) não desperta apenas ao entrar na sala; o gatilho de despertar permanece sendo a interação explícita definida no JSON/roteador.
- Sala 3: adicionada parede leste com colisão e uma abertura central de porta, fechando os vãos laterais sem bloquear completamente a passagem.
- Câmeras das salas 1–4: reduzida a velocidade de transição para diminuir a troca brusca de enquadramento.
- Modelos provisórios dos monstros usam material neutro escuro; as cores não representam tipos de monstro.

## Ainda precisa de teste dentro do Godot
- Validar que a abertura da parede leste da Sala 3 coincide com o corredor real.
- Ajustar a câmera em movimento real; não há runtime Godot disponível neste ambiente.
- Os outros cinco monstros ainda dependem de validação das camadas de navegação, gatilhos e mecânicas especiais em jogo.
