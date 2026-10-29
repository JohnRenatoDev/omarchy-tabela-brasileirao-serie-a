# Futebol BR para Omarchy

[English (US)](README.en-US.md) · Português (Brasil)

Placar ao vivo, jogos do dia e classificação na barra do Omarchy: Série A,
Série B, Copa do Brasil, Libertadores e Sul-Americana. Escolha seu time para
receber notificações e comemorações opcionais em todas as competições que ele
disputa. Nome em inglês: **Brazilian Football Scores for Omarchy**.
Antes chamado *Tabela Brasileirão Série A*.

![Painel aberto com a classificação da Série A e os escudos dos 20 clubes](preview.png)

**Imagem ilustrativa:** captura da tabela do Brasileirão Série A exibida pelo
plugin em **20/10/2026**. A classificação pode mudar após essa data. O time
selecionado e os destaques servem apenas para demonstrar a interface e **não
representam as preferências futebolísticas do autor do plugin**.

## Requisitos e instalação

Omarchy 4.0+ com plugins da shell, Quickshell/QtQuick, `curl` 8.4+,
`python3` 3.8+ e `notify-send` (pacote `libnotify`). Internet necessária;
não exige conta, chave de API ou token.

```sh
omarchy plugin add https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a.git --enable
```

O repositório foi renomeado de `omarchy-football` para
`omarchy-tabela-brasileirao-serie-a`. O ID permanente continua
`russio.football`, preservando configurações existentes.
O instalador pede consentimento para adicionar/habilitar o plugin. Não há
instalador que exija elevação de privilégios nem alteração automática de outros plugins.
Se necessário, execute `omarchy restart shell`.

## Uso

Clique na bola ou no placar para abrir o painel; `Q` ou `Esc` fecha o painel.
As setas esquerda/direita alternam as abas quando a busca não está em edição.

| Aba | Conteúdo |
| --- | --- |
| Jogos | Partida do seu time (de qualquer competição) e jogos do dia da competição escolhida. Outra partida seleciona o mandante; clicar na partida já seguida mantém seu time. |
| Tabela | Pontos, jogos, vitórias, empates, derrotas e saldo; nas copas sul-americanas, um bloco por grupo. Clique em um clube para segui-lo. |
| Ajustes | Seu time e as competições em que ele é acompanhado; busca sem acentos em todas as competições (Enter segue o primeiro resultado, Esc limpa); competição exibida; alertas e prévias. |

### Competições

| Competição | Código ESPN | Tabela |
| --- | --- | --- |
| Série A | `bra.1` | Única, 20 clubes |
| Série B | `bra.2` | Única, 20 clubes |
| Copa do Brasil | `bra.copa_do_brazil` | Não há (mata-mata) |
| Libertadores | `conmebol.libertadores` | Fase de grupos (8 × 4) |
| Sul-Americana | `conmebol.sudamericana` | Fase de grupos (8 × 4) |

O time seguido é acompanhado em toda competição do catálogo cuja lista de
participantes da ESPN o inclui, não só na exibida. Exemplo: com a Série A na
tela, um gol do seu time na Libertadores também notifica; a notificação e o
painel indicam a competição. A lista de competições do time aparece em Ajustes.
Série C e Série D não estão no catálogo: a ESPN não publica dados de 2026 para
elas.

A barra mostra o horário local antes do jogo, placar/minuto durante a partida,
`INT` no intervalo e `FIM` no término. O resultado permanece por cerca de 30
minutos após a primeira detecção do fim. Depois aparece a bola, ou o espaço
é oculto se `badgeWhenIdle` for falso. A bola também aparece sem time selecionado.

Comemorações duram aproximadamente 2,6 segundos; o aviso rival, 1,9 segundo.
As superfícies não solicitam foco de teclado e têm região de entrada vazia.
Notificações, comemoração e alerta rival são independentes. Prévias são ações
explícitas e funcionam mesmo com o respectivo efeito automático desligado.

## Configuração

Use os controles do painel. Os ajustes pertencem à entrada `russio.football`
em `~/.config/omarchy/shell.json`. Exemplo de entrada, não de arquivo completo:

```json
{
  "id": "russio.football",
  "league": "bra.1",
  "team": "2674",
  "teamName": "Santos",
  "goalNotifications": true,
  "goalCelebration": true,
  "rivalAlert": true,
  "badgeWhenIdle": true
}
```

| Chave | Padrão | Efeito |
| --- | --- | --- |
| `league` | `bra.1` | Competição exibida; escolha em Ajustes. Aceita os códigos da tabela de competições e, por compatibilidade, outros códigos ESPN como `eng.1`. Inválidos usam `bra.1`. |
| `team` / `teamName` | vazio | ID decimal positivo de até dez dígitos e nome do time seguido. |
| `goalNotifications` | `true` | Notificações de gols, início e fim. |
| `goalCelebration` | `true` | Comemoração automática dos gols do seu time. |
| `rivalAlert` | `true` | Efeito automático quando o adversário marca. |
| `badgeWhenIdle` | `true` | Mantém a bola acessível sem partida. |

A interface está em PT-BR. As faixas seguem os regulamentos de 2026:

| Competição | Faixas |
| --- | --- |
| Série A | 1º–4º Libertadores (azul), 5º Pré-Libertadores (azul-claro), 6º–11º Sul-Americana (rosa), 17º–20º rebaixamento (cor de alerta do tema) |
| Série B | 1º–2º acesso (azul), 3º–6º playoff de acesso (azul-claro), 17º–20º rebaixamento |
| Libertadores | Por grupo: 1º–2º oitavas de final (azul), 3º playoff de oitavas da Sul-Americana (rosa) |
| Sul-Americana | Por grupo: 1º oitavas de final (azul), 2º playoff de oitavas (azul-claro) |

Fontes: Manual de Clubes CONMEBOL Libertadores 2026 e CONMEBOL Sudamericana 2026
(versão de junho de 2026) e regulamentos da CBF divulgados pela imprensa. São
referências fixas, não uma confirmação de classificação: vagas extras, campeões
de copas e mudanças de regulamento podem alterar os classificados. Nas copas, a
posição exibida é a da ESPN, que já aplica o confronto direto como primeiro
critério de desempate. Em outras ligas ESPN configuradas manualmente, tabelas
com mais de 12 clubes mantêm os quatro últimos como rebaixamento indicativo.

A tabela usa colunas alinhadas para posição, clube, pontos (Pts), jogos (J),
vitórias (V), empates (E), derrotas (D) e saldo de gols (SG). Divisórias separam
as linhas, os pontos ficam em destaque e nomes longos são truncados sem invadir
as estatísticas. A aba Tabela é mais larga para acomodar os dados.

## Dados, rede e privacidade

| Uso | Destino HTTPS |
| --- | --- |
| Jogos | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/scoreboard` |
| Classificação | `site.api.espn.com/apis/v2/sports/soccer/<league>/standings` |
| Participantes | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/teams` |
| Escudos | `a.espncdn.com/i/teamlogos/soccer/500/<id>.png` |

URLs de escudos recebidas no JSON são ignoradas: o destino deriva de um ID
validado. Downloads aceitam somente HTTPS, não seguem redirecionamentos e
ignoram `.curlrc`. Não há telemetria ou envio de credenciais. ESPN/CDN recebem
requisições normais, incluindo seu endereço de rede; proxy/DNS/TLS locais são
responsabilidade do sistema. A API externa pode mudar, atrasar ou limitar pedidos.

Placar: 25 segundos com jogo ao vivo do time seguido, 90 segundos com partida
agendada/recém-encerrada, dez minutos sem jogo. Cada ciclo consulta, uma por vez,
a competição exibida e as demais que o time seguido disputa (em geral até três
requisições). Classificação: 30 minutos, ou ao abrir o painel se antiga; a Copa
do Brasil não tem classificação e não é consultada. Participantes das cinco
competições: ao iniciar e a cada 12 horas. JSON: até 2 MiB e 100 partidas/linhas processadas.
Falhas de rede ou JSON inválido preservam os últimos dados válidos com aviso.
O relógio de jogo recebido da API é limitado a 32 caracteres; valores maiores
são ignorados. A formatação de minutos/acréscimos não usa regex com backtracking.

Escudos: downloads sequenciais, até 400 IDs distintos por instância/sessão,
armazenados em `~/.cache/omarchy/football/png-v1/<id>.png` com temporários privados
e substituição atômica. Antes de disponibilizar um arquivo à interface ou às
notificações, o helper limita o download a 2 MiB e as dimensões a 2048 × 2048,
valida cabeçalho, limites, ordem e CRC dos chunks e reconstrói o PNG usando apenas
`IHDR`, `PLTE`, `tRNS`, `IDAT` e `IEND`. Outros chunks auxiliares, incluindo texto
comprimido, perfis ICC, EXIF e animação, são removidos **sem descompressão**.
Paleta e transparência são preservadas; perfis de cor e animações não são mantidos.
O cache separado impede reutilizar escudos da versão anterior. Falhas não expõem
o arquivo anterior: aparece a abreviação, sem nova tentativa na mesma sessão.
O cache persiste entre sessões, sem limpeza automática. Isso mitiga a expansão
de metadados, mas não é uma validação completa do fluxo de pixels nem uma garantia
contra outras falhas do decodificador nativo; mantenha Qt/libpng atualizados.
Em vários monitores pode haver pedidos/alertas por instância, sem sincronização.

## IPC

```sh
omarchy-shell russio.football toggle
omarchy-shell russio.football open
omarchy-shell russio.football close
omarchy-shell russio.football refresh
omarchy-shell russio.football status
omarchy-shell russio.football openTab tabela
omarchy-shell russio.football celebrate
omarchy-shell russio.football rivalGoal
```

`openTab` aceita `jogos`, `tabela` e `ajustes`. `status` informa versão, contagens
e erros da última atualização. As prévias `celebrate` e `rivalGoal` exigem time
selecionado. Omarchy/Quickshell gerencia o acesso ao IPC.

## Atualização e remoção

```sh
omarchy plugin update russio.football
omarchy plugin remove russio.football
```

O gerenciador descarrega/remove o plugin. Para apagar também os escudos,
execute separadamente, se desejar:

```sh
rm -rf -- "$HOME/.cache/omarchy/football"
```

## Desenvolvimento e licença

`Panel.qml`: interface/IPC; `Model.js`: interpretação dos dados;
`CrestCache.py`: download e gravação. Valide com `omarchy plugin validate .`
e `git diff --check`.

### Direitos sobre código, preview e conteúdo de terceiros

O código é distribuído sob a [licença MIT](LICENSE). O mantenedor confirma ter
os direitos ou as permissões necessários para publicar o código e o preview
incluídos neste repositório e submetê-los ao marketplace.

Escudos, nomes e marcas dos clubes, assim como dados e conteúdo da ESPN,
pertencem aos respectivos titulares. A licença MIT do código não se aplica
automaticamente a esses elementos e não concede autorização para sua
redistribuição ou uso de marcas. Sua exibição no plugin ou no preview não
transfere direitos nem implica endosso. O uso desses elementos deve respeitar
as permissões e condições aplicáveis dos respectivos titulares.

Este é um projeto independente, sem afiliação, patrocínio ou endosso da ESPN,
dos clubes ou dos organizadores da competição. Para comunicar um problema
relacionado a direitos ou solicitar revisão de um asset, abra uma
[issue no repositório](https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a/issues).
