import psycopg2 as pg
from psycopg2 import Error


def conn():
    try:
        conecta = pg.connect(

            user="postgres",
            password="minhasenha",
            host="localhost",
            port="5433",
            database="sistemaEscolar",)

        print("\nConexao com o Banco de Dados bem sucedida\n")
        return conecta
    except Error as e:
        print("\nFalha em se conectar ao banco de dados\n")


def encerra_conn(conecta):
    if conecta:
        conecta.close()
        print("\nConexao ao Postgres encerrada")
        print()
