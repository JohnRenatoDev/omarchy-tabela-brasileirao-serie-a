# Futebol BR para Omarchy

[English (US)](README.en-US.md) · Português (Brasil)

Placar ao vivo, jogos do dia e classificação na barra do Omarchy, com Série A,
Série B, Copa do Brasil, Libertadores e Sul-Americana. Se você seguir um time,
recebe notificações e comemorações opcionais em todas as competições que ele
disputa. Em inglês, o plugin se chama **Brazilian Football Scores for Omarchy**.
O nome anterior era *Tabela Brasileirão Série A*.

![Painel aberto com a classificação da Série A e os escudos dos 20 clubes](preview.png)

Imagem ilustrativa: tabela da Série A exibida pelo plugin em 20/10/2026. A
classificação pode ter mudado depois dessa data. O time selecionado e os
destaques só demonstram a interface e não representam as preferências
futebolísticas do autor do plugin.

## Requisitos e instalação

Omarchy 4.0+ com plugins da shell, Quickshell/QtQuick, `curl` 8.4+,
`python3` 3.8+ e `notify-send` (pacote `libnotify`). O plugin precisa de
internet, mas não pede conta, chave de API nem token.

```sh
omarchy plugin add https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a.git --enable
```

O repositório já se chamou `omarchy-football`. O ID permanente continua
`russio.football`, então as configurações existentes são mantidas.
O instalador pede sua confirmação antes de adicionar e habilitar o plugin. Nada
na instalação exige elevação de privilégios ou altera outros plugins. Se o
widget não aparecer, execute `omarchy restart shell`.

## Uso

Clique na bola ou no placar para abrir o painel. `Q` ou `Esc` fecha o painel, e
as setas esquerda/direita trocam de aba quando você não está digitando na busca.

| Aba | Conteúdo |
| --- | --- |
| Jogos | A partida do seu time, de qualquer competição, e os jogos do dia da competição escolhida. Clicar em outra partida passa a seguir o mandante; clicar na partida do seu time mantém a escolha. |
| Tabela | Pontos, jogos, vitórias, empates, derrotas e saldo. Nas copas sul-americanas, há um bloco por grupo. Clique em um clube para segui-lo. |
| Ajustes | Seu time, a competição exibida, os alertas e as prévias. |

Em Ajustes, o time seguido aparece no topo, com as competições em que ele está
sendo acompanhado e o botão "Deixar de seguir". A busca ignora acentos e procura
em todas as competições, então dá para seguir um clube da Libertadores com a
Série A na tela. Enter segue o primeiro resultado e `Esc` limpa a busca. Sem time
seguido, a lista mostra os times da competição exibida. Depois da escolha, a lista
fica recolhida até você digitar algo. A lista mostra até 24 times e informa o
total quando há mais.

### Competições

| Competição | Código ESPN | Tabela |
| --- | --- | --- |
| Série A | `bra.1` | Única, 20 clubes |
| Série B | `bra.2` | Única, 20 clubes |
| Copa do Brasil | `bra.copa_do_brazil` | Não há (mata-mata) |
| Libertadores | `conmebol.libertadores` | Fase de grupos (8 × 4) |
| Sul-Americana | `conmebol.sudamericana` | Fase de grupos (8 × 4) |

O plugin acompanha o seu time em toda competição do catálogo cuja lista de
participantes na ESPN inclui o clube, e não só na competição exibida. Com a
Série A na tela, por exemplo, um gol do seu time na Libertadores também gera
notificação, e tanto a notificação quanto o painel dizem de qual competição é o
jogo. Série C e Série D ficaram fora do catálogo porque a ESPN não publica dados
de 2026 delas.

Antes do jogo, a barra mostra o horário local. Durante a partida, mostra placar
e minuto, `INT` no intervalo e `FIM` no término. O resultado fica na barra por
cerca de 30 minutos depois que o fim é detectado. Depois volta a bola, ou o
espaço some se `badgeWhenIdle` for falso. Sem time selecionado, a bola também
aparece.

A comemoração dura cerca de 2,6 segundos e o aviso de gol rival, 1,9 segundo.
Essas telas não pegam o foco do teclado e não capturam cliques. Notificações,
comemoração e aviso rival são ligados e desligados separadamente. As prévias só
rodam quando você pede e funcionam mesmo com o efeito automático desligado.

## Configuração

Use os controles do painel. Os ajustes ficam na entrada `russio.football` de
`~/.config/omarchy/shell.json`. O exemplo abaixo mostra só essa entrada, não o
arquivo inteiro:

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
| `league` | `bra.1` | Competição exibida, escolhida em Ajustes. Aceita os códigos da tabela de competições e, por compatibilidade, outros códigos ESPN como `eng.1`. Códigos inválidos voltam para `bra.1`. |
| `team` / `teamName` | vazio | ID do time seguido (número positivo de até dez dígitos) e o nome dele. |
| `goalNotifications` | `true` | Notificações de gol, início e fim de jogo. |
| `goalCelebration` | `true` | Comemoração automática nos gols do seu time. |
| `rivalAlert` | `true` | Efeito automático quando o adversário marca. |
| `badgeWhenIdle` | `true` | Mantém a bola na barra quando não há partida. |

A interface é em português do Brasil. As faixas coloridas seguem os regulamentos
de 2026:

| Competição | Faixas |
| --- | --- |
| Série A | 1º a 4º Libertadores (azul), 5º Pré-Libertadores (azul-claro), 6º a 11º Sul-Americana (rosa), 17º a 20º rebaixamento (cor de alerta do tema) |
| Série B | 1º e 2º acesso (azul), 3º a 6º playoff de acesso (azul-claro), 17º a 20º rebaixamento |
| Libertadores | Em cada grupo: 1º e 2º vão às oitavas de final (azul), o 3º vai ao playoff de oitavas da Sul-Americana (rosa) |
| Sul-Americana | Em cada grupo: o 1º vai às oitavas de final (azul), o 2º joga o playoff de oitavas (azul-claro) |

As regras das copas vêm dos Manuais de Clubes da CONMEBOL Libertadores 2026 e da
CONMEBOL Sudamericana 2026 (edição de junho de 2026). As da CBF vêm do
regulamento divulgado pela imprensa. As faixas são uma referência fixa e não
confirmam classificação: vagas extras, campeões de copas e mudanças de
regulamento podem alterar quem se classifica. Nas copas, a posição exibida é a
da ESPN, que já usa o confronto direto como primeiro critério de desempate. Em
outras ligas ESPN configuradas à mão, tabelas com mais de 12 clubes marcam os
quatro últimos como rebaixamento indicativo.

A tabela tem colunas alinhadas para posição, clube, pontos (Pts), jogos (J),
vitórias (V), empates (E), derrotas (D) e saldo de gols (SG). Linhas divisórias
separam os clubes, os pontos ficam em destaque e nomes longos são cortados antes
de chegar às estatísticas. A aba Tabela é mais larga que as outras para caber
tudo.

## Dados, rede e privacidade

| Uso | Destino HTTPS |
| --- | --- |
| Jogos | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/scoreboard` |
| Classificação | `site.api.espn.com/apis/v2/sports/soccer/<league>/standings` |
| Participantes | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/teams` |
| Escudos | `a.espncdn.com/i/teamlogos/soccer/500/<id>.png` |

O plugin ignora URLs de escudo que vêm no JSON e monta o endereço a partir de um
ID validado. Os downloads só aceitam HTTPS, não seguem redirecionamentos e
ignoram `.curlrc`. Não há telemetria e nenhuma credencial é enviada. ESPN e CDN
recebem requisições comuns, que incluem o seu endereço de rede. Proxy, DNS e TLS
locais ficam por conta do sistema. A API externa pode mudar, atrasar ou limitar
pedidos.

O placar é atualizado a cada 25 segundos com jogo do seu time em andamento, a
cada 90 segundos com partida agendada ou recém-encerrada e a cada dez minutos
sem jogo. Cada ciclo consulta, uma de cada vez, a competição exibida e as outras
que o seu time disputa (em geral, até três requisições). A classificação é
atualizada a cada 30 minutos, ou ao abrir o painel se estiver antiga. A Copa do
Brasil não tem classificação, então essa consulta não é feita para ela. As
listas de participantes das cinco competições são baixadas ao iniciar e a cada
12 horas. O plugin aceita JSON de até 2 MiB e processa até 100 partidas ou linhas.
Falha de rede ou JSON inválido mantém os últimos dados válidos e mostra um aviso.
O relógio de jogo vindo da API é limitado a 32 caracteres, e valores maiores são
ignorados. A formatação de minutos e acréscimos não usa regex com backtracking.

Os escudos são baixados um por vez, até 400 IDs distintos por instância e sessão,
e ficam em `~/.cache/omarchy/football/png-v1/<id>.png`, gravados com arquivos
temporários privados e substituição atômica. Antes de liberar um arquivo para a
interface ou para as notificações, o helper limita o download a 2 MiB e as
dimensões a 2048 × 2048. Ele também valida cabeçalho, limites, ordem e CRC dos
chunks e reconstrói o PNG só com `IHDR`, `PLTE`, `tRNS`, `IDAT` e `IEND`. Os
demais chunks auxiliares (texto comprimido, perfis ICC, EXIF e animação) são
removidos sem descompressão. Paleta e transparência são preservadas; perfis de
cor e animações, não. O cache fica em uma pasta separada para não reaproveitar
escudos da versão anterior. Se um download falha, o arquivo anterior não é usado:
aparece a abreviação do clube, e o plugin não tenta de novo na mesma sessão. O
cache persiste entre sessões e não é limpo automaticamente. Isso reduz o risco
de metadados inflados, mas não valida todo o fluxo de pixels nem protege contra
outras falhas do decodificador nativo, então mantenha Qt e libpng atualizados.
Com vários monitores, cada instância faz seus próprios pedidos e alertas, sem
sincronização entre elas.

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

`openTab` aceita `jogos`, `tabela` e `ajustes`. `status` informa a versão, as
competições acompanhadas, contagens e erros da última atualização. As prévias
`celebrate` e `rivalGoal` exigem time selecionado. O acesso ao IPC é controlado
pelo Omarchy/Quickshell.

## Atualização e remoção

```sh
omarchy plugin update russio.football
omarchy plugin remove russio.football
```

O gerenciador descarrega e remove o plugin. Os escudos em cache continuam no
disco. Para apagá-los, rode separadamente:

```sh
rm -rf -- "$HOME/.cache/omarchy/football"
```

## Desenvolvimento e licença

`Panel.qml` cuida da interface e do IPC, `Model.js` interpreta os dados e
`CrestCache.py` baixa e grava os escudos. Valide com `omarchy plugin validate .`
e `git diff --check`.

### Direitos sobre código, preview e conteúdo de terceiros

O código é distribuído sob a [licença MIT](LICENSE). O mantenedor confirma ter
os direitos ou as permissões necessários para publicar o código e o preview
incluídos neste repositório e submetê-los ao marketplace.

Escudos, nomes e marcas dos clubes, assim como dados e conteúdo da ESPN,
pertencem aos respectivos titulares. A licença MIT do código não se aplica
automaticamente a esses elementos e não autoriza sua redistribuição nem o uso
das marcas. Exibi-los no plugin ou no preview não transfere direitos nem implica
endosso. O uso desses elementos deve respeitar as permissões e condições dos
respectivos titulares.

Este é um projeto independente, sem afiliação, patrocínio ou endosso da ESPN,
dos clubes ou dos organizadores das competições. Para comunicar um problema de
direitos ou pedir a revisão de um asset, abra uma
[issue no repositório](https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a/issues).
