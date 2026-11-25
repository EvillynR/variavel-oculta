# Sistema de monstros — estado desta entrega

## Backup e base
Esta entrega foi construída sobre a base `Prompt3_Final_work/Jogo 3D`, preservando os sistemas de enigmas, progressão, percepção, audição, navegação e os recursos atuais. Um backup separado foi mantido antes das alterações.

## Comportamentos adicionados ao controlador
- **O Polvo (octopus):** mantém o comportamento de referência: visão, audição configurada, investigação, perseguição, busca e retorno conforme a máquina de estados existente.
- **O Ângulo (angle):** tenta interceptar a última posição conhecida por um ponto lateral navegável; a rota continua sendo calculada pelo `NavigationAgent3D`, sem movimento deliberado através de paredes.
- **A Pintora (painter):** reação visual mais lenta, perseguição menos veloz e sinal `mechanic_cue` ao iniciar perseguição para que a UI/ambiente possa comunicar uma pista visual de perigo.
- **O Leitor (reader):** perseguição mais rápida e sinal `false_voice_emitted` durante investigação para comunicar uma mensagem suspeita sem depender de dublagem.
- **O Cartógrafo (cartographer):** amplia a área e a quantidade de pontos durante a busca, usando pontos projetados para navegação.
- **O Maestro (maestro):** a visão não inicia perseguição; depende do sistema `SoundStimulus` já existente. Deve receber estímulos sonoros de fontes jogáveis para ter comportamento completo.

## Limitações que permanecem
- Só O Polvo está instanciado no cenário principal nesta base. Os outros cinco ainda precisam de instâncias físicas, pontos de origem, regiões de navegação e gatilhos narrativos nos cenários correspondentes para serem jogáveis em cena.
- Os sinais `mechanic_cue` e `false_voice_emitted` são APIs para pistas; ainda não existe uma interface/objeto visual conectado a esses sinais nesta entrega.
- O jogo não tem fluxo de captura ligado a uma tela de Game Over/reinício/checkpoint comprovado nesta entrega.
- O uso de agachar/correr já existe no player, mas esconder-se não foi confirmado como mecânica integrada. Não afirmar furtividade completa.
- Os braços do Polvo continuam dependentes de modelo/animações artísticas.
- O Maestro depende de fontes de som jogáveis; o perfil de audição sozinho não gera sons.

## Verificações
- `data/game_data.json` validado com o parser JSON: 6 salas e 6 definições de monstros.
- Não foi possível executar testes em runtime: não há executável Godot disponível neste ambiente. Portanto, esta entrega não declara os seis monstros como totalmente jogáveis nem declara testes de perseguição/captura concluídos.
