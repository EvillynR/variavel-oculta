# Prompt 3 — andamento inicial (interface de enigmas)

## O que foi acrescentado nesta cópia
- `scripts/puzzles/puzzle_ui.gd`: camada de interface que apresenta enunciados, alternativas ou entrada textual; mostra pistas descobertas relacionadas ao enigma; envia respostas ao `PuzzleManager` existente; pausa o jogo enquanto a interface está aberta; permite fechar com Esc.
- `scenes/main.tscn`: adiciona a camada `PuzzleUI`, sem remover os sistemas já existentes.

## Como se integra ao projeto
- Continua usando `data/game_data.json` como fonte de dados.
- Continua usando `PuzzleManager`, `ClueManager`, `AnswerValidator` e os dados já existentes; não cria um segundo validador nem altera respostas corretas.
- Neste primeiro corte, a interface só abre enigmas associados à `room_1`, a única sala que os dados identificam como conteúdo de teste jogável. Salas pendentes e enigmas de `room_test` não abrem a interface fora de contexto.
- Ao resolver um enigma e liberar outro, o próximo fica na fila e aparece depois de fechar o painel atual.

## Verificações realizadas
- JSON parseável; seis salas presentes.
- Script referenciado pela cena principal existe.
- Referências do painel ao PuzzleManager e ClueManager apontam para os nós da cena principal.
- Verificação estática de integração e delegação de respostas ao PuzzleManager concluída.

## Limitação importante
O executável do Godot não está disponível neste ambiente; portanto, esta cópia ainda **não foi executada no Godot**. A interface é uma primeira parte do Prompt 3, não a conclusão de todo o Prompt 3. Ainda faltam validar o painel no jogo, desenvolver conteúdo definitivo (os enigmas atuais estão marcados como teste), implementar a apresentação de pistas/documentos de forma mais completa e ligar os mecanismos de progressão/saída à jogabilidade.

## Preservação
O ZIP de entrada não foi alterado. Esta versão foi construída a partir de uma cópia de trabalho e inclui os arquivos originais do projeto, além deste relatório.
