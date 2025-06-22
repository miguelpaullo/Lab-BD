import psycopg2 as pg
from psycopg2 import Error
from connect import conn, encerra_conn
from populando_faker import gerar_dados_aleatorios, inserir_dados

def verificar_matricula (cursor, matricula_aluno):
    try:

        mat = "select COUNT(*) from aluno where matricula_aluno = %s;"
        cursor.execute(mat, (matricula_aluno,))
        valor = cursor.fetchone()[0]
        return valor > 0

    except pg.Error as e:
        print(f"Erro ao verificar matricula: {e}")
        return False

def verificar_disciplina(cursor, codigo_disciplina):

    try:

        disc = "select COUNT(*) from disciplina where codigo_disciplina = %s;"
        cursor.execute(disc, (codigo_disciplina,))
        valor = cursor.fetchone()[0]
        return valor > 0

    except pg.Error as e:
        print(f"Erro ao verificar disciplina: {e}")
        return False

def verificar_pre_requisitos(cursor, matricula_aluno, codigo_disciplina):
    try:
        cursor.execute("""select codigo_disciplina_pre_requisito from verificar_pre_requisitos(%s, %s);""", (matricula_aluno, codigo_disciplina))
        resultado = cursor.fetchall()
        pre_requisito = [linha[0] for linha in resultado]
        return [linha[0] for linha in resultado]
    except pg.Error as e:
        print(f"Erro ao verificar pré-requisitos: {e}")
        return []

def verificar_horarios (cursor, matrcicula_aluno, id_turma):
    try:
        cursor.execute("""select verificar_conflito_horario(%s, %s);""", (matrcicula_aluno, id_turma))
        conflito_existe = cursor.fetchone()[0]
        return conflito_existe
    except pg.Error as e:
        print(f"Erro ao verificar conflito de horários: {e}")
        return True

def verificar_turma(cursor, id_turma):
    try:
        cursor.execute("""select turma_esta_cheia(%s);""", (id_turma,))
        turma_cheia = cursor.fetchone()[0]
        return turma_cheia
    except pg.Error as e:
        print(f"Erro ao verificar disponibilidade em turma: {e}")
        return True

def fazer_matricula(cursor, conexao):
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
    
    nome = "\nDigite o nome completo do aluno: ".strip()
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

def main():

    conexao = conn()

    cursor = conexao.cursor()

    # executando um select
    cursor.execute("SELECT current_database();")

    # atribuindo o resultado do select a uma variavel
    rows = cursor.fetchone()

    # Exibindo a qual banco de dados estamos conectados
    print("Conectado ao Banco de Dados: ", rows[0])
    print()


    #Gerando e Inserindo os Dados Aleatórios
    ###########################################################################################################
    """

    print("Gerando Dados Aleatorios")

    alunos, disciplinas, prerequisitos, turmas, horarios, matriculas, historico = gerar_dados_aleatorios()

    print("\nInserindo dados\n")

    inserir_dados(conexao, alunos, disciplinas, prerequisitos,
                  turmas, horarios, matriculas, historico)
    
    """
    ############################################################################################################
    num = -1

    while num != 0:
        print("\tMenu de Opções")
        print("\t--" * 10)
        print("\t1 - Cadastrar novo aluno")
        print("\t2 - Matricula em Turma")
        print("\t3 - Mostrar disciplinas recomendadas para matricula")
        print("\t4 - Apresentar grade horária simulada atual")
        print("\t5 - Relatórios")
        print("\t0 - Encerrar programa")
        print("\t--" * 10)
        print()
        
        num = int(input("Digite a opção desejada: "))
        print()

        if num == 1:
            inserir_novo_aluno(cursor, conexao)
            print("-"*10)
        
        elif num == 2:
            fazer_matricula(cursor, conexao)
            print("-"*10)

        elif num == 3:
            print("Mostrando suas disciplinas recomendadas")
        elif num == 4:
            print("Sua grade simulada")
        elif num == 5:
            while True:
                print("\tRELATÓRIOS")
                print("\t--" * 10)
                print("\tA - Relatório de alunos matriculados em determinada turma")
                print("\tB - Relatório sobre a grade horária individual de cada aluno")
                print("\tC - Relatório sobre as disciplinas mais e menos procuradas")
                print("\tD - Relatório sobre as disciplinas com maior indice de reprovação")
                print("\tE - Relatórios dos alunos aptos para TCC ou Estágio")
                print("\t0 - Voltar")
                print("\t--" * 10)
                print()

                opcao = input("Digite a opção desejada: ").upper()
                print()

                if(opcao == 'A'):
                    print("Opção escolhida foi A")
                elif(opcao == 'B'):
                    print("Opção escolhida foi B")
                elif(opcao == 'C'):
                    print("Opção escolhida foi C")
                elif(opcao == 'D'):
                    print("Opção escolhida foi D")
                elif(opcao == 'E'):
                    print("Opção escolhida foi E")
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

    # exibindo o resultado, teriamos que usar fetchall()
    # for row in rows:
    # print(row)

if __name__ == "__main__":
    main()
