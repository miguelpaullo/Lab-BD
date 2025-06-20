from connect import conn, encerra_conn
from populando_faker import gerar_dados_aleatorios, inserir_dados


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
            print("Vamos realizar sua matricula simulada")
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
