# Expected Findings — ortografia-reviewer

30 errors across 8 categories. Agent should detect 90%+ with correct severity.

## Seção 1: Ortografia e Acentuação (5 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 1 | 7 | necesário | necessário | SS obrigatório | CRITICO |
| 2 | 7 | esta | está | Oxítona terminada em -a | CRITICO |
| 3 | 8 | fantastico | fantástico | Proparoxítona: todas acentuadas | CRITICO |
| 4 | 8 | usuarios | usuários | Proparoxítona | CRITICO |
| 5 | 9 | conteudo | conteúdo | Hiato: U tônico | CRITICO |
| — | 9 | modulos | módulos | Proparoxítona | CRITICO |
| — | 10 | proximo | próximo | Proparoxítona | CRITICO |

Nota: linhas 9-10 contêm 2 erros adicionais (módulos, próximo) totalizando 7 nesta seção.

## Seção 2: Concordância Verbal (4 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 6 | 14 | Fazem dois anos | Faz dois anos | Fazer (tempo) = impessoal, singular | CRITICO |
| 7 | 14 | Houveram | Houve | Haver (existir) = impessoal, singular | CRITICO |
| 8 | 15 | Haviam muitas | Havia muitas | Haver (existir) = impessoal, singular | CRITICO |
| 9 | 15 | Existe várias | Existem várias | Existir concorda com sujeito | CRITICO |

## Seção 3: Regência e Crase (5 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 10 | 19 | Assisti o jogo | Assisti ao jogo | Assistir (ver) é VTI | CRITICO |
| 11 | 19 | a noite | à noite | Locução adverbial feminina: crase obrigatória | CRITICO |
| 12 | 19 | Prefiro...do que | Prefiro...a | Preferir rege preposição "a" | CRITICO |
| 13 | 20 | implicou em | implicou | Implicar (acarretar) é VTD | CRITICO |
| 14 | 20 | as 10 horas | às 10 horas | Hora exata: crase obrigatória | CRITICO |

Nota: "Cheguei em São Paulo" (linha 20) é erro adicional — chegar rege "a", não "em".

## Seção 4: Colocação Pronominal (3 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 15 | 24 | Me disseram | Disseram-me | Pronome átono nunca inicia frase | CRITICO |
| 16 | 24 | Não encontrou-se | Não se encontrou | Negação exige próclise | CRITICO |
| 17 | 25 | Tudo resolveu-se | Tudo se resolveu | Pronome indefinido exige próclise | MEDIO |

## Seção 5: Pontuação (4 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 18 | 29 | desenvolvedores, trabalharam | desenvolvedores trabalharam | Vírgula proibida entre sujeito e verbo | CRITICO |
| 19 | 29 | A certeza, de que | A certeza de que | Vírgula proibida entre nome e complemento | MEDIO |
| 20 | 30 | Maria venha | Maria, venha | Vocativo exige vírgula | MEDIO |
| 21 | 30 | Ontem à noite fomos | Ontem à noite, fomos | Adjunto adverbial deslocado exige vírgula | MEDIO |

## Seção 6: Hífen (3 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 22 | 34 | auto-suficiente | autossuficiente | Prefixo auto- + S: não usa hífen, dobra S | ALTO |
| 23 | 34 | anti-social | antissocial | Prefixo anti- + S: não usa hífen, dobra S | ALTO |
| 24 | 34 | vice presidente | vice-presidente | vice- sempre usa hífen | ALTO |

## Seção 7: Vícios de Linguagem (3 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 25 | 38 | subiu para cima | subiu | Pleonasmo vicioso | ALTO |
| 26 | 38 | saiu para fora | saiu | Pleonasmo vicioso | ALTO |
| 27 | 38 | surpresa inesperada | surpresa | Pleonasmo vicioso | ALTO |

## Seção 8: Confusões Clássicas (3 erros)

| # | Linha | Errado | Correto | Regra | Severidade |
|---|---|---|---|---|---|
| 28 | 42 | mais não posso | mas não posso | "Mas" = porém (adversativa) | ALTO |
| 29 | 42 | sentiu mau | sentiu mal | "Mal" oposto de "bem" | ALTO |
| 30 | 43 | havia chego | havia chegado | Particípio correto: "chegado" | ALTO |

## Seção 9: Escopo

O agente **NÃO deve** reportar erros no texto em inglês da Seção 9.
Se reportar qualquer erro nessa seção, é um falso positivo.

## Resumo

| Categoria | Erros | Severidade predominante |
|---|---|---|
| Ortografia/Acentuação | 7 | CRITICO |
| Concordância verbal | 4 | CRITICO |
| Regência/Crase | 5+ | CRITICO |
| Colocação pronominal | 3 | CRITICO/MEDIO |
| Pontuação | 4 | CRITICO/MEDIO |
| Hífen | 3 | ALTO |
| Vícios de linguagem | 3 | ALTO |
| Confusões clássicas | 3 | ALTO |
| **Total** | **32+** | — |
