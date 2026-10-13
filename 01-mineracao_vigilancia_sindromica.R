# Carregar pacotes 
if (!requireNamespace("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  cusum,
  data.table,
  janitor,
  lubridate,
  plotly,
  purrr,
  remotes,
  rio,
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

if (!requireNamespace("Rnssp")) {
  devtools::install_github("cdcgov/Rnssp")
} else {
  require(Rnssp)
}

### Ler arquivo

# Ler base de validação 
# Define o caminho do arquivo de entrada.
f <- "amostra_municipio.csv"

# Lê a base de validação usando codificação Latin-1.
dados <- fread(f, encoding = "Latin-1")

### Definições

# Definir stopwords 
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

# Criar expressão regular para stopwords 
# Converte a lista de stopwords em uma única expressão regular.
# O uso de \\b indica limites de palavra, evitando substituições parciais.
stop_reg <- paste0("\\b", paste(stopwords, collapse = "\\b|\\b"), "\\b")

### Processamento
dados_municipio <- dados |>
  
  mutate(
    
    ## Padronização das variáveis
    
    # Converte datas, padroniza sexo, calcula idade e classifica faixa etária.
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
    ),
    
  ## Limpeza do texto

  # Decodificar e remover símbolos de HTML
  evolucao_limpo = HTMLdecode(evolucao),
  
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

