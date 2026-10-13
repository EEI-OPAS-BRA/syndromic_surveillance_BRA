# Vigilância Sindrômica: Inteligência de dados e detecção de surtos


Repositório oficial com a documentação técnica, manuais operacionais, apresentações executivas e rotinas em R para implementação do ecossistema de **Vigilância Sindrômica** no Sistema Único de Saúde (SUS), utilizando o pacote **`Rnssp`** (CDC / NSSP).

---

## Visão geral do projeto

A vigilância sindrômica complementa a vigilância epidemiológica tradicional ao monitorar sintomas e dados assistenciais das portas de entrada de urgência e emergência (UPAs e prontos-socorros) antes da confirmação diagnóstica laboratorial. 

Este projeto disponibiliza manual analítico para:
1. **Manual de Métodos do Pacote RNSSP:** Aplicação de algoritmos de detecção de anomalias para sinalização de alertas precoces em saúde pública para o município de Florianópolis-SC, Brasil como exemplo.
2. **Código em R:** Contendo desde a extração e mineração de texto (*Text Mining*) para identificação de grupos sindrômicos (Respiratória, Arboviral, Diarreica, Exantemática, Ictérico-Hemorrágica) em prontuários eletrônicos até a modelagem com a aplicação do algoritmo de detecção de anomalias para sinalização de alertas precoces em saúde pública usando EWMA. (Conjunto de 3 códigos interdependentes e um banco de dados de exemplo)
4. **Explicação técnica do algorimo EWMA:** Arquivo organizado com a explicação dos parametros do algoritmo EWMA.

---

## Algoritmos implementados (`Rnssp` & Guidelines)

| Algoritmo | Função R | Granularidade | Histórico Mínimo | Foco Principal na Vigilância |
| :--- | :--- | :--- | :--- | :--- |
| **EWMA** | `alert_ewma()` | Diária / Semanal | 7 a 28 dias/semanas | Mudanças abruptas (*shifts*) e dados de curto prazo. |
| **Farrington** | `alert_farrington()` | Semanal | \\(\ge 4\\) anos homólogos | Padrão-ouro para Doenças de Notificação Compulsória (DNC). |
| **Binomial Negativo** | `alert_nbinom()` | Semanal | \\(\ge 2\\) anos | Séries sazonais com alta superdispersão (\\(\text{Var} \gg \text{Média}\\)). |
| **Serfling** | `alert_serfling()` | Semanal | \\(\ge 5\\) anos | Curvas de endemicidade para Influenza/VSR e excesso de eventos. |
| **Regressão Adaptativa** | `alert_regression()`| Exclusivo Diária | 28 dias | Ajuste de tendência diária e efeito "fim de semana". |
| **Switch (Híbrido)** | `alert_switch()` | Exclusivo Diária | 28 dias | Automação via \\(R^2 \ge 0{,}60\\) em redes heterogêneas. |
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


## Banco de dados de exemplo (Município de Florianópolis(SC)- Brasil)

O repositório disponibiliza uma base de dados real anonimizada da cidade de **Florianópolis/SC** (`sind_resp_tbl_final.csv`), localizada na pasta `dados/` [1].

* **Série Analisada:** Atendimentos por Síndrome Respiratória consolidados por semana epidemiológica e por Unidade de Pronto Atendimento [1].
* **Unidades Incluídas:** UPA Norte da Ilha, UPA Sul da Ilha e UPA Continente [1].
* **Estrutura das Colunas:**
  * `dateweek`: Data da Semana Epidemiológica (formato `YYYY-MM-DD`) [1].
  * `UNIDADE_ATENDIMENTO`: Nome da UPA de referência [1].
  * `n`: Número absoluto de atendimentos registrados na semana [1].

---

## Estrutura dos scripts R e fluxo de execução

Os códigos em R foram desenvolvidos de forma **modular e interdependente**. O fluxo conta com **Script Mestre** que executa os módulos sequencialmente utilizando a função `source()`.

```text
scripts/
├── 01_mineracao_vigilancia_sindromica.R      # Módulo 1: Leitura, limpeza e regex dos termos
├── 02_funcoes_mineracao.R                    # Módulo 2: Algoritmos e funções
└── 03_fluxo_vigilancia_sindromica.R          # Script Mestre: Executa 01 e 02 e gera a os alertas pelo método EWMA.

banco de dados de exemplo
└── amostra_municipio.csv                     # Dados de teste do Município de Florianópolis-SC- Brasil
```

## Tabelas e resultados gerados pelo R (Compilação Final)

Após a etapa de mineração de texto nos prontuários eletrônicos e o processamento dos dados, o pipeline no R compila e cria automaticamente **15 colunas consolidadas** no ambiente R.

Elas estão divididas entre as **séries temporais sindrômicas gerais** e as **estratificações demográficas** (por faixa etária e por sexo) para as 5 síndromes monitoradas no município de Florianópolis:

---

### 1. Séries Temporais por Grupo Sindrômico

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_tbl` | `sind_resp_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Respiratória** por semana epidemiológica e UPA. |
| `sind_arbo_tbl` | `sind_arbo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Arboviral** por semana epidemiológica e UPA. |
| `sind_exan_tbl` | `sind_exan_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Exantemática** por semana epidemiológica e UPA. |
| `sind_diar_tbl` | `sind_diar_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Diarreica** por semana epidemiológica e UPA. |
| `sind_ict_hem_tbl` | `sind_ict_hem_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `n`, `p`, `pc`, `alert` | Série temporal de atendimentos por **Síndrome Ictérico-Hemorrágica** por semana epidemiológica e UPA. |

> **Dicionário das variáveis de contagem:**
> * `n`: Frequência absoluta de atendimentos no período.
> * `p`: Proporção do grupo sindrômico em relação ao total de atendimentos gerais da UPA.
> * `pc`: Percentual relativo (`p * 100`).
> * `alert`: Classificação final do algoritmo de detecção de anomalias.

---

### 2. Distribuição demográfica por Faixa Etária (`fxetar`)

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_fx_etaria_tbl` | `sind_resp_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Respiratória** estratificados por faixa etária. |
| `sind_arbo_fx_etaria_tbl` | `sind_arbo_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Arboviral** estratificados por faixa etária. |
| `sind_exan_fx_etaria_tbl` | `sind_exan_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Exantemática** estratificados por faixa etária. |
| `sind_diar_fx_etaria_tbl` | `sind_diar_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Diarreica** estratificados por faixa etária. |
| `sind_ict_hem_fx_etaria_tbl` | `sind_ict_hem_fx_etaria_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `fxetar`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Ictérico-Hemorrágica** estratificados por faixa etária. |

---

### 3. Distribuição demográfica por sexo (`sexo`)

| Objeto no R | Nome | Colunas | Descrição |
| :--- | :--- | :--- | :--- |
| `sind_resp_sexo_tbl` | `sind_resp_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Respiratória** estratificados por sexo. |
| `sind_arbo_sexo_tbl` | `sind_arbo_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Arboviral** estratificados por sexo. |
| `sind_exan_sexo_tbl` | `sind_exan_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Exantemática** estratificados por sexo. |
| `sind_diar_sexo_tbl` | `sind_diar_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Diarreica** estratificados por sexo. |
| `sind_ict_hem_sexo_tbl` | `sind_ict_hem_sexo_tbl_final.csv` | `dateweek`, `UNIDADE_ATENDIMENTO`, `sexo`, `n`, `p`, `pc` | Distribuição dos atendimentos por **Síndrome Ictérico-Hemorrágica** estratificados por sexo. |


##  Referências Bibliográficas

AZONDEKON, Gbedegnon Roseric; SHEPPARD, Michael. Rnssp: a signature R package for the National Syndromic Surveillance Program (NSSP). Versão 0.3.1. Atlanta: Centers for Disease Control and Prevention, 2025. Software.

LIZZI, Elisângela Aparecida da Silva. Documentação de algoritmos para Vigilância Sindrômica do pacote RNSSP. - Implementação para os dados de Florianópolis- OPAS- Brasil, 2026.

ORGANIZAÇÃO PAN-AMERICANA DA SAÚDE (OPAS); MINISTÉRIO DA SAÚDE. Vigilância Sindrômica de dados assistenciais: inteligência de dados e mineração de texto. São Luís (MA), 2026.
