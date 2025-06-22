import psycopg2 as pg
from psycopg2 import Error
from psycopg2 import sql
from connect import conn, encerra_conn
from populando_faker import gerar_dados_aleatorios, inserir_dados

def povoar(cursor, tabela):
    """
    Função para verificar se o banco de dados já foi povoado com a API Faker
    """
    try:
        cursor.execute(sql.SQL("""select count(*) from {};""").format(sql.Identifier(tabela)))
        contador = cursor.fetchone()[0]
        return contador == 0
    except pg.Error as e:
        print(f"Erro ao verificar se o bando de dados está povoado: {e}")
        return False

def verificar_matricula (cursor, matricula_aluno):
    """
    Função para verificar se a matricula existe no BD
    """
    try:

        mat = "select COUNT(*) from aluno where matricula_aluno = %s;"
        cursor.execute(mat, (matricula_aluno,))
        valor = cursor.fetchone()[0]
        return valor > 0

    except pg.Error as e:
        print(f"Erro ao verificar matricula: {e}")
        return False

def verificar_disciplina(cursor, codigo_disciplina):
    """
    Função para verificar se o código de disciplina existe no BD
    """

    try:

        disc = "select COUNT(*) from disciplina where codigo_disciplina = %s;"
        cursor.execute(disc, (codigo_disciplina,))
        valor = cursor.fetchone()[0]
        return valor > 0

    except pg.Error as e:
        print(f"Erro ao verificar disciplina: {e}")
        return False

def verificar_pre_requisitos(cursor, matricula_aluno, codigo_disciplina):
    """
    Função para verificar se uma disciplina tem pré-requisitos
    """

    try:
        cursor.execute("""select codigo_disciplina_pre_requisito from verificar_pre_requisitos(%s, %s);""", (matricula_aluno, codigo_disciplina))
        resultado = cursor.fetchall()
        pre_requisito = [linha[0] for linha in resultado]
        return [linha[0] for linha in resultado]
    except pg.Error as e:
        print(f"Erro ao verificar pré-requisitos: {e}")
        return []

def verificar_horarios (cursor, matrcicula_aluno, id_turma):
    """
    Função para verificar o conflito de horários entre as turmas
    """
    try:
        cursor.execute("""select verificar_conflito_horario(%s, %s);""", (matrcicula_aluno, id_turma))
        conflito_existe = cursor.fetchone()[0]
        return conflito_existe
    except pg.Error as e:
        print(f"Erro ao verificar conflito de horários: {e}")
        return True

def verificar_turma(cursor, id_turma):
    """
    Função para verificar se a turma tem vaga para matricula
    """

    try:
        cursor.execute("""select turma_esta_cheia(%s);""", (id_turma,))
        turma_cheia = cursor.fetchone()[0]
        return turma_cheia
    except pg.Error as e:
        print(f"Erro ao verificar disponibilidade em turma: {e}")
        return True

def fazer_matricula(cursor, conexao):
    """
    Função que utiliza todas as funções acimas para realizar a matricula de fato
    """

    print("Vamos realizar sua matricula simulada\n")
    print("Primeiro vamos verificar se a disciplina escolhida tem pré-requisitos!\n")
    print("Por favor, digite a matricula do aluno: (ex.: 9999999)\n")
    rga = input().strip()

    #validação do registro do aluno
    while not verificar_matricula(cursor, rga):
        print("Matricula não encontrada, digite novamente...")
        rga = input().strip()
    print("Matricula válida!")

    #validação do código da disciplina
    print("\nPor favor, dgite o codigo da disciplina: (ex.: ABCD123)\n")
    cod = input().strip()
    while not verificar_disciplina(cursor, cod):
        print("\nCódigo de disciplina não encontrado, digite novamente...")
        cod = input().strip()
    print("\nCódigo de disciplina válido!")

    #validação dos pré-requisitos
    pre_requisitos = verificar_pre_requisitos(cursor, rga, cod)

    if pre_requisitos:
        print("\nO aluno não cumpriu os seguintes pré-requisitos:")
        for pre in pre_requisitos:
            print("- {}".format(pre))
        print("\nVocê não pode se matricular nesta disciplina, retornando ao menu principal")
        return
    
    print("\nVocê cumpriu todos os pré-requisitos necessários para a disciplina informada!")

    print("\nBuscando turmas discponíveis para a disciplina escolhida...")

    turmas_disponiveis = []
    #consulta para obter turmas disponiveis
    try:
        cursor.execute("""select * from turmas where codigo_disciplina = %s order by turno, id_turma""", (cod,))
        turmas_disciplina = cursor.fetchall()

        if not turmas_disciplina:
            print("Não há turmas disponiveis para a disciplina solicitada!")
            return
        print("\t - " * 10)
        print("\tTurmas disponíveis: ")
        print("\t{:<10} {:<10} {:<10} {:<10} {:<10} {:<10}".format('TURMA', 'SEMESTRE', 'TURNO', 'LOCAL', 'CAPACIDADE', 'PROFESSOR'))
        print("\t - " * 10)
    
        for t_id, codigo_disciplina, semestre, prof, turno, local, capacidade in turmas_disciplina:
            #verificar se a turma não está cheia
            if not verificar_turma(cursor, t_id):
                turmas_disponiveis.append({'id_turma': t_id, 'codigo_disciplina': codigo_disciplina, 'semestre': semestre, 'professor': prof, 'turno': turno, 'local': local, 'capacidade': capacidade})
                print("- {:<10} {:<10} {:<10} {:<10} {:<10} {:<10}".format(t_id, semestre, prof, turno, local, capacidade))
        if not turmas_disponiveis:
            print("Nenhuma turma disponivel no momento, podem estar todas cheias!")
            return
        
    except pg.Error as e:
        print(f"Erro ao buscar turmas disponiveis. Matricula cancelada: {e}")
        return
    except Exception as e:
        print(f"Ocorreu um erro inesperado! {e}")
        return
    
    #usuario irá escolher a turma
    turma = None
    while turma is None:
        try:
            id_turma = int(input("\nDigite o id da turma escolhida: "))

            #verificar se o id existe
            if any(turmas ['id_turma'] == id_turma for turmas in turmas_disponiveis):
                turma = id_turma
                print("\nTurma selecionada")
            else:
                print("\nID indisponivel não existe ou turma não está disponivel para matricula, por favor digite um id válido: ")
        except ValueError:
            print("\nEntrada inválida!")
    
    #verificar conflito de horários
    if verificar_horarios(cursor, rga, turma):
        print("\nConflito de horário detectado")
        print("Matricula CANCELADA!")
        return
    
    print("\nTurma com vaga disponível!")

    #Realizando a inserção na tabela matricula
    print("\nRealizando matricula...")
    try:
        cursor.execute("""insert into matricula (matricula_aluno, id_turma, status) values (%s, %s, %s) on conflict (matricula_aluno, id_turma) do nothing""", (rga, turma, 'Ativa'))
        conexao.commit()

        #verificando se foi inserido com sucesso
        if cursor.rowcount > 0:
            print("\nMatricula realizada com sucesso!")
        else:
            print("\nAluno já estava matriculado!")
    except pg.Error as e:
        print(f"\nErro ao matricular aluno: {e}")
        conexao.rollback()
        print("Matricula NÃO REALIZADA")
    except Exception as e:
        print(f"\nOcorreu um erro inesperado: {e}")
        print("Matricula NÃO REALIZADA")

    print("\nProcesso de matricula simulada realizado com sucesso!")

def inserir_novo_aluno(cursor, conexao):
    """
    Função para inserir um novo aluno, permite ao usuário cadastrar um novo aluno ao BD
    """
    print("\tCadastro de novo aluno")
    matricula = ""
    while True:
        matricula = input("\nDigite a matricula do aluno (ex.: 2025123): ").strip()
        if not matricula:
            print("\nMatricula não pode ser vazia!")
            continue
        if verificar_matricula(cursor, matricula):
            print("\nMatricula já existe")
        else:
            break
    
    nome = input("\nDigite o nome completo do aluno: ").strip()
    while not nome:
        print("\nNome não pode ser vazio")
        nome = "\nDigite o nome completo do aluno: ".strip()
    
    curso = input("\nDigite o curso do aluno (Ex. Engenharia de Software): ").strip()
    while not curso:
        print("\nCurso não pode ser vazio!")
        curso = input("\nDigite o curso do aluno (Ex. Engenharia de Software): ").strip()
    
    periodo_atual = -1
    while periodo_atual < 1 or periodo_atual > 10:
        try:
            periodo_atual = int(input("\nDigite o periodo atual (1-10): "))
            if periodo_atual < 1 or periodo_atual > 10:
                print("\nO período deve ser entre 1 e 10")
        except ValueError:
            print("\nEntrada Inválida. Digite um número inteiro")
    
    carga_horaria_maxima = -1
    while carga_horaria_maxima < 0:
        try: 
            carga_horaria_maxima = int(input("\nDigite a carga horária máxima em horas: "))
            if carga_horaria_maxima < 0:
                print("\nCarga horária não pode ser negativa!")
        except ValueError:
            print("\nEntrada inválida, digite um número inteiro!")
    
    try:
        cursor.execute("""insert into aluno(matricula_aluno, nome, curso, periodo_atual, carga_horaria_maxima) values (%s, %s, %s, %s, %s)""", (matricula, nome, curso, periodo_atual, carga_horaria_maxima))
        conexao.commit()
        print("\nAluno cadastrado com sucesso!")
    except pg.Error as e:
        print(f"\nErro ao cadastrar aluno: {e}")
        conexao.rollback()
    except Exception as e:
        print(f"\nOcorreu um erro inesperado ao cadastrar o aluno: {e}")
        print("Cadastro de aluno não realizado")

def grade_horaria_simulada(cursor):
    """
    Função para gerar a grade simulada do aluno
    """

    print("Carregando grade horária simulada...")
    rga = input("\nDigite a Matricula do Aluno: ").strip()
    print()
    if not verificar_matricula(cursor, rga):
        print("Erro: Matricula não encontrada")
        print("Não foi possivel visualzar a grade horária simulada")
        return
    try: 
        cursor.execute("""select nome_disciplina, dia_semana, horario_ini, horario_fim from visualizar_grade_horaria(%s);""", (rga,))
        grade = cursor.fetchall()

        if not grade:
            print("O aluno não possui disciplinas matriculadas")
            return
        print("\t - "*10)
        print("\t\t\tGRADE HORÁRIA SIMULADA: RGA => {} ".format(rga))
        print("\t - "*10)
        print("\t{:<30} {:<12} {:<15} {:<15} ".format('Disciplina', 'Dia da Semana', 'Início', 'Fim'))
        print("\t - "*10)

        for nome_dis, dia, hora_I, hora_F in grade:
            print("\t{:<30} {:<12} {:<15} {:<15} ".format(nome_dis, dia, str(hora_I), str(hora_F)))
        print("\t - "*10)
        print()
    except pg.Error as e:
        print(f"Erro ao consultar grade horária simulada: {e}")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

def disciplinas_recomendadas(cursor):
    """
    Função para gerar a disciplinas recomendadas ao aluno para cursar
    """
    rga = input("Digite a matrcicula do aluno para ver uma lista de recomendações de disciplinas: ")
    if not verificar_matricula(cursor, rga):
        print("Erro: Matricula não encontrada")
        print("Não foi possivel visualzar a recomendação de disciplinas")
        return
    recomendacoes = []

    try:
        cursor.execute("""select codigo_disciplina, nome_disciplina from disciplinas_nao_cursadas_ou_reprovadas(%s);""", (rga,))
        disciplinas = cursor.fetchall()
        if not disciplinas:
            print("O aluno já cursou todas as disciplinas disponiveis ou está cumprindo todos os pré-requisitos no momento")
            return
        print("\nForam encontradas {} disciplinas que o aluno não cursou, porém algumas tem pré-requisitos, vou exibir somente as que você pode cursar!".format(len(disciplinas)))
        for disc, nome_disc in disciplinas:
            pre_requisitos = verificar_pre_requisitos(cursor, rga, disc)
            if not pre_requisitos:
                recomendacoes.append({'codigo': disc, 'nome': nome_disc})
        if not recomendacoes:
            print("O aluno não possui disciplinas para matricular no momento, falta cursar os pré-requisitos")
            return
        
        print("\t - "*10)
        print("\t\t\tDISCIPLINAS RECOMENDADAS RGA => {} ".format(rga))
        print("\t - "*10)
        print("\t{:<10} {:<30} ".format('Codigo', 'Nome da Disciplina'))
        print("\t - "*10)

        for disc in recomendacoes:
            print("\t{:<10} {:<30}".format(disc['codigo'], disc['nome']))
        print("\t - "*10)
    except pg.Error as e:
        print(f"Erro ao buscar recomendações de disciplinas: {e}")
    except Exception as e:
        print(f"ocorreu um erro inesperado: {e}")

def relatorio_alunos_aptos_estagio_tcc(cursor):
    """
    Função gera um relatório com todos os alunos aptos a fazer TCC e/ou Estagio a partir de uma carga horária inserida pelo usuário
    """
    print("Relatório de Alunos Aptos à TCC ou Estágio\n")
    carga_minima = -1
    while carga_minima <= 0:
        try:
            carga_minima = int(input("Digite a carga horária mínima necessária para realizar TCC e/ou Estágio: "))
            if carga_minima <= 0:
                print("A carga mínima tem que ser um número inteiro positivo")
        except ValueError:
            print("Entrada Inválida")
        
    try:
        cursor.execute("""select matricula_aluno, nome_aluno from alunos_aptos_estagio(%s);""", (carga_minima,))
        alunos_aptos = cursor.fetchall()
        if not alunos_aptos:
            print("\nNenhum aluno apto a TCC ou Estágio")
            return
        print("\t - "*10)
        print()
        print("\tALUNOS APTOS A TCC OU ESTAGIO (Carga horária mínima = {})".format(carga_minima))
        print("\t - "*10)
        print("\t{:<15} {:<40}".format('Matricula', 'Nome do Aluno'))
        print("\t - "*10)
        for matricula, nome in alunos_aptos:
            print("\t{:<15} {:<40}".format(matricula, nome))
        print("\t - "*10)
    except pg.Error as e:
        print(f"Erro ao gerar relatório: {e}")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

def disciplinas_mais_menos_procuradas(cursor):
    """
    Essa função gera um relatório com as disciplinas mais e menos procurados pelos alunos, 
    utilizando a quantidade de matriculas de cada disciplina como parâmetro
    """
    print("\tGerando Relatório das disciplinas mais e menos procuradas")

    try:
        cursor.execute("""select nome_disciplina, total_matriculas from disciplinas_procuradas();""")
        disciplinas_dados = cursor.fetchall()

        if not disciplinas_dados:
            print("Nenhuma disciplina registrada ou não há matriculas cadastradas")
            return
        print()
        print("\t - "*10)
        print("\t\t\t\tDISCIPLINAS MAIS PROCURADAS")
        print("\t - "*10)
        print("\t{:<40} {:<50}".format('Nome Disciplina', 'Matriculas'))
        print("\t - "*10)
        for i in range(min(5, len(disciplinas_dados))):
            nome, total = disciplinas_dados[i]
            print("\t{:<40} {:<50}".format(nome, total))
        print("\t - "*10)

        if len(disciplinas_dados) > 5:
            print()
            print("\t - "*10)
            print("\t\t\t\tDISCIPLINAS MENOS PROCURADAS")
            print("\t - "*10)
            print("\t{:<40} {:<50}".format('Nome Disciplina', 'Matriculas'))
            print("\t - "*10)
        
            for i in range(max(0, len(disciplinas_dados) - 5), len(disciplinas_dados)):
                nome, total = disciplinas_dados[i]
                print("\t{:<40} {:<50}".format(nome, total))
            print("\t - "*10)
        elif len(disciplinas_dados) > 0:
            print("Não há disciplinas suficientes para listar")
    except pg.Error as e:
        print(f"Erro a listas disciplinas: {e}")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

def relatorio_alunos_por_turma(cursor):
    """
    Essa função solicita ao usuário o id de uma turma, para mostrar todos os matriculados na mesma
    """
    id_turma_usuario = -1
    while id_turma_usuario < 1000:
        try: 
            id_turma_usuario = int(input("\nDigite o ID da turma que você quer gerar o relatório: "))
            if id_turma_usuario < 1000:
                print("O ID das turmas é um numero entre 1000 e 1039!")
        except ValueError:
            print("Entrada Inválida!")
    try:
        cursor.execute("""select count(*) from turmas where id_turma = %s;""", (id_turma_usuario,))
        turma_existe = cursor.fetchone()[0] > 0

        if not turma_existe:
            print("Erro: turma não encontrada!")
            return
        cursor.execute("""select nome_aluno from alunos_da_turma(%s);""", (id_turma_usuario,))
        alunos_dados = cursor.fetchall()

        print("\t - "*10)
        print("\t\t\t\tAlunos matriculados na turma {}".format(id_turma_usuario))
        print("\t - "*10)
        print("\t{:<40} ".format('Nome do Aluno'))
        print("\t - "*10)

        for aluno in alunos_dados:
            nome_aluno = aluno[0]
            print("\t{:<40}".format(nome_aluno))
        print("\t - "*10)

    except pg.Error as e:
        print(f"Erro ao gerar lista de alunos na turma: {e}")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

def relatorio_grade_horaria_individual(cursor):
    """
    Essa função mostra a grade horária individual de cada aluno cadastrado no BD
    """
    print("Relatório de Grade Horária Individual\n")

    try:
        cursor.execute("""SELECT matricula_aluno, nome FROM aluno order by nome;""")
        alunos = cursor.fetchall()

        if not alunos:
            print("Nenhum aluno encontrado no sistema.")
            return

        for aluno in alunos:
            matricula = aluno[0]
            nome_aluno = aluno[1]
            print("\t - " * 10)
            print("\tGRADE HORÁRIA DO ALUNO => {} {}".format(matricula, nome_aluno))
            print("\t - " * 10)
            print("{:<30} {:<15} {:<10} {:<10}".format('Disciplina', 'Dia da Semana', 'Início', 'Fim'))

            cursor.execute("""
                SELECT nome_disciplina, dia_semana, horario_ini, horario_fim
                FROM visualizar_grade_horaria(%s);
            """, (matricula,))
            grade = cursor.fetchall()

            if not grade:
                print("Nenhuma disciplina matriculada.")
            else:
                for nome, dia, ini, fim in grade:
                    print("{:<30} {:<15} {:<10} {:<10}".format(nome, dia, str(ini), str(fim)))

            print("\t - " * 10)
            print()

    except pg.Error as e:
        print(f"Erro ao gerar o relatório: {e}")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

def main():

    """
    Essa é a função principal do nosso programa, onde ocorre o chamamento de todas as 
    funções definidas acima, realiza a conexao com o banco utilizando as funçoes definidas
    no connect.py
    E utiliza os dados aleatórios gerados no arquivo populando_faker.py
    """

    conexao = conn()

    cursor = conexao.cursor()

    # executando um select
    cursor.execute("SELECT current_database();")

    # atribuindo o resultado do select a uma variavel
    rows = cursor.fetchone()

    # Exibindo a qual banco de dados estamos conectados
    print("Conectado ao Banco de Dados: ", rows[0])
    

    if povoar (cursor, "aluno"):
        print("O banco de dados está vazio, vamos iniciar a povoa-lo")
        print("Gerando Dados Aleatorios")
        alunos, disciplinas, prerequisitos, turmas, horarios, matriculas, historico = gerar_dados_aleatorios()
        print("Dados gerados com sucesso")
        print("Inserindo dados aleatórios!")
        inserir_dados(conexao, alunos, disciplinas, prerequisitos,
                  turmas, horarios, matriculas, historico)
    else:
        print("\nO Banco de Dados já contém dados!")
        print("O povoamento do Banco de Dados foi pulado!")
        print("- " * 50)
        print()
        
    num = -1

    while num != 0:
        print("\t---" * 10)
        print("\t\t\t\t\tMenu de Opções")
        print("\t---" * 10)
        print("\t1 - Cadastrar novo aluno")
        print("\t2 - Matricula em Turma")
        print("\t3 - Mostrar disciplinas recomendadas para matricula")
        print("\t4 - Apresentar grade horária simulada atual")
        print("\t5 - Relatórios")
        print("\t0 - Encerrar programa")
        print("\t---" * 10)
        print()
        
        num = int(input("Digite a opção desejada: "))
        print()

        if num == 1:
            inserir_novo_aluno(cursor, conexao)
            print("- "*50)
        
        elif num == 2:
            fazer_matricula(cursor, conexao)
            print("- "*50)

        elif num == 3:
            disciplinas_recomendadas(cursor)
        elif num == 4:
            grade_horaria_simulada(cursor)
        elif num == 5:
            while True:
                print("\t---" * 10)
                print("\t\t\t\t\tRELATÓRIOS")
                print("\t---" * 10)
                print("\tA - Relatório de alunos matriculados em determinada turma")
                print("\tB - Relatório sobre a grade horária individual de cada aluno")
                print("\tC - Relatório sobre as disciplinas mais e menos procuradas")
                print("\tD - Relatório sobre as disciplinas com maior indice de reprovação")
                print("\tE - Relatórios dos alunos aptos para TCC e/ou Estágio")
                print("\t0 - Voltar")
                print("\t---" * 10)
                print()

                opcao = input("Digite a opção desejada: ").upper()
                print()

                if(opcao == 'A'):
                    relatorio_alunos_por_turma(cursor)
                elif(opcao == 'B'):
                    relatorio_grade_horaria_individual(cursor)
                elif(opcao == 'C'):
                    disciplinas_mais_menos_procuradas(cursor)
                elif(opcao == 'D'):
                    print("Será implementado em reseases futuras!")
                    print()
                    break
                elif(opcao == 'E'):
                    relatorio_alunos_aptos_estagio_tcc(cursor)
                elif(opcao == '0'):
                    print("Opção escolhida foi voltar")
                    print()
                    break
                else:
                    print("Opção inválida")
        elif num == 0:
            print("Encerrando a conexão")
            encerra_conn(conexao)
        else:
            print("Opção inválida, digite novamente...")

if __name__ == "__main__":
    main()
