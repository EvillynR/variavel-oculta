# Sistema de Monstros — continuação de integração

## O que foi alterado nesta continuação
- Mantida esta cópia sobre `Jogo3D_Sistema_Monstros_Entrega.zip`; o ZIP de entrada foi preservado sem sobrescrita.
- Instanciados O Ângulo, A Pintora, O Leitor, O Cartógrafo e O Maestro na cena principal, nas áreas com navegação correspondente.
- Adicionados modelos provisórios simples e substituíveis para que as instâncias não fiquem invisíveis enquanto os modelos finais não existem.
- Criada uma estrutura física provisória para a sala de Música, com chão, teto, paredes, abertura de passagem, volume de sala e região de navegação de camada 32.
- Criado um gatilho provisório de entrada: cada monstro só é despertado quando a protagonista entra na sala que corresponde ao `room_id` do monstro. Os gatilhos de objetos/puzzles já existentes continuam no controlador.
- Criado um fluxo de captura global com tela de Game Over, botão para tentar novamente e opção de retornar ao checkpoint inicial.
- Como ainda não há checkpoints por sala persistidos, os dois botões recarregam a cena; o botão de checkpoint não promete restaurar progresso de sala.
- Atualizados os dados da sala 6 para apontar para a estrutura e navmesh de Música recém-criadas.

## Comportamentos específicos
- O Ângulo: usa interceptação lateral e NavigationAgent3D.
- A Pintora: percepção visual mais lenta e sinal de pista visual de perigo.
- O Leitor: sinal de voz suspeita ao investigar; não depende de dublagem.
- O Cartógrafo: busca ampliada e mais pontos de busca.
- O Maestro: não inicia perseguição por visão e depende de estímulos `SoundStimulus` válidos.
- O Polvo mantém o comportamento de referência existente.

## Verificações estáticas executadas
- `data/game_data.json` parseia corretamente e contém seis salas e seis monstros.
- Todas as referências `res://` encontradas na cena principal apontam para arquivos existentes.
- A cena principal contém as cinco novas instâncias, a estrutura de Música, o volume de Música, a região de navegação e a UI de captura.
- A navegação do Maestro usa a camada 32 e a região correspondente.

## Limitações e validação pendente
- O executável Godot não está disponível neste ambiente; não foi possível importar/rodar o projeto nem validar erros de parser/runtime ou física em execução.
- Os modelos são placeholders geométricos, não modelos artísticos finais.
- A Pintora e o Leitor emitem sinais de pista; ainda precisam de objetos/UI narrativos conectados para que a pista seja visível ao jogador.
- O Maestro tem lógica de reação a estímulos, mas a cena ainda precisa de fontes sonoras jogáveis e pistas visuais explícitas para todos os estímulos.
- O esconderijo ainda não está integrado como mecânica confirmada; caminhar/agachar/correr devem ser validados no jogo.
- Os botões de Game Over recarregam a cena; checkpoints por sala e save/load continuam pendentes.
- O comportamento de todos os monstros, as colisões, as rotas e a câmera precisam de teste dentro do Godot antes de declarar a versão plenamente jogável.
