import psycopg2 as pg
from psycopg2 import Error
from faker import Faker
import random
from datetime import time, datetime

from connect import conn, encerra_conn

fake = Faker('pt-BR')


def gerar_dados_aleatorios(num_alunos=50, num_disciplinas=20, num_turmas_disciplinas=2):
    # criando um vetor para armazenar os valores que serão inseridos em alunos
    alunos_dados = []

    for i in range(num_alunos):
        # gerando um número aleatório de 7 digitos
        matricula = str(random.randint(1000000, 10000000 - 1))
        nome = fake.name()
        curso = random.choice(['Engenharia de Software', 'Ciencia da Computacao',
                              'Sistemas de Informacao', 'Engenharia da Computacao'])
        periodo = random.randint(1, 10)
        carga_max = random.choice([16, 20, 24, 28, 32])
        alunos_dados.append((matricula, nome, curso, periodo, carga_max))

    # armazenar os dados das disciplinas
    disciplinas_dados = []
    # criacao de um vetor auxiliar para guardar os codigos das disciplinas, pois eles são FK de outras tabelas
    codigos_disciplinas = []

    for i in range(num_disciplinas):
        # escolhendo 4 letras e concatenando com um numero aleatorio de 3 digitos
        letras = "".join(random.choices("ABCDEFGHIJKLMNOPQRSTUVWXYZ", k=4))
        numeros = str(random.randint(100, 999))
        codigo = letras + numeros

        # pegando uma carga horaria aleatoria
        carga_horaria = random.choice([32, 64, 102, 271])

        # gerando um nome aleatorio
        nome = random.choice(["Introducao a ", "Fundamentos em ", "Topicos em ",
                             "Desenvolvimento em "]) + fake.word() + random.choice(["I", "II", "III", ""])
        disciplinas_dados.append((codigo, nome, carga_horaria))
        codigos_disciplinas.append(codigo)

    # criação de um vetor para armazenar os pre requisitos
    pre_requisitos_dados = []

    # Verificar se temos mais de uma disciplina
    if len(codigos_disciplinas) >= 2:
        for i in range(num_disciplinas):
            disciplina_principal = random.choice(codigos_disciplinas)
            disciplina_pre_requisito = random.choice(codigos_disciplinas)
            # evita que uma disciplina seja prerequisito de si mesma
            if disciplina_principal != disciplina_pre_requisito:
                pre_requisitos_dados.append(
                    (disciplina_principal, disciplina_pre_requisito))

    turmas_dados = []
    horarios_dados = []
    matriculas_dados = []
    historico_dados = []

    # contador para gerar os ids das turmas
    turma_id = 1000

    for codigo in codigos_disciplinas:
        for i in range(num_turmas_disciplinas):
            semestre = random.choice(["2025.1", "2025.2"])
            professor = fake.name()
            turno = random.choice(["Manha", "Tarde", "Noite"])
            local = random.choice(
                ["Sala " + str(random.randint(1, 5)), "Laboratorio " + str(random.randint(1, 5))])
            capacidade = random.choice([24, 50, 70])

            turmas_dados.append(
                (turma_id, codigo, semestre, turno, local, capacidade, professor))

            qtd_aulas = random.randint(1, 3)
            dia_semana = random.sample(
                ["Segunda", "Terca", "Quarta", "Quinta", "Sexta"], qtd_aulas)

            for dia in dia_semana:
                hora_ini = time(random.randint(7, 20), 0)
                hora_fim = time(hora_ini.hour + random.randint(1, 2), 0)
                horarios_dados.append((turma_id, dia, hora_ini, hora_fim))

            alunos_turma = random.randint(5, min(capacidade, num_alunos))
            matricula_alunos = random.sample(alunos_dados, alunos_turma)

            for aluno, i, j, k, l in matricula_alunos:
                status_matricula = random.choice(["Ativa", "Pendente"])
                matriculas_dados.append((aluno, turma_id, status_matricula))

            turma_id += 1

            # falta implementar o historico
    for aluno, i, j, k, l in alunos_dados:
        num_disciplinas_cursadas = random.randint(
            0, min(5, len(codigos_disciplinas)))
        disciplinas_cursadas = random.sample(
            codigos_disciplinas, num_disciplinas_cursadas)
        for disciplina in disciplinas_cursadas:
            nota = round(random.uniform(0.0, 10.0), 2)
            frequencia = round(random.uniform(50.0, 100.0), 2)
            if nota >= 6.0 and frequencia >= 75.0:
                situacao = "Aprovado"
            else:
                situacao = "Reprovado"
            historico_dados.append(
                (aluno, disciplina, nota, frequencia, situacao))

    return alunos_dados, disciplinas_dados, pre_requisitos_dados, turmas_dados, horarios_dados, matriculas_dados, historico_dados


def inserir_dados(conexao, alunos_dados, disciplinas_dados, pre_requisitos_dados, turmas_dados, horarios_dados, matriculas_dados, historico_dados):
    if conexao is None:
        print("Não foi possível inserir dados")
        return

    cursor = conexao.cursor()

    try:
        cursor.executemany("""
            insert into aluno (matricula_aluno, nome, curso, periodo_atual, carga_horaria_maxima)
            values (%s, %s, %s, %s, %s) ON conflict (matricula_aluno) do nothing; """, alunos_dados)

        cursor.executemany(""" 
            insert into disciplina (codigo_disciplina, nome, carga_horaria_total) values (%s, %s, %s) ON conflict (codigo_disciplina) do nothing""", disciplinas_dados)

        for pre in pre_requisitos_dados:
            try:
                cursor.execute("""
                insert into  pre_requisitos (codigo_disciplina_principal, codigo_disciplina_pre_requisito)
                values (%s, %s) ON conflict (codigo_disciplina_principal, codigo_disciplina_pre_requisito) do nothing; """, pre)
            except pg.IntegrityError as e:
                conexao.rollback()
                cursor = conexao.cursor()
                pass

        cursor.executemany("""
            insert into turmas (id_turma, codigo_disciplina, semestre, turno, local, capacidade_maxima, professor)
            values (%s, %s, %s, %s, %s, %s, %s) ON conflict (id_turma) do nothing; """, turmas_dados)

        for hora in horarios_dados:
            try:
                cursor.execute("""
                    insert into horarios (id_turma, dia_semana, horario_ini, horario_fim)
                    values (%s, %s, %s, %s) ON conflict (id_turma, dia_semana, horario_ini) do nothing; """, hora)
            except pg.IntegrityError as e:
                conexao.rollback()
                cursor = conexao.cursor()
                pass

        for matricula in matriculas_dados:
            try:
                cursor.execute("""
                    insert into matricula (matricula_aluno, id_turma, status)
                    values (%s, %s, %s) ON conflict (matricula_aluno, id_turma) do nothing; """, matricula)
            except pg.IntegrityError as e:
                conexao.rollback()
                cursor = conexao.cursor()
                pass

        for historico in historico_dados:
            try:
                cursor.execute("""
                    insert into historico_escolar (matricula_aluno, codigo_disciplina, nota, frequencia, situacao)
                    values (%s, %s, %s, %s, %s) ON conflict (matricula_aluno, codigo_disciplina) do nothing; """, historico)
            except pg.IntegrityError as e:
                conexao.rollback()
                cursor = conexao.cursor()
                pass

        conexao.commit()
        print("Dados Falsos Inseridos com Sucesso!")

    except Error as e:
        print(f"Erro a inserir dados falsos: {e}")
        conexao.rollback()
    finally:
        if cursor:
            cursor.close()
