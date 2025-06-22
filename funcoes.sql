-- Verificar pré-requisitos cumpridos
CREATE OR REPLACE FUNCTION verificar_pre_requisitos(
    p_matricula_aluno varchar,
    p_codigo_disciplina varchar
)
RETURNS TABLE(codigo_disciplina_pre_requisito varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT pr.codigo_disciplina_pre_requisito
    FROM pre_requisitos pr
    LEFT JOIN historico_escolar h 
      ON pr.codigo_disciplina_pre_requisito = h.codigo_disciplina
      AND h.matricula_aluno = p_matricula_aluno
      AND h.situacao = 'aprovado'
    WHERE pr.codigo_disciplina_principal = p_codigo_disciplina
      AND h.codigo_disciplina IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Verificar conflito de horário
CREATE OR REPLACE FUNCTION verificar_conflito_horario(
    p_matricula_aluno varchar,
    p_id_turma integer
)
RETURNS boolean AS $$
DECLARE
    v_exists int;
BEGIN
    SELECT 1 INTO v_exists
    FROM matricula m
    JOIN horarios h1 ON m.id_turma = h1.id_turma
    JOIN horarios h2 ON h2.id_turma = p_id_turma
    WHERE m.matricula_aluno = p_matricula_aluno
      AND h1.dia_semana = h2.dia_semana
      AND h1.horario_ini < h2.horario_fim
      AND h1.horario_fim > h2.horario_ini
    LIMIT 1;

    RETURN v_exists IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Verificar se a turma está cheia
CREATE OR REPLACE FUNCTION turma_esta_cheia(
    p_id_turma integer
)
RETURNS boolean AS $$
DECLARE
    v_total_matriculados int;
    v_capacidade int;
BEGIN
    SELECT COUNT(*) INTO v_total_matriculados FROM matricula WHERE id_turma = p_id_turma;
    SELECT capacidade_maxima INTO v_capacidade FROM turmas WHERE id_turma = p_id_turma;

    RETURN v_total_matriculados >= v_capacidade;
END;
$$ LANGUAGE plpgsql;

-- Visualizar grade horária do aluno
CREATE OR REPLACE FUNCTION visualizar_grade_horaria(
    p_matricula_aluno varchar
)
RETURNS TABLE(nome_disciplina varchar, dia_semana varchar, horario_ini time, horario_fim time) AS $$
BEGIN
    RETURN QUERY
    SELECT d.nome, h.dia_semana, h.horario_ini, h.horario_fim
    FROM matricula m
    JOIN turmas t ON m.id_turma = t.id_turma
    JOIN disciplina d ON t.codigo_disciplina = d.codigo_disciplina
    JOIN horarios h ON h.id_turma = t.id_turma
    WHERE m.matricula_aluno = p_matricula_aluno;
END;
$$ LANGUAGE plpgsql;

-- Nomes de todos os alunos da turma
CREATE OR REPLACE FUNCTION alunos_da_turma(
    p_id_turma integer
)
RETURNS TABLE(nome_aluno varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT a.nome
    FROM matricula m
    JOIN aluno a ON m.matricula_aluno = a.matricula_aluno
    WHERE m.id_turma = p_id_turma
    ORDER BY a.nome;
END;
$$ LANGUAGE plpgsql;

-- Disciplina mais e menos procurada
CREATE OR REPLACE FUNCTION disciplinas_procuradas()
RETURNS TABLE(nome_disciplina varchar, total_matriculas int) AS $$
BEGIN
    RETURN QUERY
    SELECT d.nome, COUNT(*) AS total_matriculas
    FROM matricula m
    JOIN turmas t ON m.id_turma = t.id_turma
    JOIN disciplina d ON t.codigo_disciplina = d.codigo_disciplina
    GROUP BY d.nome
    ORDER BY total_matriculas DESC;
END;
$$ LANGUAGE plpgsql;

-- Alunos aptos a TCC ou estágio (carga horária mínima)
CREATE OR REPLACE FUNCTION alunos_aptos_estagio(
    p_carga_minima int
)
RETURNS TABLE(matricula_aluno varchar, nome_aluno varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT a.matricula_aluno, a.nome
    FROM aluno a
    JOIN historico_escolar h ON a.matricula_aluno = h.matricula_aluno
    JOIN disciplina d ON h.codigo_disciplina = d.codigo_disciplina
    WHERE h.situacao = 'Aprovado'
    GROUP BY a.matricula_aluno, a.nome
    HAVING SUM(d.carga_horaria_total) >= p_carga_minima;
END;
$$ LANGUAGE plpgsql;

-- Disciplinas não cursadas ou reprovadas pelo aluno
CREATE OR REPLACE FUNCTION disciplinas_nao_cursadas_ou_reprovadas(
    p_matricula_aluno varchar
)
RETURNS TABLE(codigo_disciplina varchar, nome_disciplina varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT d.codigo_disciplina, d.nome
    FROM disciplina d
    WHERE d.codigo_disciplina NOT IN (
        SELECT codigo_disciplina
        FROM historico_escolar
        WHERE matricula_aluno = p_matricula_aluno
          AND situacao = 'Aprovado'
    );
END;
$$ LANGUAGE plpgsql;