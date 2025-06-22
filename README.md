# Simulador de Matricula com Verificação de Conflito de Horários e Requisitos

Trabalho final da disciplina de Laboratório de Banco de Dados, ministrada pelo Prof. Dr. Marcio Inacio da Silva.
O trabalho consiste na modelagem, projeto e construção de um banco de dados relacional, com a integração do banco de dados com o código feito na linguagem Python, além da pesquisa adicional sobre SQL e o minimundo proposto para solucinar problemas reais apresentados nos requisitos.

## 🚀 Links Importantes

* **Link do projeto no Google Drive** https://drive.google.com/drive/folders/1Vt2SG8_wW8Xkm1AGNM46SmzwrAI0XIV3?usp=drive_link
* **[link da Apresentação no youtube]()**
* **Link do GitHub** https://github.com/miguelpaullo/Lab-BD))

### 📋 Pré-requisitos

* Você irá precisar de uma IDE como o VSCode com o interpretador do Python instalado
* Baixar o Docker Desktop caso esteja utilizando Windows
* Levantar os container do docker
* Voltando ao VSCode será necessário baixar a biblioteca pyscopg2 que faz a conexão do código com o BD
* E baixar a API Faker para gerar os dados aleatórios

### 🔧 Instalação

No link do google drive temos duas pastas com os executáveis, uma com o banco de dados povoado e uma com o banco de dados sem dados, porém a execução será a mesma, com a única diferença que a API Faker será executada na pasta "Executavel com BD sem dados"

O convite para ser colaborador no git foi enviado ao seu email institucional professor!
Lá você poderá verificar todo o nosso processo de desenvolvimento, porém é possivel acompanhar por meio dos backups no drive

Descrevendo passo a passo:

No docker:

```
Levantando o container => docker compose -f postgresql.yml.txt up -d
Importando o Banco de Dados povoado => docker exec -i meucontainer psql -U postgres -d sistemaEscolar < trabalho_finalizado_BD.sql
Importando o Banco de Dados sem dados => docker exec -i meucontainer psql -U postgres -d sistemaEscolar < dump.sql
```

No VSCode:

```
Tem a possibilidade de clonar o repositório do git ou baixar a pasta do drive e executa-la
Realizando a instalação do psycopg2 => pip install psycopg2
Realizando a instalação da API Faker => pip install faker
```

## ⚙️ Executando os testes

No terminal podemos executar o arquivo

```
Lembre-se de estar no diretório certo => cd ...
python main.py
Se você tiver mais de uma versão do Python instalada pode ser necessário especificar a versão
```

### 🔩 Principais Funcionalidades

Funcionalidades Implementadas:

```
Cadastrar novos alunos
Realizar matriculas em disciplinas
Apresentar grade horária simulada
Mostrar disciplinas recomendadas ao usuário se matricular
Relatórios: alunos matriculados em determinada turma, grade individual de cada aluno cadastrado, disciplinas mais e menos procuradas, alunos aptos a TCC e/ou Estágio
```

Funcionalidades Não Implementadas

```
Relatório: disciplinas com maior índice de reprovação
```

Todas as funcionalidade são executadas via linha de comando:
* Com um menu principal com 6 opções que o usuário pode escolher
* E também um menu secundário exclusivo para os relatórios, com 6 opções

## 🛠️ Construído com

* Python
* VSCode
* Docker Desktop
* Banco de Dados Relacional Postgres
* API Faker
* psycopg2

## ✒️ Autores

* **Miguel Paulo Rodrigues de Macedo RGA: 2024.1906.011-0** - *Integração Python => Postgres, Geração de dados aleatórios, Código Fonte e Documentação* - [miguelpaullo](https://github.com/miguelpaullo)
* **Beatriz V. G. da Silva RGA: 2024.1906.071-4** - *Código Fonte e Documentação* - [biavieirakkj](https://github.com/biavieirakkj)
* **Luciana Nunes Viana RGA: 2024.1906.044-7** - *Código Fonte e Documentação* - [lunah1](https://github.com/lunah1)

## 📄 Orientador

* **Prof. Dr. Marcio Inacio da Silva** - *Professor e Orientador* - [mapsiva](https://github.com/mapsiva)

## 🎁 Expressões de gratidão

* Obrigado **Armsstrong Lohãns** - *Criador do template READ.ME* - [Armstrong Lohãns](https://gist.github.com/lohhans) ❤️
