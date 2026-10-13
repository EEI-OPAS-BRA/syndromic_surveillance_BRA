# Vigilância Sindrômica: Inteligência de dados e detecção de surtos


Repositório oficial com a documentação técnica, manuais operacionais, apresentações executivas e rotinas em R para implementação do ecossistema de **Vigilância Sindrômica** no Sistema Único de Saúde (SUS), utilizando o pacote **`Rnssp/CDC`** (R National Syndromic Surveillance Program/ Centers for Disease Control and Prevention)

---

## Visão geral do projeto

A vigilância sindrômica complementa a vigilância epidemiológica tradicional ao monitorar sintomas e dados assistenciais das portas de entrada de urgência e emergência (UPAs e prontos-socorros) antes da confirmação diagnóstica laboratorial. 

Este projeto disponibiliza:
1. **Código em R:** Contendo desde a extração e mineração de texto (*Text Mining*) para identificação de grupos sindrômicos (Respiratória e Arboviral) em prontuários eletrônicos até a modelagem com a aplicação do algoritmo de detecção de anomalias para sinalização de alertas precoces em saúde pública usando EWMA. (Conjunto de 3 códigos interdependentes)
   
2. **Explicação técnica do algorimo EWMA:** Arquivo organizado com a explicação dos parametros do algoritmo EWMA.

3. **Manual técnico com todos os algoritmo do pacote RNSSP do R:** O pacote RNSSP (R National Syndromic Surveillance Program) disponibiliza ferramentas para implementação desses algoritmos, amplamente utilizados em sistemas de vigilância sindrômica vinculados ao CDC (Centers for Disease Control and Prevention), em português e com códigos de aplicação.

---

## Algoritmos implementados (`Rnssp` & Guidelines)

| Algoritmo | Função R | Granularidade | Histórico Mínimo | Foco Principal na Vigilância |
| :--- | :--- | :--- | :--- | :--- |
| **EWMA** | `alert_ewma()` | Diária / Semanal | 7 a 28 dias/semanas | Mudanças abruptas (*shifts*) e dados de curto prazo. |
| **Farrington** | `alert_farrington()` | Semanal | maior que 4 anos homólogos | Padrão-ouro para Doenças de Notificação Compulsória (DNC). |
| **Binomial Negativo** | `alert_nbinom()` | Semanal | maior que 2 anos | Séries sazonais com alta superdispersão (Variância> Média). |
| **Serfling** | `alert_serfling()` | Semanal | maior que 5 anos | Curvas de endemicidade para Influenza/VSR e excesso de eventos. |
| **Regressão Adaptativa** | `alert_regression()`| Exclusivo Diária | 28 dias | Ajuste de tendência diária e efeito "fim de semana". |
| **Switch (Híbrido)** | `alert_switch()` | Exclusivo Diária | 28 dias | Automação via R quadrado em redes heterogêneas. |
| **Threshold / EARS / RAMMIE** | *Ver Guidelines fora do RNSSP* | Diária / Semanal | Variável / Curto | Monitoramento de rotina e modelos multinível complexos. |

---

## Critério para escolha do algoritmo

**Nota Metodológica:** A escolha do algoritmo estatístico não deve ser tratada como uma receita fechada. O comportamento de cada método é sensível ao volume assistencial, à presença de sazonalidade e à maturidade do histórico de dados da região. Recomenda-se, sempre que possível, testar e avaliar os algoritmos na própria rotina de vigilância local, utilizando o pipeline comparativo fornecido neste repositório para selecionar o método (ou a combinação de métodos) de maior aderência ao cenário da sua localidade.

```text
[ Seleção do Algoritmo ]
    │
    ├── 1. Frequência dos Dados
    │     ├── DIÁRIA (UPAs / Prontos-Socorros) ─────────► EWMA / Regressão Adaptativa / Switch
    │     └── SEMANAL (Semanas Epidemiológicas) ────────► Farrington / Binomial Negativo / Serfling
    │
    ├── 2. Histórico Disponível (Linha de Base - B)
    │     ├── Séries Curtas (< 2 anos ou < 60 dias) ─────► EWMA / EARS / Threshold
    │     ├── Séries Médias (2 a 3 anos) ───────────────► Regressão Binomial Negativo
    │     └── Séries Longas (3 a 5+ anos) ──────────────► Farrington / Serfling / RAMMIE
    │
    └── 3. Variabilidade e Sazonalidade
          ├── Superdispersão (Onde a Variância >> Média) ────► Binomial Negativo / Farrington
          └── Sazonalidade Marcante (Inverno/Verão) ───► Serfling / Binomial Negativo
```
**Desenvolvimento e codificação:** Marcelo Borges (Vigilância em Saúde do Município de Florianópolis/SC) — responsável pela concepção, organização e estruturação das rotinas em R deste respositório.



## Estrutura dos scripts R e fluxo de execução

Os códigos em R foram desenvolvidos de forma modular para garantir reprodutibilidade e facilidade de manutenção. O fluxo de trabalho é composto por rotinas analíticas, funções utilitárias e um script demonstrativo autônomo:

 01_mineracao_vigilancia_sindromica.R: Script independente e didático, dedicado a ilustrar o passo a passo da leitura dos dados brutos, pré-processamento, limpeza e mineração de texto com expressões regulares (regex).

02_funcoes_mineracao.R : Módulo interno de funções e algoritmos auxiliares reutilizáveis, desenvolvido para dar suporte às etapas de processamento e modelagem.

03_fluxo_vigilancia_sindromica.R : Script principal(pipeline principal). Importa as funções de funcoes_mineracao.R via source(), executa o fluxo automatizado da vigilância sindrômica de ponta a ponta e aplica o método EWMA para detecção de anomalias e geração de alertas.

```text

scripts/
├── 01_mineracao_vigilancia_sindromica.R      # Módulo 1: Leitura, limpeza e regex dos termos (Exemplo/tutorial autônomo de limpeza e regex)
├── 02_funcoes_mineracao.R                    # Definições de funções (para source)
└── 03_fluxo_vigilancia_sindromica.R          #Script principal: Faz a chamada R/funcoes_mineracao.R

banco de dados de exemplo
└── amostra_municipio.csv                     # Dados da sua localidade (NÃO DISPONIBILIZADO)
```
Seguindo a lógica conforme figura abaixo, o código esta totalmente organizado para gerar o alerta pelo método EWMA.

<img width="1191" height="1321" alt="fluxograma" src="https://github.com/user-attachments/assets/f5504513-4ed8-423b-8226-2cf7c0733aa4" />



## Tabelas e resultados gerados pelo R (Compilação Final)

Após a etapa de mineração de texto nos prontuários eletrônicos e o processamento dos dados, o pipeline no R compila e cria automaticamente **novas colunas consolidadas** no ambiente R.

Elas estão divididas entre as **séries temporais sindrômicas gerais** e as **estratificações demográficas** (por faixa etária e por sexo) para as síndromes monitoradas na localidade.

---

### 1. Séries Temporais por Grupo Sindrômico

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_tbl` | `sind_resp_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Respiratória** por semana epidemiológica e UPA. |
| `sind_arbo_tbl` | `sind_arbo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Arboviral** por semana epidemiológica e UPA. |


> **Dicionário das variáveis de contagem:**
> * `n`: Frequência absoluta de atendimentos no período.
> * `p`: Proporção do grupo sindrômico em relação ao total de atendimentos gerais da UPA.
> * `pc`: Percentual relativo, quando existe algum agrupamento/estratificação (por exemplo, sexo ou faixa etaria)
> * `alert`: Classificação final do algoritmo de detecção de anomalias.

---

### 2. Distribuição demográfica por Faixa Etária (`fxetar`)

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_fx_etaria_tbl` | `sind_resp_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Respiratória** estratificados por faixa etária. |
| `sind_arbo_fx_etaria_tbl` | `sind_arbo_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Arboviral** estratificados por faixa etária. |

---

### 3. Distribuição demográfica por sexo (`sexo`)

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_sexo_tbl` | `sind_resp_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Respiratória** estratificados por sexo. |
| `sind_arbo_sexo_tbl` | `sind_arbo_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Arboviral** estratificados por sexo. |


## Vitrine do Conhecimento em Vigilância Sindrômica
A Vitrine do Conhecimento em Vigilância Sindrômica reúne publicações científicas e documentos técnicos para apoiar profissionais, gestores, pesquisadores e estudantes interessados no tema. O acervo apresenta fundamentos, experiências e métodos relacionados à identificação de alterações nos padrões de saúde e ao uso de informações para alerta precoce e resposta em saúde pública.
[Acesso aqui a vitrine do conhecimento, clique!](https://vitrinas.bvsalud.org/health-emergencies/vitrine/vigilancia-sindromica/)


##  Referências Bibliográficas

AZONDEKON, Gbedegnon Roseric; SHEPPARD, Michael. Rnssp: a signature R package for the National Syndromic Surveillance Program (NSSP). Versão 0.3.1. Atlanta: Centers for Disease Control and Prevention, 2025. Software.

BORGES, Marcelo. Rotinas de codificação em R para processamento de dados e execução dos algoritmos de Vigilância Sindrômica (Rnssp)- Florianópolis(SC), Vigilância em Saúde do Município de Florianópolis, 2026. Script R.

LIZZI, Elisângela Aparecida da Silva. Documentação de algoritmos para Vigilância Sindrômica do pacote RNSSP - Implementação comparariva para os dados de Florianópolis- OPAS- Brasil, 2026.

ORGANIZAÇÃO PAN-AMERICANA DA SAÚDE (OPAS)-Vigilância Sindrômica – Health Emergencies- Vitrine do conhecimento. Disponível em:
https://vitrinas.bvsalud.org/health-emergencies/vitrine/vigilancia-sindromica/. Accessed: 2026-10-13

