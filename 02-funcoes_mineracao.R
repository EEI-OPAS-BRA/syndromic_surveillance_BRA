# Carregar pacotes ----
# Instala o pacote pacman, caso ele ainda não esteja disponível no ambiente.
# O pacman é utilizado para carregar múltiplos pacotes de forma compacta.
if (!requireNamespace("pacman")) {
  install.packages("pacman")
}

# Carrega os pacotes necessários para leitura, processamento, mineração de texto,
# manipulação de dados, análise temporal, detecção de alertas e visualização.
pacman::p_load(
  cusum,
  data.table,
  janitor,
  lubridate,
  plotly,
  purrr,
  rio,
  Rnssp,
  stopwords,
  stringi,
  stringr,
  textutils,
  tidytext,
  tidyverse,
  tm,
  treemapify,
  viridis,
  zoo,
  rio
)


# Definir stopwords ----
# Carrega a lista padrão de stopwords em português.
# Definir stopwords 

# Adiciona termos específicos do contexto dos atendimentos.
# Esses termos são removidos ou ignorados em etapas de mineração de texto,
# pois tendem a não contribuir para a identificação de sintomas ou síndromes.

stopwords <- c(
  "de", "a", "o", "que", "e", "do", "da", "em",
  "um", "para", "com", "não", "uma", "os", "no", "se",
  "na", "por", "mais", "as", "dos", "como", "mas", "ao",
  "ele", "das", "à", "seu", "sua", "ou", "quando", "muito",
  "nos", "já", "eu", "também", "só", "pelo", "pela", "até",
  "isso", "ela", "entre", "depois", "mesmo", "aos", "seus",
  "quem", "nas", "me", "esse", "eles", "você", "essa", "num",
  "nem", "suas", "meu", "às", "minha", "numa", "pelos", "elas",
  "qual", "nós", "lhe", "deles", "essas", "esses", "pelas", "este",
  "dele", "tu", "te", "vocês", "vos", "lhes", "meus", "minhas",
  "teu", "tua", "teus", "tuas", "nosso", "nossa", "nossos", "nossas",
  "dela", "delas", "esta", "estes", "estas", "aquele", "aquela", "aqueles",
  "aquelas", "isto", "aquilo", "estou", "está", "estamos", "estão", "estive",
  "esteve", "estivemos", "estiveram", "estava", "estávamos", "estavam", "estivera", "estivéramos",
  "esteja", "estejamos", "estejam", "estivesse", "estivéssemos", "estivessem", "estiver", "estivermos",
  "estiverem", "hei", "há", "havemos", "hão", "houve", "houvemos", "houveram",
  "houvera", "houvéramos", "haja", "hajamos", "hajam", "houvesse", "houvéssemos", "houvessem",
  "houver", "houvermos", "houverem", "houverei", "houverá", "houveremos", "houverão", "houveria",
  "houveríamos", "houveriam", "sou", "somos", "são", "era", "éramos", "eram",
  "fui", "foi", "fomos", "foram", "fora", "fôramos", "seja", "sejamos",
  "sejam", "fosse", "fôssemos", "fossem", "for", "formos", "forem", "serei",
  "será", "seremos", "serão", "seria", "seríamos", "seriam", "tenho", "tem",
  "temos", "tém", "tinha", "tínhamos", "tinham", "tive", "teve", "tivemos",
  "tiveram", "tivera", "tivéramos", "tenha", "tenhamos", "tenham", "tivesse", "tivéssemos",
  "tivessem", "tiver", "tivermos", "tiverem", "terei", "terá", "teremos", "terão",
  "teria", "teríamos", "teriam", "°c", "afebril", "murm[úu]rio vesicular?"
)

# Define caracteres especiais problemáticos que podem surgir após problemas
# de encoding ou cópia de sistemas externos.
chars_problematicos <- paste0(
  "[",
  "\u2018", # ‘
  "\u2019", # ’
  "\u201A", # ‚
  "\u201C", # “
  "\u201D", # ”
  "\u201E", # „
  "\u2013", # -
  "\u2020", # †
  "\u2021", # ‡
  "\u2022", # •
  "\u2026", # …
  "\u2030", # ‰
  "\u2039", # ‹
  "\u203A", # ›
  "\u20AC", # €
  "\u2122", # ™
  "\u0192", # ƒ
  "\u0160", # Š
  "\u0161", # š
  "\u017D", # Ž
  "\u017E", # ž
  "\u0152", # Œ
  "\u0153", # œ
  "]"
)

# Criar expressão regular para stopwords ----
# Converte a lista de stopwords em uma única expressão regular.
# O uso de \\b indica limites de palavra, evitando substituições parciais.
stop_reg <- paste0("\\b", paste(stopwords, collapse = "\\b|\\b"), "\\b")

# Processamento dos dados ----
# Processar bloco de atendimentos ----
# Descrição:
#   Padroniza e processa uma base de atendimentos em saúde a partir de campos
#   mínimos de identificação, data, sexo, unidade e evolução clínica.
#   A função limpa o texto da evolução, calcula variáveis demográficas,
#   cria uma versão normalizada do texto para mineração, identifica sintomas
#   por expressões regulares e classifica atendimentos em síndromes de interesse.
#
# Argumentos:
#   df:
#     Base de dados contendo os atendimentos a serem processados.
#
#   id_atendimento:
#     Nome da coluna, em formato de texto, que identifica o atendimento.
#     O padrão é "nr_atendimento_principal".
#
#   data_nascimento:
#     Nome da coluna, em formato de texto, com a data de nascimento.
#     O padrão é "dt_nascimento".
#
#   campo_evolucao:
#     Nome da coluna, em formato de texto, com a evolução clínica/anamnese.
#     O padrão é "evolucao".
#
#   data_atendimento:
#     Nome da coluna, em formato de texto, com a data/hora do atendimento.
#     O padrão é "data_hora_atendimento".
#
#   campo_sexo:
#     Nome da coluna, em formato de texto, com o sexo do paciente.
#     O padrão é "sg_sexo".
#
#   nome_unidade_atendimento:
#     Nome da coluna, em formato de texto, com a unidade de atendimento.
#     O padrão é "unidade".
#
#   corrigir_encoding_arg:
#     Valor lógico. Se TRUE, tenta corrigir problemas comuns de encoding e
#     remover caracteres problemáticos. O padrão é TRUE.
#
# Retorno:
#   Uma base processada contendo as colunas padronizadas de entrada, variáveis
#   demográficas derivadas, texto clínico limpo, indicadores lógicos de sintomas
#   e indicadores lógicos de síndromes.
#
# Como utilizar:
#   dados_processados <- processa_bloco(
#     df = dados,
#     id_atendimento = "nr_atendimento_principal",
#     data_nascimento = "dt_nascimento",
#     campo_evolucao = "evolucao",
#     data_atendimento = "data_hora_atendimento",
#     campo_sexo = "sg_sexo",
#     nome_unidade_atendimento = "unidade"
#   )
#
#   Caso a base original use nomes diferentes, informe os nomes correspondentes:
#   dados_processados <- processa_bloco(
#     df = dados,
#     id_atendimento = "ID",
#     data_nascimento = "DT_NASC",
#     campo_evolucao = "ANAMNESE",
#     data_atendimento = "DT_ATEND",
#     campo_sexo = "SEXO",
#     nome_unidade_atendimento = "UNIDADE"
#   )

processa_bloco <- function(df,
                           id_atendimento = "nr_atendimento_principal",
                           data_nascimento = "dt_nascimento",
                           campo_evolucao = "evolucao",
                           data_atendimento = "data_hora_atendimento",
                           campo_sexo = "sg_sexo",
                           nome_unidade_atendimento = "unidade",
                           corrigir_encoding_arg = TRUE
) {
  
  df <- df |>
    
    # Padronizar nomes das colunas de entrada ----
  # Renomeia as colunas informadas pelo usuário para os nomes internos
  # utilizados ao longo da função.
  rename(
    nr_atendimento_principal = all_of(id_atendimento),
    dt_nascimento            = all_of(data_nascimento),
    evolucao                 = all_of(campo_evolucao),
    data_hora_atendimento    = all_of(data_atendimento),
    sg_sexo                  = all_of(campo_sexo),
    unidade                  = all_of(nome_unidade_atendimento)
  ) %>%
    
    # Selecionar colunas necessárias ----
  # Mantém apenas os campos utilizados no processamento.
  select(
    nr_atendimento_principal,
    dt_nascimento,
    evolucao,
    data_hora_atendimento,
    sg_sexo,
    unidade
  ) %>%
    
    # Padronizar textos em minúsculas ----
  # Aplica tolower somente em colunas de texto, evitando alterar datas e números.
  mutate(
    across(where(is.character), tolower)
  ) %>%
  
    # Criar variáveis demográficas e temporais ----
  # Converte datas, padroniza sexo, calcula idade e classifica faixa etária.
  mutate(
    dtatend = as.Date(data_hora_atendimento),
    dtnasc  = ymd(dt_nascimento),
    
    sexo = case_when(
      sg_sexo == "f" ~ "Feminino",
      sg_sexo == "m" ~ "Masculino",
      TRUE           ~ "Ignorado"
    ),
    
    sexo = factor(
      sexo,
      levels = c("Feminino", "Masculino", "Ignorado")
    ),
    
    idade = trunc(time_length(difftime(dtatend, dtnasc), "years")),
    idade = as.numeric(idade),
    
    fxetar = case_when(
      idade < 1          ~ "< 1",
      idade %in% 1:4     ~ "1-4",
      idade %in% 5:9     ~ "5-9",
      idade %in% 10:19   ~ "10-19",
      idade %in% 20:59   ~ "20-59",
      idade >= 60        ~ "60+",
      TRUE               ~ "Ignorado"
    ),
    
    fxetar = factor(
      fxetar,
      levels = c("< 1", "1-4", "5-9", "10-19", "20-59", "60+", "Ignorado")
    )
  )
  
  
  if(corrigir_encoding_arg) {
    
    df <- df |>
      mutate(
        # Corrigir problemas de encoding ----
        evolucao_limpo = stringi::stri_conv(evolucao, from = "UTF-8", to = "latin1"),
        evolucao_limpo = ifelse(stringi::stri_enc_isutf8(evolucao_limpo), evolucao_limpo, iconv(evolucao_limpo, from = "latin1", to = "UTF-8", sub = "")),
        evolucao_limpo = stringr::str_remove_all(evolucao_limpo, chars_problematicos),
      )
    
  } else {
    
    df <- df |>
      mutate(evolucao_limpo = evolucao)
  }
    
    # Limpar campo de evolução clínica ----
  # Cria uma primeira versão limpa do texto original da evolução.
  
  df <- df |>
  mutate(
    # Calcula medidas simples do texto processado.
    n_caracteres = nchar(evolucao_limpo),
    n_palavras = stri_count_words(evolucao_limpo),
    
    ## Limpeza do texto
    
    # Decodificar e remover símbolos de HTML
    evolucao_limpo = HTMLdecode(evolucao_limpo),
    
    # Remover expressão "sem sangue" ou "sem sangramentos"
    evolucao_limpo = str_remove_all(
      evolucao_limpo,
      regex("sem sangue|sem \\bsa?n?gramen?tos?", 
            ignore_case = TRUE)
    ),
    
    # Remover negações antes de remover pontuações ou marcadores de parágrafo ou quebra de linha:
    # Qualquer palavra + ":" + regex_nega (ex: Comoborbidades: nega)
    # Expressões de negação (nega, nefa, sem) até o final da frase (pontuações, marcadores de parágrafo, quebra de linha) ou conectivos adversativos
    # Qualquer palavra seguida de ausente(s) ou auzente(s)
    evolucao_limpo = str_remove_all(
      evolucao_limpo,
      regex("(?:\\b[[:alnum:]À-ÿ_-]+:\\s*(?:<[^>]+>\\s*)*(?:nega|ne[ga]|[ne]ga|nefa)\\b|\\b(?:nega|ne[ga]|[ne]ga|nefa|sem)\\b.*?(?:\\.|;|<br\\s*/?>|</p>|\\r?\\n|\\bcontudo\\b|\\bpor[eé][mn]\\b|\\bentretanto\\b|(?:,\\s*)?\\bmas\\b|$)|\\bsem\\b(?:\\s+\\S+)?|\\b[[:alnum:]À-ÿ_-]+\\s+au[zs]entes?\\b)", 
            ignore_case = TRUE)
    ),
    
    # Remover tags de hipertexto
    evolucao_limpo = stringr::str_replace_all(
      evolucao_limpo,
      paste0("</?(?:a|address|b|bdo|blockquote|br|button|col|colgroup|del|div|em|fieldset|form|h1|h2|h3|h4|h5|h6|hr|i|iframe|img|input|",
             "label|legend|li|object|ol|option|p|pre|script|select|small|span|strong|style|sub|sup|table|tbody|td|textarea|th|thead|",
             "tr|ul|xml|[A-Za-z]+:[A-Za-z][A-Za-z0-9-]*)\\b[^>]*>"),
      " "
    ),
    
    # Remove ponto entre letras, inclusive letras acentuadas.
    evolucao_limpo = gsub("([[:alpha:]])\\.([[:alpha:]])", "\\1\\2", evolucao_limpo),
    
    # Normaliza espaços unicode, incluindo espaços não separáveis.
    evolucao_limpo = stringi::stri_replace_all_regex(evolucao_limpo, "\\p{Z}+", " "),
    
    # Padronizar textos em minúsculas
    evolucao_limpo = tolower(evolucao_limpo),
    
    # Substituir tudo que não é letra por espaço (ou seja, remover pontuações, números, etc)
    combinacao = str_replace_all(evolucao_limpo, "[^A-Za-zÀ-ÿ]", " "),
    
    # Remover stopwords (realizado antes de remover acentos para que apenas as correspondências corretas sejam removidas)
    combinacao = map_chr(
      combinacao,
      ~ str_remove_all(.x, pattern = stop_reg)
    ),
    
    # Normalizar o texto: substituir letras com símbolos ou caracteres especiais pelas letras correspondentes
    combinacao = combinacao |>
      abjutils::rm_accent() |>
      str_replace_all("[^A-Za-z]", " ") |>
      str_squish(),
    
    # Remover letras que ficam soltas após o tratamento dos dados
    combinacao = str_replace_all(
      combinacao,
      "\\bh\\b|\\bp\\b|\\bg\\b|\\bc\\b|\\bx\\b|\\bb\\b",
      " "
    ),
    
    ## Unir expressões compostas relevantes 
    # Junta termos que precisam ser tratados como uma unidade semântica.
    # Ex.: "dor garganta" -> "dor-garganta".
    combinacao = str_replace_all(
      combinacao,
      "(temperatura|temp)\\s+(alta|elevada)",
      "\\1-\\2"
    ),
    
    combinacao = str_replace_all(
      combinacao,
      "(dor)\\s+(cabeca|garganta|abdominal|abdomin|abd|corpo)",
      "\\1-\\2"
    ),
    
    combinacao = str_replace_all(
      combinacao,
      "(insuficiencia|insuf)\\s+(respiratoria|resp)",
      "\\1-\\2"
    ),
    
    # Remove espaços duplicados
    combinacao = str_squish(combinacao),
    
    ## Extrair sintomas
    
    # Cria variáveis lógicas indicando a presença de sintomas e condições clínicas no texto processado.
    febre = str_detect(combinacao, "\\bfebr|temperatura-|temp-"),
    exant = str_detect(combinacao, "\\bexa?nt|\\benantema\\b|\\bexatema\\b|\\bolhas?\\b|\\brash\\b|\\bpapul|\\bpetequia?[sl]?\\b|\\bpetequeia\\b|\\bmacula[sr]?\\b|\\bmaculo|\\bmo[r]biliforme|escarlatiniforme|rubeoliforme|\\burticariformes|purpuric[oa]|\\berup(?:cao|coes)\\s+cutane[oa]s?\\b"),
    tosse = str_detect(combinacao, "\\btoss?s?e?\\b"),
    artral = str_detect(combinacao, "\\bar?tralgias?\\b"),
    artrite = str_detect(combinacao, "\\bar?trite\\b"),
    mialgia = str_detect(combinacao, "\\bmial?gi?as?\\b"),
    dor_gargan = str_detect(combinacao, "\\bdor-ga(?:rganta|rgante|raganta|rgata|rgnta|ganta)\\b|\\bodinofagia|\\bodinfagia|\\bodinofgia|\\bodiofagia|\\bodnofagia"),
    dispneia = str_detect(combinacao, "\\bdis?p[ei]?neic?a|\\bcansa[cd]o"),
    cianose = str_detect(combinacao, "\\bciano[ts]"),
    insuf_resp = str_detect(combinacao, "\\binsuficiencia|\\binsuf-"),
    
    dor_ouvido = str_detect(combinacao, "\\b(?:ecrecao|secracao|secreao|secreca|secrecao|secrecaoa|serecao|dor)\\b(?:\\s+\\p{L}+){0,1}\\s+\\b(?:ouvido|ouvidod|ouvidos|pouvido|\\baauricular\\b|\\baricular\\b|\\bauricualar\\b|\\bauricular\\b|\\bauriculr\\b)\\b"),
    otalgia = str_detect(combinacao, "\\baotalgia\\b|\\bhotalgia\\b|\\boltalgia\\b|\\bortalgia\\b|\\botagia\\b|\\botaklgia\\b|\\botalcgia\\b|\\botalfgia\\b|\\botalfia\\b|\\botalga\\b|\\botalgia\\b|\\botalgiae\\b|\\botaligia\\b|\\botalkgia\\b|\\botaogia\\b|\\botlgia\\b|\\bptalgia\\b"),
    otite = str_detect(combinacao, "\\baotite\\b|\\bomite\\b|\\boptite\\b|\\botie\\b|\\botite\\b|\\botites\\b|\\botte\\b"),
    dor_ouvido_todos = ifelse(dor_ouvido | otalgia | otite, TRUE, FALSE),
    
    # Criar combinações auxiliares 
    # Identifica atendimentos com febre associada a sintomas respiratórios
    # altos, usados para exclusão da síndrome arbovirose-like.
    tosse_dor_garganta_otalgia = febre & (tosse | dor_gargan | dor_ouvido_todos),
    
    ## Classificar síndromes 
    # Síndrome respiratória.
    sind_resp = febre & (tosse | dor_gargan | dispneia | cianose | insuf_resp),
    
    # Classificar síndrome compatível com arbovirose 
    # Identifica atendimentos com febre e pelo menos duas manifestações
    # compatíveis com arbovirose.
    sind_arbo_anterior = febre & (
      (dor_retro & cefaleia) |
        (dor_retro & exant) |
        (dor_retro & mialgia) |
        (dor_retro & artrite) |
        (dor_retro & artral) |
        (cefaleia & exant) |
        (cefaleia & mialgia) |
        (cefaleia & artrite) |
        (cefaleia & artral) |
        (exant & mialgia) |
        (exant & artrite) |
        (exant & artral) |
        (mialgia & artrite) |
        (mialgia & artral) |
        (artrite & artral)
    ),
    
    # Remove da síndrome arbovirose-like os casos com combinação respiratória
    # definida como critério de exclusão.
    sind_arbo = sind_arbo_anterior & !tosse_dor_garganta_otalgia
  )
  
  return(df)
}

#####
# Processar base em blocos ----
# Descrição:
#   Processa uma base de atendimentos em partes menores, salvando o resultado
#   de cada bloco em um arquivo .rds separado. Essa estratégia reduz o uso de
#   memória e permite retomar o processamento caso a execução seja interrompida.
#
# Argumentos:
#   df:
#     Base de dados completa a ser processada.
#
#   n_linhas:
#     Número de linhas em cada bloco de processamento. O padrão é 10000.
#     Para processar toda a base de uma vez, utilizar nrow(df).
#
#   out_dir:
#     Diretório onde os arquivos .rds de cada bloco serão salvos.
#     O padrão é "processamento_blocos".
#
#   prefixo:
#     Prefixo usado no nome dos arquivos salvos. O padrão é "chunk".
#     Os arquivos serão salvos no formato: prefixo_0001.rds,
#     prefixo_0002.rds, etc.
#
#   sobrescrever:
#     Valor lógico. Se TRUE, blocos já processados serão processados novamente.
#     Se FALSE, arquivos já existentes serão pulados. O padrão é FALSE.
#
#   ...:
#     Argumentos adicionais repassados para a função processa_bloco().
#     Use este argumento para informar os nomes das colunas da base original.
#
# Retorno:
#   Retorna, de forma invisível, um vetor com os caminhos dos arquivos .rds
#   esperados para os blocos processados.
#
# Como utilizar:
#   arquivos_processados <- processa_em_blocos(
#     df = vs_amostra,
#     n_linhas = 10000,
#     out_dir = "processamento_serie",
#     prefixo = "chunk",
#     id_atendimento = "nr_atendimento_principal",
#     data_nascimento = "dt_nascimento",
#     campo_evolucao = "evolucao",
#     data_atendimento = "data_hora_atendimento",
#     campo_sexo = "sg_sexo",
#     nome_unidade_atendimento = "unidade",
#     corrigir_encoding_arg = TRUE
#   )
#
#   Para retomar uma execução interrompida, rode a mesma chamada novamente.
#   Os blocos já salvos serão ignorados, desde que sobrescrever = FALSE.
#
#   Para forçar o reprocessamento de todos os blocos:
#   arquivos_processados <- processa_em_blocos(
#     df = vs_amostra,
#     n_linhas = 10000,
#     out_dir = "processamento_serie",
#     prefixo = "chunk",
#     sobrescrever = TRUE
#   )

processa_em_blocos <- function(
    df,
    n_linhas = 10000,
    out_dir = "processamento_blocos",
    prefixo = "chunk",
    sobrescrever = FALSE,
    corrigir_encoding_arg = TRUE,
    ...
) {
  
  # Criar diretório de saída ----
  # Cria a pasta onde os arquivos processados serão salvos.
  # Caso a pasta já exista, nenhum aviso é exibido.
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  
  
  # Definir blocos de linhas ----
  # Calcula o número total de linhas da base e separa os índices em blocos
  # de tamanho definido por n_linhas.
  n <- nrow(df)
  
  ids_blocos <- split(
    seq_len(n),
    ceiling(seq_len(n) / n_linhas)
  )
  
  
  # Definir nomes dos arquivos de saída ----
  # Cada bloco terá um arquivo próprio com numeração de quatro dígitos.
  arquivos_saida <- file.path(
    out_dir,
    sprintf("%s_%04d.rds", prefixo, seq_along(ids_blocos))
  )
  
  
  # Processar blocos ----
  # Percorre cada bloco, processa os dados e salva o resultado em disco.
  for (i in seq_along(ids_blocos)) {
    
    arquivo_i <- arquivos_saida[i]
    
    # Pular blocos já processados ----
    # Se o arquivo do bloco já existir e sobrescrever = FALSE,
    # o bloco é ignorado para permitir retomada do processamento.
    if (file.exists(arquivo_i) && !sobrescrever) {
      message("Pulando bloco já processado: ", basename(arquivo_i))
      next
    }
    
    message("Processando bloco ", i, " de ", length(ids_blocos))
    
    # Selecionar linhas do bloco atual.
    bloco <- df[ids_blocos[[i]], , drop = FALSE]
    
    # Processar bloco atual usando processa_bloco().
    # Os argumentos adicionais informados em ... são repassados para essa função.
    resultado <- processa_bloco(
      df = bloco,
      corrigir_encoding_arg = corrigir_encoding_arg,
      ...
    )
    
    # Salvar resultado do bloco atual em arquivo .rds.
    saveRDS(resultado, arquivo_i)
    
    # Liberar memória antes de seguir para o próximo bloco.
    rm(bloco, resultado)
    gc()
  }
  
  
  # Retornar caminhos dos arquivos ----
  # Retorna invisivelmente o vetor com os caminhos esperados dos arquivos salvos.
  invisible(arquivos_saida)
}

# Processar tabelas de síndrome ----
# Descrição:
#   Cria tabelas agregadas para uma síndrome específica a partir da base
#   processada de atendimentos. A função calcula séries temporais semanais
#   por unidade de atendimento, por faixa etária e por sexo. Também calcula
#   proporções, média móvel e indicadores de alerta por EWMA.
#
# Argumentos:
#   dados:
#     Base de dados processada, contendo pelo menos as colunas da síndrome,
#     unidade de atendimento, dateweek, fxetar e sexo.
#
#   coluna_sindrome:
#     Nome da coluna, em formato de texto, que indica a síndrome a ser analisada.
#     Essa coluna deve ser lógica, com TRUE para atendimentos classificados como
#     a síndrome e FALSE caso contrário.
#
#   coluna_unidade_atendimento:
#     Nome da coluna, em formato de texto, que identifica a unidade de atendimento.
#
# Retorno:
#   Uma lista com três tabelas:
#     - tabela semanal da síndrome por unidade de atendimento;
#     - tabela semanal da síndrome por unidade e faixa etária;
#     - tabela semanal da síndrome por unidade e sexo.
#
#   Os nomes dos elementos da lista são criados automaticamente a partir do nome
#   informado em coluna_sindrome.
#
# Como utilizar:
#   sind_resp_list <- processar_sind_tbls(
#     dados = dados_municipio,
#     coluna_sindrome = "sind_resp_total",
#     coluna_unidade_atendimento = "UNIDADE_ATENDIMENTO"
#   )
#
#   Acessar as tabelas:
#   sind_resp_list$sind_resp_total_tbl
#   sind_resp_list$sind_resp_total_fx_etaria_tbl
#   sind_resp_list$sind_resp_total_sexo_tbl

processar_sind_tbls <- function(dados,
                                coluna_sindrome,
                                coluna_unidade_atendimento
) {
  
  # Criar tabela semanal da síndrome por unidade ----
  # Filtra os atendimentos classificados como a síndrome de interesse,
  # agrega os casos por semana e unidade, completa semanas sem casos com zero
  # e calcula proporções e média móvel.
  sind_tbl <- dados %>%
    rename(
      sindrome = all_of(coluna_sindrome),
      UNIDADE_ATENDIMENTO = all_of(coluna_unidade_atendimento)
    ) %>%
    filter(sindrome) %>% 
    group_by(dateweek, UNIDADE_ATENDIMENTO) %>% 
    reframe(n = sum(sindrome)) %>%
    complete(
      dateweek = seq(
        min(dateweek, na.rm = TRUE),
        max(dateweek, na.rm = TRUE),
        by = "week"
      ),
      UNIDADE_ATENDIMENTO,
      fill = list(n = 0)
    ) |>
    group_by(dateweek, UNIDADE_ATENDIMENTO) |>
    mutate(
      p = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      p = ifelse(is.nan(p), 0, p)
    ) |>
    group_by(dateweek) |>
    mutate(
      pc = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      pc = ifelse(is.nan(pc), 0, pc)
    ) |>
    group_by(UNIDADE_ATENDIMENTO) |>
    mutate(
      mm_direita = zoo::rollmean(
        n,
        k = 2,
        fill = NA,
        align = "right"
      )
    ) |>
    ungroup()
  
  
  # Criar tabela semanal da síndrome por faixa etária ----
  # Remove registros com faixa etária ignorada, agrega casos por semana,
  # unidade e faixa etária, completa combinações ausentes com zero e calcula
  # proporções e média móvel.
  sind_fx_etaria_tbl <- dados %>% 
    rename(
      sindrome = all_of(coluna_sindrome),
      UNIDADE_ATENDIMENTO = all_of(coluna_unidade_atendimento)
    ) %>%
    filter(sindrome) %>%
    filter(fxetar != "Ignorado") %>% 
    drop_na() %>% 
    group_by(UNIDADE_ATENDIMENTO, dateweek, fxetar) %>% 
    reframe(n = sum(sindrome)) %>%
    arrange(dateweek) |>
    complete(
      dateweek = seq(
        min(dateweek, na.rm = TRUE),
        max(dateweek, na.rm = TRUE),
        by = "week"
      ),
      UNIDADE_ATENDIMENTO,
      fxetar,
      fill = list(n = 0)
    ) |>
    group_by(dateweek, UNIDADE_ATENDIMENTO) |>
    mutate(
      p = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      p = ifelse(is.nan(p), 0, p)
    ) |>
    group_by(dateweek, fxetar) |>
    mutate(
      pc = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      pc = ifelse(is.nan(pc), 0, pc)
    ) |>
    group_by(UNIDADE_ATENDIMENTO) |>
    mutate(
      mm_direita = zoo::rollmean(
        n,
        k = 2,
        fill = NA,
        align = "right"
      )
    ) |>
    ungroup()
  
  # Criar tabela semanal da síndrome por sexo ----
  # Remove registros com sexo ignorado, agrega casos por semana, unidade e sexo,
  # completa combinações ausentes com zero e calcula proporções e média móvel.
  sind_sexo_tbl <- dados %>%
    rename(
      sindrome = all_of(coluna_sindrome),
      UNIDADE_ATENDIMENTO = all_of(coluna_unidade_atendimento)
    ) %>%
    filter(sindrome) %>%
    filter(sexo != "Ignorado") %>%
    drop_na() %>%
    group_by(UNIDADE_ATENDIMENTO, dateweek, sexo) %>%
    reframe(n = sum(sindrome)) %>%
    arrange(dateweek) |>
    complete(
      dateweek = seq(
        min(dateweek, na.rm = TRUE),
        max(dateweek, na.rm = TRUE),
        by = "week"
      ),
      UNIDADE_ATENDIMENTO,
      sexo,
      fill = list(n = 0)
    ) |>
    group_by(dateweek, UNIDADE_ATENDIMENTO) |>
    mutate(
      p = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      p = ifelse(is.nan(p), 0, p)
    ) |>
    group_by(dateweek, sexo) |>
    mutate(
      pc = round(n / sum(n, na.rm = TRUE), 4)
    ) |>
    ungroup() |>
    mutate(
      pc = ifelse(is.nan(pc), 0, pc)
    ) |>
    group_by(UNIDADE_ATENDIMENTO) |>
    mutate(
      mm_direita = zoo::rollmean(
        n,
        k = 2,
        fill = NA,
        align = "right"
      )
    ) |>
    ungroup()
  
  
  # Criar tabela de alerta ----
  # Aplica o algoritmo EWMA à série semanal de casos por unidade de atendimento.
  # O resultado indica semanas com comportamento esperado ou alerta.
  alert_tbl <- sind_tbl |>
    group_by(UNIDADE_ATENDIMENTO) %>%
    alert_ewma(t = dateweek, y = n) %>%
    mutate(
      alert = factor(
        alert,
        levels = c("blue", "red", "yellow", "grey")
      )
    ) |>
    select(UNIDADE_ATENDIMENTO, dateweek, alert)
  
  
  # Combinar série semanal com alertas ----
  # Adiciona a classificação de alerta à tabela principal da síndrome.
  tbl_final <- sind_tbl |>
    mutate(dateweek = as.Date(dateweek)) |>
    left_join(
      alert_tbl,
      by = c("UNIDADE_ATENDIMENTO", "dateweek")
    )
  
  
  # Organizar saída ----
  # Agrupa as três tabelas em uma lista e nomeia os elementos de acordo com
  # a síndrome analisada.
  output <- list(
    sindrome = tbl_final,
    idade = sind_fx_etaria_tbl,
    sexo =  sind_sexo_tbl
  )
  
  names(output) <- paste0(
    coluna_sindrome,
    c("_tbl", "_fx_etaria_tbl", "_sexo_tbl")
  )
  
  return(output)
}

### Plotar série temporal
# Plotar série temporal de atendimentos ----
# Descrição:
#   Gera um gráfico de série temporal semanal com o número de atendimentos e
#   a respectiva média móvel. O gráfico é separado por unidade de atendimento
#   usando facet_wrap().
#
# Argumentos:
#   data:
#     Tabela com os dados agregados por semana e unidade de atendimento.
#     Deve conter, pelo menos, as colunas dateweek, n, mm_direita e
#     UNIDADE_ATENDIMENTO.
#
#   quebra_datas:
#     Intervalo entre as marcações do eixo x. Deve ser informado em formato
#     aceito por scale_x_date(), como "4 weeks", "1 month" ou "2 months".
#     O padrão é "4 weeks".
#
#   cor_barra:
#     Cor das barras que representam o número de atendimentos.
#     O padrão é "#dfc27d".
#
#   cor_media:
#     Cor da linha que representa a média móvel.
#     O padrão é "#d94801".
#
#   titulo:
#     Título do gráfico. O padrão é "".
#
# Retorno:
#   Um objeto ggplot com a série temporal de atendimentos por unidade.
#
# Como utilizar:
#   plot_serie_atendimentos(
#     total_atendimento_tbl,
#     quebra_datas = "4 weeks",
#     titulo = "Total de atendimentos"
#   )
#
#   A função também pode ser usada para síndromes específicas:
#   plot_serie_atendimentos(
#     sind_resp_list$sind_resp_total_tbl,
#     quebra_datas = "4 weeks",
#     titulo = "Síndrome Respiratória"
#   )

plot_serie_atendimentos <- function(data, 
                                    quebra_datas = "4 weeks",
                                    cor_barra = "#dfc27d",
                                    cor_media = "#d94801",
                                    titulo = ""
) {
  
  # Construir gráfico ----
  # Combina barras para o número absoluto de atendimentos e linha para a média
  # móvel, separando os painéis por unidade de atendimento.
  data |>
    ggplot() +
    
    # Adicionar barras de atendimentos ----
  # Representa o número semanal de atendimentos.
  geom_col(
    aes(
      x = dateweek,
      y = n,
      fill = "Número de atendimentos"
    ),
    stat = "identity"
  ) +
    
    # Adicionar linha de média móvel ----
  # Representa a média móvel calculada previamente na coluna mm_direita.
  geom_line(
    aes(
      x = dateweek,
      y = mm_direita,
      color = "Média móvel (7 dias)"
    ),
    linewidth = 1.1
  ) +  
    
    # Definir cores da legenda ----
  scale_fill_manual(
    "",
    values = c("Número de atendimentos" = cor_barra)
  ) +
    
    scale_color_manual(
      "",
      values = c("Média móvel (7 dias)" = cor_media)
    ) +
    
    # Definir rótulos do gráfico ----
  labs(
    x = "Semana Epidemiológica",
    y = "Número de atendimentos",
    title = titulo
  ) +
    
    # Separar gráfico por unidade de atendimento ----
  facet_wrap(~UNIDADE_ATENDIMENTO, ncol = 2) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      axis.text.x = element_text(
        color = "grey20",
        size = 10,
        angle = 0,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      axis.text.y = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = 1,
        vjust = 0,
        face = "plain"
      ),
      axis.title.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = 0,
        face = "plain"
      ),
      axis.title.y = element_text(
        color = "grey20",
        size = 12,
        angle = 90,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      legend.text = element_text(size = 15),
      legend.title = element_text(size = 15),
      text = element_text(size = 15),
      title = element_text(size = 15),
      plot.title = element_text(hjust = 0.5),
      legend.position = "bottom"
    ) +
    
    # Configurar eixo temporal ----
  # Define o intervalo dos rótulos no eixo x e o formato das datas.
  scale_x_date(
    date_breaks = quebra_datas, 
    labels = scales::label_date_short(format = c("%Y", "%U"))
  )
}
# Plotar distribuição por sexo ----
# Descrição:
#   Gera um gráfico de barras empilhadas proporcionais mostrando a distribuição
#   dos atendimentos por sexo ao longo das semanas epidemiológicas. O gráfico é
#   separado por unidade de atendimento usando facet_wrap().
#
# Argumentos:
#   data:
#     Tabela agregada por semana, unidade de atendimento e sexo.
#     Deve conter, pelo menos, as colunas dateweek, n, sexo e
#     UNIDADE_ATENDIMENTO.
#
#   paleta:
#     Vetor de cores usado para representar as categorias de sexo.
#     O padrão é c("#984ea3", "#4daf4a", "#bdbdbd").
#
#   titulo:
#     Título do gráfico. O padrão é "".
#
#   quebra_datas:
#     Intervalo entre as marcações do eixo x. Deve ser informado em formato
#     aceito por scale_x_date(), como "4 weeks", "1 month" ou "2 months".
#     O padrão é "4 weeks".
#
# Retorno:
#   Um objeto ggplot com a distribuição proporcional dos atendimentos por sexo.
#
# Como utilizar:
#   plot_sexo(
#     sind_resp_list$sind_resp_total_sexo_tbl,
#     quebra_datas = "4 weeks",
#     titulo = "Síndrome Respiratória"
#   )

plot_sexo <- function(data,
                      paleta = c("#984ea3", "#4daf4a", "#bdbdbd"),
                      titulo = "",
                      quebra_datas = "4 weeks") {
  
  # Construir gráfico ----
  # Cria barras empilhadas proporcionais por sexo, separadas por unidade.
  fig <- data |>
    ggplot() +
    
    # Adicionar barras proporcionais ----
  geom_bar(
    aes(
      x = dateweek,
      y = n,
      fill = sexo
    ),
    position = "fill",
    stat = "identity"
  ) +
    
    # Configurar eixo y como proporção ----
  scale_y_continuous(
    labels = c("0%", "25%", "50%", "75%", "100%")
  ) +
    
    # Definir cores das categorias de sexo ----
  scale_fill_manual(values = paleta) +
    
    # Definir rótulos do gráfico ----
  labs(
    x = "Semana Epidemiológica",
    y = "Proporção de atendimentos",
    fill = "Sexo",
    title = titulo
  ) +
    
    # Separar gráfico por unidade de atendimento ----
  facet_wrap(
    ~UNIDADE_ATENDIMENTO,
    scales = "free_y",
    ncol = 2
  ) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      axis.text.x = element_text(
        color = "grey20",
        size = 10,
        angle = 0,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      axis.text.y = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = 1,
        vjust = 0,
        face = "plain"
      ),
      axis.title.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = 0,
        face = "plain"
      ),
      axis.title.y = element_text(
        color = "grey20",
        size = 12,
        angle = 90,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      legend.text = element_text(size = 15),
      legend.title = element_text(size = 15),
      text = element_text(size = 15),
      plot.title = element_text(hjust = 0.5),
      title = element_text(size = 15),
      legend.position = "bottom"
    ) +
    
    # Configurar eixo temporal ----
  scale_x_date(
    date_breaks = quebra_datas,
    labels = scales::label_date_short(format = c("%Y", "%U"))
  )
  
  # Retornar gráfico ----
  return(fig)
}

###
# Plotar distribuição por faixa etária ----
# Descrição:
#   Gera um gráfico de barras empilhadas proporcionais mostrando a distribuição
#   dos atendimentos por faixa etária ao longo das semanas epidemiológicas.
#   O gráfico é separado por unidade de atendimento usando facet_wrap().
#
# Argumentos:
#   data:
#     Tabela agregada por semana, unidade de atendimento e faixa etária.
#     Deve conter, pelo menos, as colunas dateweek, n, fxetar e
#     UNIDADE_ATENDIMENTO.
#
#   paleta:
#     Vetor de cores usado para representar as categorias de faixa etária.
#     O padrão é paleta_escuro.
#
#   titulo:
#     Título do gráfico. O padrão é "".
#
#   quebra_datas:
#     Intervalo entre as marcações do eixo x. Deve ser informado em formato
#     aceito por scale_x_date(), como "4 weeks", "1 month" ou "2 months".
#     O padrão é "4 weeks".
#
# Retorno:
#   Um objeto ggplot com a distribuição proporcional dos atendimentos por faixa etária.
#
# Como utilizar:
#   plot_faixa_etaria(
#     sind_resp_list$sind_resp_total_fx_etaria_tbl,
#     quebra_datas = "4 weeks",
#     titulo = "Síndrome Respiratória"
#   )

plot_faixa_etaria <- function(data,
                              paleta = c("#22A884FF", "#762a83", "#bf812d","#377eb8", "#a63603", "#dfc27d", "#BDBDBD"),
                              titulo = "",
                              quebra_datas = "4 weeks") {
  
  # Construir gráfico ----
  # Cria barras empilhadas proporcionais por faixa etária, separadas por unidade.
  data |>
    ggplot() +
    
    # Adicionar barras proporcionais ----
  geom_bar(
    aes(
      x = dateweek,
      y = n,
      fill = fxetar
    ),
    position = "fill",
    stat = "identity"
  ) +
    
    # Configurar eixo y como proporção ----
  scale_y_continuous(
    labels = c("0%", "25%", "50%", "75%", "100%")
  ) +
    
    # Definir cores das categorias de faixa etária ----
  scale_fill_manual(values = paleta) + 
    
    # Definir rótulos do gráfico ----
  labs(
    x = "Semana Epidemiológica",
    y = "Proporção de atendimentos",
    fill = "Faixa etária",
    title = titulo
  ) +
    
    # Separar gráfico por unidade de atendimento ----
  facet_wrap(
    ~UNIDADE_ATENDIMENTO,
    scales = "free_y",
    ncol = 2
  ) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      axis.text.x = element_text(
        color = "grey20",
        size = 10,
        angle = 0,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      axis.text.y = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = 1,
        vjust = 0,
        face = "plain"
      ),
      axis.title.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = 0,
        face = "plain"
      ),
      axis.title.y = element_text(
        color = "grey20",
        size = 12,
        angle = 90,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      legend.text = element_text(size = 15),
      legend.title = element_text(size = 15),
      plot.title = element_text(hjust = 0.5),
      text = element_text(size = 15),
      title = element_text(size = 15),
      legend.position = "bottom"
    ) +
    
    # Configurar eixo temporal ----
  scale_x_date(
    date_breaks = quebra_datas,
    labels = scales::label_date_short(format = c("%Y", "%U"))
  )
}


# Plotar série temporal com alertas ----
# Descrição:
#   Gera uma série temporal semanal do número de atendimentos, destacando os
#   alertas detectados pelo algoritmo EWMA. Cada ponto da série é colorido de
#   acordo com a classificação de alerta e os gráficos são separados por unidade
#   de atendimento.
#
# Argumentos:
#   data:
#     Tabela contendo a série temporal semanal e a classificação de alerta.
#     Deve conter, pelo menos, as colunas dateweek, n, alert e
#     UNIDADE_ATENDIMENTO.
#
#   titulo:
#     Título do gráfico. O padrão é "".
#
#   quebra_datas:
#     Intervalo entre as marcações do eixo x. Deve ser informado em formato
#     aceito por scale_x_date(), como "4 weeks", "1 month" ou "2 months".
#     O padrão é "4 weeks".
#
# Retorno:
#   Um objeto ggplot com a série temporal e a classificação dos alertas.
#
# Como utilizar:
#   plot_alerta(
#     sind_resp_list$sind_resp_total_tbl,
#     quebra_datas = "4 weeks",
#     titulo = "EWMA: Síndrome Respiratória"
#   )

plot_alerta <- function(data,
                        titulo = "",
                        quebra_datas = "4 weeks") {
  
  # Construir gráfico ----
  # Plota a série temporal semanal e destaca os alertas gerados pelo algoritmo EWMA.
  ggplot(data) +
    
    # Adicionar linha da série temporal ----
  geom_line(
    aes(
      x = dateweek,
      y = n
    ),
    color = "#254B73",
    linewidth = 0.7
  ) +
    
    # Adicionar pontos coloridos conforme o alerta ----
  geom_point(
    aes(
      x = dateweek,
      y = n,
      color = alert
    ),
    size = 3
  ) +
    
    # Definir cores e legenda dos alertas ----
  scale_color_manual(
    values = c("#254B73", "#A50026", "#FDD081", "grey70"),
    name = "Detecção",
    labels = c(
      "Nenhum",
      "Alerta",
      "Aviso",
      "Sem dados de linha de base"
    )
  ) +
    
    # Configurar eixo y ----
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(c(0, 0.2)),
    labels = scales::comma,
    name = "Número de atendimentos"
  ) +
    
    # Definir rótulos do gráfico ----
  labs(
    x = "Semana epidemiológica (SE)",
    title = titulo
  ) +
    
    # Separar gráfico por unidade de atendimento ----
  facet_wrap(
    ~UNIDADE_ATENDIMENTO,
    ncol = 2
  ) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      axis.text.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      axis.text.y = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = 1,
        vjust = 0,
        face = "plain"
      ),
      axis.title.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = 0,
        face = "plain"
      ),
      axis.title.y = element_text(
        color = "grey20",
        size = 12,
        angle = 90,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      legend.text = element_text(size = 15),
      legend.title = element_text(size = 15),
      text = element_text(size = 15),
      title = element_text(size = 11),
      plot.title = element_text(hjust = 0.5),
      legend.position = "bottom"
    ) +
    
    # Configurar eixo temporal ----
  scale_x_date(
    date_breaks = quebra_datas,
    labels = scales::label_date_short(format = c("%Y", "%U"))
  )
}

# Plotar incompletude dos dados ----
# Descrição:
#   Calcula e visualiza a proporção de valores ausentes nas variáveis
#   selecionadas, estratificando os resultados por unidade de atendimento.
#   O resultado é apresentado como um mapa de calor, em que cores mais intensas
#   indicam maior proporção de dados faltantes.
#
# Argumentos:
#   data:
#     Base de dados a ser avaliada.
#
#   variaveis:
#     Vetor de caracteres com os nomes das colunas que terão a incompletude
#     avaliada.
#
#   coluna_unidade:
#     Nome da coluna, em formato de texto, que identifica a unidade de atendimento.
#
# Retorno:
#   Um objeto ggplot com o mapa de calor da proporção de dados faltantes por
#   variável e unidade de atendimento.
#
# Como utilizar:
#   plot_incompletude(
#     dados_municipio,
#     variaveis = c(
#       "data_hora_atendimento",
#       "dt_nascimento",
#       "evolucao",
#       "sg_sexo",
#       "fxetar"
#     ),
#     coluna_unidade = "UNIDADE_ATENDIMENTO"
#   )

plot_incompletude <- function(data, variaveis, coluna_unidade) {
  
  # Calcular incompletude por unidade ----
  # Padroniza o nome da coluna de unidade, seleciona as variáveis de interesse
  # e calcula a quantidade de valores ausentes por variável e unidade.
  data %>% 
    rename(
      unidade_atendimento = all_of(coluna_unidade)
    ) |>
    
    select(
      unidade_atendimento,
      all_of(variaveis)
    ) %>% 
    
    # Padronizar variáveis de data ----
  # Converte campos de data para texto antes de calcular incompletude,
  # garantindo uma avaliação consistente após a conversão para Date.
  mutate(
    data_hora_atendimento = as.character(as.Date(data_hora_atendimento)),
    dt_nascimento = as.character(as.Date(dt_nascimento)),
    total = NA
  ) %>% 
    
    # Contar valores ausentes ----
  # A coluna total é criada como NA para representar o denominador total
  # de registros por unidade após a agregação.
  group_by(unidade_atendimento) %>%
    reframe(
      across(everything(), ~ sum(is.na(.)))
    ) |>
    ungroup() |>
    
    # Reorganizar tabela para formato longo ----
  pivot_longer(
    col = variaveis,
    names_to = "var",
    values_to = "missing"
  ) %>% 
    
    # Calcular proporção de incompletude ----
  # Divide o número de valores ausentes pelo total de registros da unidade.
  mutate(
    prop_mis = round(missing / total * 100, 2)
  ) %>% 
    
    # Construir gráfico ----
  ggplot(
    aes(
      x = unidade_atendimento,
      y = var,
      fill = prop_mis
    )
  ) +
    
    # Adicionar mapa de calor ----
  geom_tile(color = "black") +
    
    # Definir escala de cores ----
  # A escala é fixada entre 0% e 100% para permitir comparação entre gráficos.
  scale_fill_gradientn(
    "",
    colours = c("white", "orange", "red", "darkred"),
    limits = c(0, 100)
  ) +
    
    # Definir rótulos do gráfico ----
  labs(
    y = "Variáveis",
    x = "Nome da Unidade de Atendimento",
    title = "Proporção de dados faltantes"
  ) +
    
    # Adicionar percentual em cada célula ----
  geom_text(
    aes(label = paste0(round(prop_mis, 1), "%")),
    color = "black",
    size = 4
  ) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      legend.position = "right",
      axis.text.x = element_text(
        size = 9,
        angle = 45,
        hjust = 1
      ),
      plot.title = element_text(hjust = 0.5),
      axis.text.y = element_text(size = 9)
    )
}
# Plotar frequência de sintomas ----
# Descrição:
#   Calcula e visualiza a frequência total dos sintomas identificados na base
#   processada. A função transforma as colunas lógicas de sintomas para o
#   formato longo, soma os registros positivos de cada sintoma e gera um gráfico
#   de barras horizontais ordenado por frequência.
#
# Argumentos:
#   data:
#     Base de dados processada contendo as colunas lógicas de sintomas.
#
# Retorno:
#   Um objeto ggplot com a frequência total dos sintomas identificados.
#
# Como utilizar:
#   plot_freq_sintomas(dados_municipio)

plot_freq_sintomas <- function(data) {
  
  # Definir colunas de sintomas ----
  # Lista as variáveis lógicas usadas para identificar sintomas e queixas
  # extraídas do campo de evolução clínica.
  colunas_sintomas <- c(
    "febre",
    "exant",
    "tosse",
    "artral",
    "artrite",
    "mialgia",
    "cefaleia",
    "dor_gargan",
    "dispneia",
    "cianose",
    "insuf_resp",
    "nega",
    "dor_ouvido_todos",
  )
  
  
  # Calcular frequência dos sintomas ----
  # Transforma as colunas de sintomas para formato longo e soma os valores TRUE
  # de cada sintoma.
  data %>% 
    pivot_longer(
      cols = all_of(colunas_sintomas),
      values_to = "freq",
      names_to = "sintomas"
    ) %>% 
    group_by(sintomas) %>% 
    summarise(
      n = sum(freq, na.rm = TRUE),
      .groups = "drop"
    ) %>% 
    
    # Ordenar sintomas por frequência ----
  arrange(desc(n)) %>%
    
    # Construir gráfico ----
  ggplot() +
    
    # Adicionar barras horizontais ----
  geom_bar(
    aes(
      fct_reorder(sintomas, n),
      n
    ),
    fill = "#238b45",
    stat = "identity",
    width = 0.8
  ) +
    
    # Inverter coordenadas para facilitar leitura dos nomes dos sintomas.
    coord_flip() +
    
    # Adicionar rótulos com frequências absolutas ----
  geom_text(
    aes(
      y = n,
      x = fct_reorder(sintomas, n),
      label = n
    ), 
    hjust = -0.09,
    fontface = "bold",
    size = 3
  ) + 
    
    # Definir rótulos do gráfico ----
  labs(
    title = "Sintomas (Sintoma/Queixa)",
    x = "Sintomas",
    y = "Frequência"
  ) +
    
    # Aplicar tema visual ----
  theme_classic() +
    theme(
      axis.text.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      axis.text.y = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = 1,
        vjust = 0,
        face = "plain"
      ),
      axis.title.x = element_text(
        color = "grey20",
        size = 12,
        angle = 0,
        hjust = .5,
        vjust = 0,
        face = "plain"
      ),
      axis.title.y = element_text(
        color = "grey20",
        size = 12,
        angle = 90,
        hjust = .5,
        vjust = .5,
        face = "plain"
      ),
      legend.text = element_text(size = 15),
      legend.title = element_text(size = 15),
      text = element_text(size = 15),
      title = element_text(size = 11),
      legend.position = "none"
    )
}
