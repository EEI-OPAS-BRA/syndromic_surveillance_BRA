# Carregar funções auxiliares e funções de mineração ----
source("funcoes_mineracao.R")

# Ler base de validação ----
# Define o caminho do arquivo de entrada.
f <- "amostra_municipio.csv"

# Lê a base de validação usando codificação Latin-1.
vs_amostra <- fread(f, encoding = "Latin-1")

####################################
# Processar base em blocos ----
####################################

# A base é processada em blocos para reduzir uso de memória e permitir retomada caso a execução seja interrompida.
# Para processar todas as linhas de uma vez, usar: n_linhas = nrow(vs_amostra)

ini = Sys.time()

arquivos_processados <- processa_em_blocos(
  df = vs_amostra,
  n_linhas = 10000, 
  out_dir = "processamento_serie_municipio",
  prefixo = "vs_amostra",
  id_atendimento = "nr_atendimento_principal",
  data_nascimento = "dt_nascimento",
  campo_evolucao = "evolucao",
  data_atendimento = "data_hora_atendimento",
  campo_sexo = "sg_sexo",
  nome_unidade_atendimento = "unidade",
  corrigir_encoding_arg = TRUE
)

fin = Sys.time()


tempo_regex_anterior = fin - ini
print(tempo_regex_anterior)
# Consolidar arquivos processados ----
# Lista os arquivos .rds gerados no processamento em blocos.
# Em seguida, lê cada arquivo e combina todos em uma única base.

dados_processados <- list.files(
  "processamento_serie_municipio",
  pattern = "^vs_amostra_\\d{4}\\.rds$",
  full.names = TRUE
) |>
  sort() |>
  map(readRDS) |>
  bind_rows()

# Padronizar variáveis para análise municipal ----
dados_municipio <- dados_processados |>
  
  # Recodifica os nomes das unidades de atendimento para rótulos mais curtos (adaptar de acordo com o banco)
  mutate(
    UNIDADE_ATENDIMENTO = factor(
      unidade,
      levels = c(
        "unidade de pronto atendimento - upa norte da ilha",
        "unidade de pronto atendimento - upa continente",
        "unidade de pronto atendimento - upa sul da ilha",
        "pronto atendimento - rio tavares",
        "cr dengue norte"
      ),
      labels = c(
        "UPA Norte da Ilha",
        "UPA Continente",
        "UPA Sul da Ilha",
        "UPA Sul da Ilha",
        "UPA Norte da Ilha"
      )
    )
  ) |>
  
  # Criar variáveis temporais ----
# Cria a semana epidemiológica, o ano epidemiológico e o mês do atendimento.

mutate(
  dateweek = floor_date(dtatend, unit = "week"),
  epiweek = paste0(epiweek(dateweek), ".", epiyear(dateweek)),
  mes_atend = month(dtatend)
) |>
  
  # Tratar valores ausentes em variáveis lógicas ----
# Substitui NA por FALSE em todas as colunas do tipo lógico.
mutate(
  across(where(is.logical), ~ replace_na(.x, FALSE))
)

##############################################
# Calcular total semanal de atendimentos ----
##############################################

# Calcula o número total de atendimentos por semana e por unidade.
# Também calcula uma média móvel simples de 2 semanas, alinhada à direita.

total_atendimento_tbl <- dados_municipio %>%
  arrange(dateweek) %>% 
  group_by(dateweek, UNIDADE_ATENDIMENTO) %>% 
  reframe(n = n()) %>%
  ungroup() |>
  group_by(UNIDADE_ATENDIMENTO) %>% 
  mutate(
    mm_direita = zoo::rollmean(
      n,
      k = 2,
      fill = NA,
      align = "right"
    )
  ) 

##############################################
# Criar tabelas de indicadores sindrômicos ----
##############################################

# Cada chamada de processar_sind_tbls() gera uma lista de tabelas derivadas para uma síndrome específica, separadas por unidade de atendimento.

# Processar síndrome respiratória ----
sind_resp_list <- processar_sind_tbls(
  dados_municipio, 
  coluna_sindrome = "sind_resp", 
  coluna_unidade_atendimento = "UNIDADE_ATENDIMENTO"
)

# Processar síndrome de arbovirose ----
sind_arbo_list <- processar_sind_tbls(
  dados_municipio, 
  coluna_sindrome = "sind_arbo",
  coluna_unidade_atendimento = "UNIDADE_ATENDIMENTO"
)

####################################
# Visualizar resultados ----
####################################

## Plotar total de atendimentos ----

# Gera a série temporal do total semanal de atendimentos por unidade.
# O argumento quebra_datas define o intervalo entre os rótulos do eixo x.

plot_serie_atendimentos(
  total_atendimento_tbl,
  quebra_datas = "4 weeks",
  titulo = "Total de atendimentos"
)

## Plotar incompletude dos dados ----

# Avalia a proporção de valores ausentes nas variáveis selecionadas,
# estratificando os resultados por unidade de atendimento.

plot_incompletude(
  dados_municipio,
  variaveis = c(
    "data_hora_atendimento",
    "dt_nascimento",
    "evolucao",
    "sg_sexo",
    "fxetar"
  ),
  coluna_unidade = "UNIDADE_ATENDIMENTO"
)


## Plotar frequência de sintomas ----

# Gera gráfico com a frequência dos sintomas identificados na base processada.
plot_freq_sintomas(dados_municipio)

#################
## Síndromes
#################

# Visualizar indicadores sindrômicos ----

# Síndrome respiratória ----
# Gera a série temporal semanal de atendimentos classificados como síndrome respiratória.
plot_serie_atendimentos(
  sind_resp_list$sind_resp_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Respiratória"
)

# Gera a distribuição temporal da síndrome respiratória por sexo.
plot_sexo(
  sind_resp_list$sind_resp_sexo_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Respiratória"
)

# Gera a distribuição temporal da síndrome respiratória por faixa etária.
plot_faixa_etaria(
  sind_resp_list$sind_resp_fx_etaria_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Respiratória"
)

# Gera o gráfico de alerta por EWMA para síndrome respiratória.
plot_alerta(
  sind_resp_list$sind_resp_tbl,
  quebra_datas = "4 weeks",
  titulo = "EWMA: Síndrome Respiratória"
)


# Síndrome arbovirose-like ----
# Gera a série temporal semanal de atendimentos classificados como síndrome arbovirose-like.
plot_serie_atendimentos(
  sind_arbo_list$sind_arbo_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Arbovirose-like"
)

# Gera a distribuição temporal da síndrome arbovirose-like por sexo.
plot_sexo(
  sind_arbo_list$sind_arbo_sexo_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Arbovirose-like"
)

# Gera a distribuição temporal da síndrome arbovirose-like por faixa etária.
plot_faixa_etaria(
  sind_arbo_list$sind_arbo_fx_etaria_tbl,
  quebra_datas = "4 weeks",
  titulo = "Síndrome Arbovirose-like"
)

# Gera o gráfico de alerta por EWMA para síndrome arbovirose-like.
plot_alerta(
  sind_arbo_list$sind_arbo_tbl,
  quebra_datas = "4 weeks",
  titulo = "EWMA: Síndrome Arbovirose-like"
)

