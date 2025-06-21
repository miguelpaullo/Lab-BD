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
        print("Erro ao verificar matricula")
        return False

def verificar_disciplina(cursor, codigo_disciplina):

    try:

        disc = "select COUNT(*) from disciplina where codigo_disciplina = %s;"
        cursor.execute(disc, (codigo_disciplina,))
        valor = cursor.fetchone()[0]
        return valor > 0

    except pg.Error as e:
        print("Erro ao verificar disciplina")
        return False

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
        print("\t------------------------------------------------------------")
        print("\t1 - Matricula em Turma")
        print("\t2 - Mostrar disciplinas recomendadas para matricula")
        print("\t3 - Apresentar grade horária simulada atual")
        print("\t4 - Relatórios")
        print("\t0 - Encerrar programa")
        print("\t------------------------------------------------------------")
        print()
        
        num = int(input("Digite a opção desejada: "))
        print()

        if num == 1:
            print("Vamos realizar sua matricula simulada\n")
            print("Primeiro vamos verificar se a disciplina escolhida tem pré-requisitos!\n")
            print("Por favor, digite a matricula do aluno: (ex.: 9999999)\n")
            rga = input().strip()
            while True:
                if verificar_matricula(cursor, rga):
                    print("\nMatricula válida!")
                    break
                else:
                    print("A matricula não existe, digite novamente...")
                    rga = input().strip()
            
            print("\nPor favor, dgite o codigo da disciplina: (ex.: ABCD123)")
            cod = input().strip()
            while True:
                if verificar_disciplina(cursor, cod):
                    print("\nCódigo de disciplina válido")
                    break
                else:
                    print("Código de disciplina inválido, digite novamente...")
                    cod = input().strip()
            
            try:
                cursor.execute("""select codigo_disciplina_pre_requisito from verificar_pre_requisitos(%s, %s);""", (rga, cod))
                resultado = cursor.fetchall()
                pre_requisito = [linha[0] for linha in resultado]

                if not pre_requisito:
                    print("O aluno cumpriu todos os pré-requisitos para a disciplina informada")
                    return True
                else:
                    print("O aluno tem pré-requisitos a cursar antes da disciplina informada")
                    for pre in pre_requisito:
                        print("- {}".format(pre))
                    return False
            except pg.Error as e:
                print("Erro ao verificar pré-requititos")
                return []
        elif num == 2:
            print("Mostrando suas disciplinas recomendadas")
        elif num == 3:
            print("Sua grade simulada")
        elif num == 4:
            while True:
                print("\tRELATÓRIOS")
                print("\t-------------------------------------------------------------------")
                print("\tA - Relatório de alunos matriculados em determinada turma")
                print("\tB - Relatório sobre a grade horária individual de cada aluno")
                print("\tC - Relatório sobre as disciplinas mais e menos procuradas")
                print("\tD - Relatório sobre as disciplinas com maior indice de reprovação")
                print("\tE - Relatórios dos alunos aptos para TCC ou Estágio")
                print("\t0 - Voltar")
                print("\t-------------------------------------------------------------------")
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
