# Vigilância Sindrômica: Inteligência de dados e detecção de surtos com R (`Pacote Rnssp`)


Repositório oficial com a documentação técnica, manuais operacionais, apresentações executivas e rotinas em R para implementação do ecossistema de **Vigilância Sindrômica** no Sistema Único de Saúde (SUS), utilizando o pacote **`Rnssp`** (CDC / NSSP).

---

## Visão geral do projeto

A vigilância sindrômica complementa a vigilância epidemiológica tradicional ao monitorar sintomas e dados assistenciais das portas de entrada de urgência e emergência (UPAs e prontos-socorros) antes da confirmação diagnóstica laboratorial. 

Este projeto disponibiliza manual analítico para:
1. **Extração e Mineração de Texto (*Text Mining*):** Identificação de grupos sindrômicos (Respiratória, Arboviral, Diarreica, Exantemática, Ictérico-Hemorrágica) em prontuários eletrônicos.
2. **Modelagem Estatística de Séries Temporais:** Aplicação de algoritmos de detecção de anomalias para sinalização de alertas precoces em saúde pública.
3. **Análise Comparativa de Sensibilidade:** Matriz de decisão e concordância entre múltiplos algoritmos para redução de falsos alarmes.

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
| **Threshold / EARS / RAMMIE** | *Ver Guidelines* | Diária / Semanal | Variável / Curto | Monitoramento de rotina e modelos multinível complexos. |

---

## Critério para escolha do algoritmo

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
          ├── Superdispersão Extrema (Var >> Média) ────► Binomial Negativo / Farrington
          └── Sazonalidade Marcante (Inverno/Verão) ───► Serfling / Binomial Negativo

## Banco de Dados de Exemplo (Florianópolis/SC)

O repositório disponibiliza uma base de dados real anonimizada da cidade de **Florianópolis/SC** (`sind_resp_tbl_final.csv`), localizada na pasta `dados/` [1].

* **Série Analisada:** Atendimentos por Síndrome Respiratória consolidados por semana epidemiológica e por Unidade de Pronto Atendimento [1].
* **Unidades Incluídas:** UPA Norte da Ilha, UPA Sul da Ilha e UPA Continente [1].
* **Estrutura das Colunas:**
  * `dateweek`: Data da Semana Epidemiológica (formato `YYYY-MM-DD`) [1].
  * `UNIDADE_ATENDIMENTO`: Nome da UPA de referência [1].
  * `n`: Número absoluto de atendimentos registrados na semana [1].

---

## Estrutura dos scripts R e fluxo de execução

Os códigos em R foram desenvolvidos de forma **modular e interdependente**. O fluxo é conta conta com **Script Mestre** que executa os módulos sequencialmente utilizando a função `source()`.

```text
scripts/
├── 01_mineracao_vigilancia_sindromica.R      # Módulo 1: Leitura, limpeza e regex dos termos
├── 02_funcoes_mineracao.R                    # Módulo 2: Algoritmos e funções
└── 03_fluxo_vigilancia_sindromica.R          # Script Mestre: Executa 01 e 02 e gera a os alertas pelo método EWMA.

##  Referências Bibliográficas

AZONDEKON, Gbedegnon Roseric; SHEPPARD, Michael. Rnssp: a signature R package for the National Syndromic Surveillance Program (NSSP). Versão 0.3.1. Atlanta: Centers for Disease Control and Prevention, 2025. Software.

LIZZI, Elisângela Aparecida da Silva. Documentação de algoritmos para Vigilância Sindrômica do pacote RNSSP. - Implementação para os dados de Florianópolis- OPAS- Brasil, 2026.

ORGANIZAÇÃO PAN-AMERICANA DA SAÚDE (OPAS); MINISTÉRIO DA SAÚDE. Vigilância Sindrômica de dados assistenciais: inteligência de dados e mineração de texto. São Luís (MA), 2026.
