--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg120+1)
-- Dumped by pg_dump version 17.5 (Debian 17.5-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: alunos_aptos_estagio(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.alunos_aptos_estagio(p_carga_minima integer) RETURNS TABLE(matricula_aluno character varying, nome_aluno character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: alunos_da_turma(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.alunos_da_turma(p_id_turma integer) RETURNS TABLE(nome_aluno character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT a.nome
    FROM matricula m
    JOIN aluno a ON m.matricula_aluno = a.matricula_aluno
    WHERE m.id_turma = p_id_turma
    ORDER BY a.nome;
END;
$$;


--
-- Name: disciplinas_nao_cursadas_ou_reprovadas(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.disciplinas_nao_cursadas_ou_reprovadas(p_matricula_aluno character varying) RETURNS TABLE(codigo_disciplina character varying, nome_disciplina character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: disciplinas_procuradas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.disciplinas_procuradas() RETURNS TABLE(nome_disciplina character varying, total_matriculas integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT d.nome, COUNT(*)::int AS total_matriculas 
    FROM matricula m
    JOIN turmas t ON m.id_turma = t.id_turma
    JOIN disciplina d ON t.codigo_disciplina = d.codigo_disciplina
    GROUP BY d.nome
    ORDER BY total_matriculas DESC;
END;
$$;


--
-- Name: turma_esta_cheia(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.turma_esta_cheia(p_id_turma integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_matriculados int;
    v_capacidade int;
BEGIN
    SELECT COUNT(*) INTO v_total_matriculados FROM matricula WHERE id_turma = p_id_turma;
    SELECT capacidade_maxima INTO v_capacidade FROM turmas WHERE id_turma = p_id_turma;

    RETURN v_total_matriculados >= v_capacidade;
END;
$$;


--
-- Name: verificar_conflito_horario(character varying, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_conflito_horario(p_matricula_aluno character varying, p_id_turma integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: verificar_pre_requisitos(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_pre_requisitos(p_matricula_aluno character varying, p_codigo_disciplina character varying) RETURNS TABLE(codigo_disciplina_pre_requisito character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: visualizar_grade_horaria(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.visualizar_grade_horaria(p_matricula_aluno character varying) RETURNS TABLE(nome_disciplina character varying, dia_semana character varying, horario_ini time without time zone, horario_fim time without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT d.nome, h.dia_semana, h.horario_ini, h.horario_fim
    FROM matricula m
    JOIN turmas t ON m.id_turma = t.id_turma
    JOIN disciplina d ON t.codigo_disciplina = d.codigo_disciplina
    JOIN horarios h ON h.id_turma = t.id_turma
    WHERE m.matricula_aluno = p_matricula_aluno;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aluno; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aluno (
    matricula_aluno character varying(20) NOT NULL,
    nome character varying(100) NOT NULL,
    curso character varying(50) NOT NULL,
    periodo_atual integer,
    carga_horaria_maxima integer
);


--
-- Name: disciplina; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disciplina (
    codigo_disciplina character varying(10) NOT NULL,
    nome character varying(100) NOT NULL,
    carga_horaria_total integer NOT NULL
);


--
-- Name: historico_escolar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historico_escolar (
    matricula_aluno character varying(20) NOT NULL,
    codigo_disciplina character varying(10) NOT NULL,
    nota double precision,
    frequencia double precision,
    situacao character varying(20) NOT NULL
);


--
-- Name: horarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.horarios (
    id_turma integer NOT NULL,
    dia_semana character varying(20) NOT NULL,
    horario_ini time without time zone NOT NULL,
    horario_fim time without time zone NOT NULL
);


--
-- Name: matricula; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matricula (
    matricula_aluno character varying(20) NOT NULL,
    id_turma integer NOT NULL,
    status character varying(20) NOT NULL
);


--
-- Name: pre_requisitos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pre_requisitos (
    codigo_disciplina_principal character varying(10) NOT NULL,
    codigo_disciplina_pre_requisito character varying(10) NOT NULL
);


--
-- Name: turmas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.turmas (
    id_turma integer NOT NULL,
    codigo_disciplina character varying(10) NOT NULL,
    semestre character varying(10) NOT NULL,
    turno character varying(20),
    local character varying(50),
    capacidade_maxima integer NOT NULL,
    professor character varying(100) NOT NULL
);


--
-- Name: turmas_id_turma_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.turmas_id_turma_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: turmas_id_turma_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.turmas_id_turma_seq OWNED BY public.turmas.id_turma;


--
-- Name: turmas id_turma; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turmas ALTER COLUMN id_turma SET DEFAULT nextval('public.turmas_id_turma_seq'::regclass);


--
-- Data for Name: aluno; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.aluno VALUES ('4278413', 'EloÔö£├¡ Vieira', 'Ciencia da Computacao', 8, 20);
INSERT INTO public.aluno VALUES ('9651573', 'ThÔö£┬«o da Cunha', 'Ciencia da Computacao', 5, 24);
INSERT INTO public.aluno VALUES ('2987927', 'Davi Machado', 'Sistemas de Informacao', 2, 24);
INSERT INTO public.aluno VALUES ('9038731', 'Sra. Sara Vasconcelos', 'Sistemas de Informacao', 2, 20);
INSERT INTO public.aluno VALUES ('6065876', 'Emanuel Costela', 'Engenharia da Computacao', 2, 28);
INSERT INTO public.aluno VALUES ('2138666', 'Liam GonÔö£┬║alves', 'Engenharia de Software', 9, 20);
INSERT INTO public.aluno VALUES ('2410780', 'Leonardo Cirino', 'Engenharia de Software', 7, 24);
INSERT INTO public.aluno VALUES ('2196096', 'Daniel da Costa', 'Sistemas de Informacao', 4, 32);
INSERT INTO public.aluno VALUES ('6128786', 'Calebe Barros', 'Sistemas de Informacao', 5, 28);
INSERT INTO public.aluno VALUES ('3900630', 'Caleb Ribeiro', 'Ciencia da Computacao', 10, 32);
INSERT INTO public.aluno VALUES ('8207648', 'Dra. Giovanna FogaÔö£┬║a', 'Engenharia da Computacao', 2, 32);
INSERT INTO public.aluno VALUES ('3973638', 'Paulo Monteiro', 'Engenharia de Software', 4, 20);
INSERT INTO public.aluno VALUES ('7838240', 'Carolina Porto', 'Ciencia da Computacao', 3, 20);
INSERT INTO public.aluno VALUES ('2485594', 'Ravi Lucca Vargas', 'Ciencia da Computacao', 6, 16);
INSERT INTO public.aluno VALUES ('5398987', 'Pietra Monteiro', 'Engenharia de Software', 1, 32);
INSERT INTO public.aluno VALUES ('6908973', 'Vicente Nunes', 'Ciencia da Computacao', 10, 32);
INSERT INTO public.aluno VALUES ('6644653', 'Valentina Alves', 'Sistemas de Informacao', 1, 16);
INSERT INTO public.aluno VALUES ('3369041', 'Ana VitÔö£Ôöéria Abreu', 'Ciencia da Computacao', 6, 32);
INSERT INTO public.aluno VALUES ('1737678', 'Dra. Maria da Mota', 'Engenharia da Computacao', 3, 20);
INSERT INTO public.aluno VALUES ('2890489', 'Anna Liz Camargo', 'Engenharia da Computacao', 7, 16);
INSERT INTO public.aluno VALUES ('1160773', 'Joana Viana', 'Ciencia da Computacao', 7, 24);
INSERT INTO public.aluno VALUES ('7505126', 'Gustavo Moreira', 'Sistemas de Informacao', 1, 16);
INSERT INTO public.aluno VALUES ('2315919', 'Pedro Lopes', 'Sistemas de Informacao', 6, 28);
INSERT INTO public.aluno VALUES ('2781909', 'Leonardo Sampaio', 'Engenharia da Computacao', 5, 24);
INSERT INTO public.aluno VALUES ('4110382', 'Ravy CÔö£├│mara', 'Engenharia da Computacao', 7, 28);
INSERT INTO public.aluno VALUES ('6738608', 'Luna Freitas', 'Engenharia de Software', 2, 32);
INSERT INTO public.aluno VALUES ('4502368', 'Maria JÔö£Ôòælia Freitas', 'Sistemas de Informacao', 2, 28);
INSERT INTO public.aluno VALUES ('7199006', 'Marcelo Silva', 'Sistemas de Informacao', 7, 20);
INSERT INTO public.aluno VALUES ('8828137', 'Helena Carvalho', 'Ciencia da Computacao', 8, 16);
INSERT INTO public.aluno VALUES ('7084419', 'Daniel Moura', 'Engenharia de Software', 9, 32);
INSERT INTO public.aluno VALUES ('6221665', 'Maya Alves', 'Engenharia de Software', 9, 28);
INSERT INTO public.aluno VALUES ('9902354', 'Ôö£├¼sis Oliveira', 'Ciencia da Computacao', 8, 20);
INSERT INTO public.aluno VALUES ('8236098', 'Sarah da Paz', 'Ciencia da Computacao', 6, 20);
INSERT INTO public.aluno VALUES ('8338607', 'Maria LuÔö£┬ísa GonÔö£┬║alves', 'Engenharia da Computacao', 4, 32);
INSERT INTO public.aluno VALUES ('9687726', 'Yan da Costa', 'Engenharia da Computacao', 8, 28);
INSERT INTO public.aluno VALUES ('9766553', 'Dr. Vinicius Machado', 'Engenharia de Software', 5, 20);
INSERT INTO public.aluno VALUES ('6256480', 'Catarina Silva', 'Ciencia da Computacao', 1, 20);
INSERT INTO public.aluno VALUES ('2637706', 'Dra. Mariah GonÔö£┬║alves', 'Engenharia da Computacao', 6, 20);
INSERT INTO public.aluno VALUES ('9004880', 'Maria Laura Cavalcante', 'Engenharia de Software', 7, 16);
INSERT INTO public.aluno VALUES ('3012871', 'Kamilly da Rocha', 'Ciencia da Computacao', 10, 28);
INSERT INTO public.aluno VALUES ('7905686', 'Dra. CecÔö£┬ília Moraes', 'Sistemas de Informacao', 5, 28);
INSERT INTO public.aluno VALUES ('5156042', 'Rael Souza', 'Ciencia da Computacao', 5, 28);
INSERT INTO public.aluno VALUES ('2373756', 'EloÔö£├¡ Campos', 'Engenharia da Computacao', 8, 20);
INSERT INTO public.aluno VALUES ('5926464', 'Maria Alice Caldeira', 'Ciencia da Computacao', 1, 24);
INSERT INTO public.aluno VALUES ('2741817', 'Sr. Bento Nogueira', 'Engenharia da Computacao', 9, 20);
INSERT INTO public.aluno VALUES ('3393269', 'Dr. LÔö£┬«o Aparecida', 'Sistemas de Informacao', 5, 32);
INSERT INTO public.aluno VALUES ('5415276', 'Dr. JoÔö£├║o Miguel da Costa', 'Sistemas de Informacao', 3, 28);
INSERT INTO public.aluno VALUES ('7533052', 'Dra. Allana Moreira', 'Ciencia da Computacao', 10, 16);
INSERT INTO public.aluno VALUES ('2523873', 'Maria Liz Freitas', 'Engenharia da Computacao', 8, 20);
INSERT INTO public.aluno VALUES ('6651646', 'Dra. Ana VitÔö£Ôöéria da Paz', 'Sistemas de Informacao', 4, 28);
INSERT INTO public.aluno VALUES ('2024190', 'Digite o nome completo do aluno:', 'Engenharia de Software', 5, 50);
INSERT INTO public.aluno VALUES ('2025190', 'Miguel Paulo Rodrigues', 'Ciencia da Computacao', 5, 40);


--
-- Data for Name: disciplina; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.disciplina VALUES ('JIJD423', 'Desenvolvimento em atqueII', 32);
INSERT INTO public.disciplina VALUES ('WYFW213', 'Fundamentos em esse', 32);
INSERT INTO public.disciplina VALUES ('RKKT348', 'Topicos em occaecatiIII', 102);
INSERT INTO public.disciplina VALUES ('WJXO924', 'Fundamentos em culpaIII', 32);
INSERT INTO public.disciplina VALUES ('ONAY724', 'Introducao a culpaI', 64);
INSERT INTO public.disciplina VALUES ('ZHZX546', 'Topicos em vel', 102);
INSERT INTO public.disciplina VALUES ('NOUT250', 'Desenvolvimento em quosI', 64);
INSERT INTO public.disciplina VALUES ('OJAE495', 'Desenvolvimento em estII', 271);
INSERT INTO public.disciplina VALUES ('FKNA475', 'Desenvolvimento em aut', 64);
INSERT INTO public.disciplina VALUES ('LSEV313', 'Topicos em quaeIII', 64);
INSERT INTO public.disciplina VALUES ('JLKK128', 'Desenvolvimento em quiIII', 64);
INSERT INTO public.disciplina VALUES ('UAYQ942', 'Topicos em eveniet', 32);
INSERT INTO public.disciplina VALUES ('ZBFT202', 'Introducao a fugaII', 102);
INSERT INTO public.disciplina VALUES ('IOIB247', 'Topicos em eaque', 102);
INSERT INTO public.disciplina VALUES ('FKLF581', 'Fundamentos em perspiciatisII', 32);
INSERT INTO public.disciplina VALUES ('CAJC396', 'Introducao a officiisI', 271);
INSERT INTO public.disciplina VALUES ('JRZI625', 'Introducao a abII', 64);
INSERT INTO public.disciplina VALUES ('KFAS933', 'Fundamentos em optioII', 102);
INSERT INTO public.disciplina VALUES ('COYP966', 'Topicos em idI', 102);
INSERT INTO public.disciplina VALUES ('ITWB921', 'Fundamentos em dictaIII', 32);


--
-- Data for Name: historico_escolar; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.historico_escolar VALUES ('4278413', 'ONAY724', 8.96, 61.32, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('4278413', 'WYFW213', 1.49, 76.27, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('4278413', 'CAJC396', 3.04, 53.33, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('4278413', 'ZBFT202', 6.64, 60.53, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9651573', 'JLKK128', 2.45, 83.55, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9651573', 'IOIB247', 7.99, 53.1, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9651573', 'FKNA475', 2.79, 86.69, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2987927', 'LSEV313', 0.85, 82.74, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2987927', 'ZHZX546', 9.86, 89.34, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('2987927', 'UAYQ942', 9.48, 95.3, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('9038731', 'UAYQ942', 6.09, 92.9, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('6065876', 'NOUT250', 6.35, 87.56, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('6065876', 'WYFW213', 0.33, 72.46, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6065876', 'IOIB247', 1.88, 65.81, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6065876', 'JRZI625', 2.7, 54.92, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2410780', 'CAJC396', 0.49, 69.66, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2410780', 'KFAS933', 5.84, 91.95, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2410780', 'ZBFT202', 3.26, 80.14, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2410780', 'LSEV313', 2.23, 81.39, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2410780', 'NOUT250', 2.69, 52.63, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6128786', 'UAYQ942', 6.11, 77.08, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('6128786', 'LSEV313', 4.34, 80.65, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6128786', 'KFAS933', 9.51, 63.89, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3900630', 'ITWB921', 6.27, 80.92, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('8207648', 'KFAS933', 2.01, 83.32, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8207648', 'OJAE495', 2.65, 71.9, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8207648', 'FKNA475', 8.98, 56.23, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8207648', 'LSEV313', 6.27, 79.51, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('3973638', 'OJAE495', 3.55, 93.84, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3973638', 'UAYQ942', 3.11, 96.78, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3973638', 'KFAS933', 0.65, 96.79, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3973638', 'FKNA475', 5.53, 56.42, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7838240', 'JIJD423', 0.04, 78.78, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2485594', 'JLKK128', 6.41, 88.19, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('2485594', 'RKKT348', 9.02, 62.99, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2485594', 'LSEV313', 4.98, 81.62, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2485594', 'COYP966', 8.2, 65.81, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6908973', 'ONAY724', 0.18, 74.78, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6908973', 'WYFW213', 5.64, 74.47, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6908973', 'ITWB921', 0.44, 62.94, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6908973', 'ZBFT202', 6.26, 59.37, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6644653', 'JIJD423', 3.45, 53.08, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6644653', 'UAYQ942', 3.42, 68.5, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6644653', 'RKKT348', 7.54, 69.38, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3369041', 'ZHZX546', 6.19, 97.21, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('2890489', 'JIJD423', 2.96, 90.55, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2890489', 'JLKK128', 4.73, 95.02, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7505126', 'JLKK128', 1.79, 72.18, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2315919', 'JIJD423', 6.14, 57.21, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2315919', 'KFAS933', 7.45, 68.51, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2315919', 'RKKT348', 3.31, 68.4, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2315919', 'CAJC396', 8.23, 65.78, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2315919', 'IOIB247', 1.41, 58.51, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2781909', 'UAYQ942', 3.92, 77.65, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2781909', 'ZBFT202', 9, 71.76, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2781909', 'NOUT250', 4.69, 68.89, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2781909', 'RKKT348', 6.99, 72.71, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('4110382', 'ZBFT202', 6.44, 53.95, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('4110382', 'CAJC396', 0.83, 68.9, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6738608', 'IOIB247', 2.91, 85.34, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6738608', 'WJXO924', 2.22, 56.6, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6738608', 'COYP966', 6.97, 71.48, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6738608', 'FKLF581', 3.32, 58.29, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6738608', 'WYFW213', 6.29, 88.41, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('4502368', 'JLKK128', 8.73, 76.95, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('4502368', 'CAJC396', 7.62, 92.69, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('4502368', 'FKLF581', 1.69, 79.8, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7199006', 'JRZI625', 1.82, 98.87, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7199006', 'IOIB247', 8.5, 87.44, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('7199006', 'ITWB921', 9.42, 60.13, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7199006', 'WYFW213', 8.14, 81.69, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('7084419', 'JRZI625', 8.24, 88.57, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('7084419', 'CAJC396', 1.64, 84.36, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6221665', 'WJXO924', 8.81, 62.4, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6221665', 'ONAY724', 5.23, 56.87, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6221665', 'CAJC396', 1.54, 63.85, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6221665', 'WYFW213', 6.7, 72.77, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9902354', 'ZHZX546', 6.98, 79.2, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('9902354', 'WYFW213', 2.06, 74.18, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9902354', 'WJXO924', 9.93, 93.99, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('9902354', 'JIJD423', 9.22, 59.22, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9902354', 'COYP966', 7.77, 69.09, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8236098', 'IOIB247', 0.41, 87.2, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8236098', 'CAJC396', 5.84, 84.1, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('8338607', 'IOIB247', 9.09, 50.27, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9687726', 'OJAE495', 3.1, 96.63, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9687726', 'JRZI625', 7.48, 72.64, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9687726', 'ZHZX546', 2.02, 77.39, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9766553', 'ONAY724', 4.61, 88.05, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9766553', 'ZHZX546', 3.59, 59.92, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9766553', 'OJAE495', 4.15, 54.26, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6256480', 'FKLF581', 8.11, 51.47, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6256480', 'FKNA475', 0.6, 51.64, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6256480', 'ZBFT202', 4.94, 53.47, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2637706', 'IOIB247', 6.88, 75.59, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('2637706', 'WJXO924', 2.26, 91.22, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9004880', 'KFAS933', 1.33, 69.6, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('9004880', 'JLKK128', 5.88, 87.3, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2373756', 'JLKK128', 5.44, 76.04, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('5926464', 'ZHZX546', 0.81, 52.79, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2741817', 'CAJC396', 7.94, 58.34, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2741817', 'RKKT348', 0.17, 86.7, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2741817', 'ITWB921', 6, 83.76, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('2741817', 'NOUT250', 2.32, 81.95, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2741817', 'ONAY724', 8.31, 61.76, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('3393269', 'WJXO924', 9.68, 89.14, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('5415276', 'CAJC396', 7.1, 72.58, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('5415276', 'FKNA475', 4.56, 62.95, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('5415276', 'JIJD423', 8.33, 80.91, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('5415276', 'COYP966', 2.65, 83.63, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('5415276', 'OJAE495', 3.31, 98.41, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7533052', 'JLKK128', 9.29, 83.98, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('7533052', 'FKLF581', 3.93, 51.28, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('7533052', 'ITWB921', 6.63, 75.35, 'Aprovado');
INSERT INTO public.historico_escolar VALUES ('7533052', 'OJAE495', 4.96, 90.96, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('2523873', 'WJXO924', 3.89, 52.26, 'Reprovado');
INSERT INTO public.historico_escolar VALUES ('6651646', 'WYFW213', 7.74, 64.08, 'Reprovado');


--
-- Data for Name: horarios; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.horarios VALUES (1000, 'Quinta', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1001, 'Quinta', '10:00:00', '11:00:00');
INSERT INTO public.horarios VALUES (1001, 'Terca', '12:00:00', '13:00:00');
INSERT INTO public.horarios VALUES (1002, 'Sexta', '19:00:00', '20:00:00');
INSERT INTO public.horarios VALUES (1003, 'Segunda', '08:00:00', '09:00:00');
INSERT INTO public.horarios VALUES (1003, 'Quarta', '17:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1004, 'Quarta', '14:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1004, 'Terca', '15:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1004, 'Quinta', '16:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1005, 'Segunda', '20:00:00', '22:00:00');
INSERT INTO public.horarios VALUES (1006, 'Quarta', '14:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1006, 'Terca', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1006, 'Quinta', '09:00:00', '10:00:00');
INSERT INTO public.horarios VALUES (1007, 'Terca', '17:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1007, 'Quinta', '17:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1007, 'Segunda', '09:00:00', '10:00:00');
INSERT INTO public.horarios VALUES (1008, 'Terca', '16:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1009, 'Quinta', '15:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1009, 'Sexta', '12:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1010, 'Quinta', '08:00:00', '10:00:00');
INSERT INTO public.horarios VALUES (1011, 'Quinta', '18:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1012, 'Terca', '07:00:00', '09:00:00');
INSERT INTO public.horarios VALUES (1013, 'Quarta', '07:00:00', '08:00:00');
INSERT INTO public.horarios VALUES (1013, 'Terca', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1014, 'Terca', '15:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1014, 'Quinta', '15:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1014, 'Segunda', '19:00:00', '21:00:00');
INSERT INTO public.horarios VALUES (1015, 'Segunda', '11:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1015, 'Sexta', '16:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1016, 'Terca', '20:00:00', '21:00:00');
INSERT INTO public.horarios VALUES (1016, 'Sexta', '12:00:00', '13:00:00');
INSERT INTO public.horarios VALUES (1016, 'Quinta', '15:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1017, 'Quinta', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1017, 'Segunda', '16:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1018, 'Quinta', '17:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1018, 'Terca', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1019, 'Terca', '16:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1019, 'Quarta', '13:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1019, 'Segunda', '07:00:00', '08:00:00');
INSERT INTO public.horarios VALUES (1020, 'Sexta', '18:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1020, 'Segunda', '10:00:00', '11:00:00');
INSERT INTO public.horarios VALUES (1020, 'Quinta', '20:00:00', '21:00:00');
INSERT INTO public.horarios VALUES (1021, 'Quarta', '19:00:00', '21:00:00');
INSERT INTO public.horarios VALUES (1021, 'Sexta', '11:00:00', '13:00:00');
INSERT INTO public.horarios VALUES (1021, 'Segunda', '12:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1022, 'Sexta', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1022, 'Quarta', '08:00:00', '10:00:00');
INSERT INTO public.horarios VALUES (1023, 'Segunda', '14:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1024, 'Sexta', '09:00:00', '10:00:00');
INSERT INTO public.horarios VALUES (1025, 'Sexta', '18:00:00', '20:00:00');
INSERT INTO public.horarios VALUES (1025, 'Quarta', '16:00:00', '18:00:00');
INSERT INTO public.horarios VALUES (1025, 'Terca', '09:00:00', '11:00:00');
INSERT INTO public.horarios VALUES (1026, 'Terca', '15:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1026, 'Segunda', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1027, 'Sexta', '14:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1027, 'Quarta', '15:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1028, 'Quarta', '20:00:00', '21:00:00');
INSERT INTO public.horarios VALUES (1028, 'Segunda', '18:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1029, 'Terca', '15:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1030, 'Segunda', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1030, 'Sexta', '20:00:00', '22:00:00');
INSERT INTO public.horarios VALUES (1030, 'Quinta', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1031, 'Sexta', '13:00:00', '14:00:00');
INSERT INTO public.horarios VALUES (1031, 'Quarta', '08:00:00', '09:00:00');
INSERT INTO public.horarios VALUES (1031, 'Quinta', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1032, 'Sexta', '11:00:00', '13:00:00');
INSERT INTO public.horarios VALUES (1032, 'Segunda', '11:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1033, 'Quarta', '11:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1033, 'Segunda', '20:00:00', '22:00:00');
INSERT INTO public.horarios VALUES (1033, 'Quinta', '16:00:00', '17:00:00');
INSERT INTO public.horarios VALUES (1034, 'Quarta', '17:00:00', '19:00:00');
INSERT INTO public.horarios VALUES (1034, 'Terca', '15:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1034, 'Sexta', '14:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1035, 'Quinta', '14:00:00', '16:00:00');
INSERT INTO public.horarios VALUES (1036, 'Terca', '13:00:00', '15:00:00');
INSERT INTO public.horarios VALUES (1037, 'Sexta', '10:00:00', '12:00:00');
INSERT INTO public.horarios VALUES (1038, 'Terca', '08:00:00', '09:00:00');
INSERT INTO public.horarios VALUES (1039, 'Terca', '08:00:00', '10:00:00');


--
-- Data for Name: matricula; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.matricula VALUES ('2196096', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1000, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1000, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1001, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1001, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1002, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1002, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1003, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1003, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1004, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1004, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1005, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1005, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1005, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1005, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1005, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1005, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1005, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1006, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1006, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1007, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1007, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1008, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1008, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1009, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1009, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1010, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1010, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1011, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1011, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1011, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1011, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1012, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1012, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1013, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1013, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1014, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1014, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1014, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1014, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1014, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1015, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1015, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1016, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1016, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1017, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1017, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1018, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1018, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1019, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1019, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1020, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1020, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1021, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1021, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1022, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1022, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1022, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1022, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1022, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1023, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1023, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1023, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1023, 'Ativa');
INSERT INTO public.matricula VALUES ('2196096', 1024, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1024, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1024, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1024, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1024, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1024, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1024, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1024, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1024, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('6651646', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1025, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1025, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2890489', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('2485594', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1026, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1026, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('6128786', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2138666', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('2890489', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('1160773', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('9651573', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1027, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1027, 'Ativa');
INSERT INTO public.matricula VALUES ('7533052', 1028, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1028, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1028, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1028, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1028, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1029, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1029, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1029, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('5926464', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('4278413', 1029, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('9651573', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('2523873', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('6065876', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('2781909', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('4110382', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('8236098', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('6256480', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1030, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1030, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('6908973', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('3369041', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1031, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1031, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('7505126', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1032, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1032, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('4502368', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('2410780', 1033, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1033, 'Pendente');
INSERT INTO public.matricula VALUES ('6065876', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('3012871', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('6908973', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('2196096', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('9687726', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('9766553', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('6128786', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('2410780', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('2987927', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('8338607', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('4278413', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('6221665', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('1737678', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('3393269', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('9004880', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('2485594', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('2890489', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1034, 'Pendente');
INSERT INTO public.matricula VALUES ('4110382', 1035, 'Ativa');
INSERT INTO public.matricula VALUES ('7905686', 1035, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1035, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1035, 'Ativa');
INSERT INTO public.matricula VALUES ('7084419', 1035, 'Pendente');
INSERT INTO public.matricula VALUES ('3973638', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('4502368', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1036, 'Ativa');
INSERT INTO public.matricula VALUES ('6738608', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('2637706', 1036, 'Pendente');
INSERT INTO public.matricula VALUES ('9902354', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('3900630', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('1160773', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('3393269', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('7199006', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('1737678', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('2315919', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('8828137', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('2373756', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('7838240', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('6221665', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('8207648', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('8338607', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('5156042', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('2523873', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('5415276', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('2890489', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('6644653', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('9038731', 1037, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1037, 'Pendente');
INSERT INTO public.matricula VALUES ('5926464', 1038, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1038, 'Pendente');
INSERT INTO public.matricula VALUES ('5398987', 1038, 'Ativa');
INSERT INTO public.matricula VALUES ('7838240', 1038, 'Pendente');
INSERT INTO public.matricula VALUES ('2741817', 1038, 'Ativa');
INSERT INTO public.matricula VALUES ('2315919', 1038, 'Pendente');
INSERT INTO public.matricula VALUES ('8236098', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('9902354', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('2890489', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('6256480', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('6644653', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('6651646', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('2987927', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('5156042', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('2637706', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('9687726', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('6738608', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('9038731', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('7084419', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('7533052', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('8207648', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('5398987', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('2138666', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('2781909', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('5415276', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('2741817', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('3973638', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('7905686', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('3900630', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('2373756', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('7199006', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('9004880', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('8828137', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('9766553', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('3369041', 1039, 'Ativa');
INSERT INTO public.matricula VALUES ('7505126', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('3012871', 1039, 'Pendente');
INSERT INTO public.matricula VALUES ('2024190', 1034, 'Ativa');
INSERT INTO public.matricula VALUES ('2025190', 1001, 'Ativa');


--
-- Data for Name: pre_requisitos; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.pre_requisitos VALUES ('CAJC396', 'JIJD423');
INSERT INTO public.pre_requisitos VALUES ('COYP966', 'CAJC396');
INSERT INTO public.pre_requisitos VALUES ('LSEV313', 'WYFW213');
INSERT INTO public.pre_requisitos VALUES ('ZBFT202', 'JRZI625');
INSERT INTO public.pre_requisitos VALUES ('LSEV313', 'CAJC396');
INSERT INTO public.pre_requisitos VALUES ('RKKT348', 'OJAE495');
INSERT INTO public.pre_requisitos VALUES ('FKLF581', 'UAYQ942');
INSERT INTO public.pre_requisitos VALUES ('OJAE495', 'ITWB921');
INSERT INTO public.pre_requisitos VALUES ('JLKK128', 'ONAY724');
INSERT INTO public.pre_requisitos VALUES ('UAYQ942', 'IOIB247');
INSERT INTO public.pre_requisitos VALUES ('NOUT250', 'OJAE495');
INSERT INTO public.pre_requisitos VALUES ('ZBFT202', 'ONAY724');
INSERT INTO public.pre_requisitos VALUES ('ZBFT202', 'WYFW213');
INSERT INTO public.pre_requisitos VALUES ('ONAY724', 'IOIB247');
INSERT INTO public.pre_requisitos VALUES ('FKNA475', 'IOIB247');
INSERT INTO public.pre_requisitos VALUES ('WYFW213', 'KFAS933');
INSERT INTO public.pre_requisitos VALUES ('ITWB921', 'KFAS933');
INSERT INTO public.pre_requisitos VALUES ('NOUT250', 'ZHZX546');
INSERT INTO public.pre_requisitos VALUES ('FKLF581', 'JLKK128');
INSERT INTO public.pre_requisitos VALUES ('WYFW213', 'FKLF581');


--
-- Data for Name: turmas; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.turmas VALUES (1000, 'JIJD423', '2025.1', 'Manha', 'Sala 2', 50, 'Dr. Theodoro GonÔö£┬║alves');
INSERT INTO public.turmas VALUES (1001, 'JIJD423', '2025.2', 'Manha', 'Sala 1', 50, 'Ravi Lucca da Cruz');
INSERT INTO public.turmas VALUES (1002, 'WYFW213', '2025.2', 'Tarde', 'Sala 5', 70, 'Vinicius Teixeira');
INSERT INTO public.turmas VALUES (1003, 'WYFW213', '2025.1', 'Manha', 'Sala 5', 50, 'Sra. Hellena Cassiano');
INSERT INTO public.turmas VALUES (1004, 'RKKT348', '2025.2', 'Manha', 'Sala 2', 70, 'Lucas Gabriel da Mota');
INSERT INTO public.turmas VALUES (1005, 'RKKT348', '2025.2', 'Noite', 'Sala 1', 24, 'Davi Miguel Moraes');
INSERT INTO public.turmas VALUES (1006, 'WJXO924', '2025.2', 'Tarde', 'Sala 1', 24, 'Aylla Marques');
INSERT INTO public.turmas VALUES (1007, 'WJXO924', '2025.1', 'Manha', 'Sala 4', 50, 'Maya Jesus');
INSERT INTO public.turmas VALUES (1008, 'ONAY724', '2025.2', 'Manha', 'Laboratorio 4', 50, 'Gabrielly Pinto');
INSERT INTO public.turmas VALUES (1009, 'ONAY724', '2025.1', 'Manha', 'Laboratorio 4', 50, 'Emanuelly Cardoso');
INSERT INTO public.turmas VALUES (1010, 'ZHZX546', '2025.1', 'Manha', 'Sala 1', 50, 'Manuela da Mata');
INSERT INTO public.turmas VALUES (1011, 'ZHZX546', '2025.2', 'Noite', 'Sala 5', 24, 'Camila Nunes');
INSERT INTO public.turmas VALUES (1012, 'NOUT250', '2025.2', 'Noite', 'Laboratorio 5', 70, 'VitÔö£Ôöéria Monteiro');
INSERT INTO public.turmas VALUES (1013, 'NOUT250', '2025.1', 'Noite', 'Laboratorio 1', 24, 'Ana Beatriz Caldeira');
INSERT INTO public.turmas VALUES (1014, 'OJAE495', '2025.1', 'Manha', 'Sala 1', 70, 'Sra. VitÔö£Ôöéria Nogueira');
INSERT INTO public.turmas VALUES (1015, 'OJAE495', '2025.1', 'Manha', 'Laboratorio 1', 50, 'Gustavo da ConceiÔö£┬║Ôö£├║o');
INSERT INTO public.turmas VALUES (1016, 'FKNA475', '2025.1', 'Noite', 'Laboratorio 5', 24, 'Srta. Evelyn Porto');
INSERT INTO public.turmas VALUES (1017, 'FKNA475', '2025.2', 'Tarde', 'Sala 4', 24, 'Pietra Costa');
INSERT INTO public.turmas VALUES (1018, 'LSEV313', '2025.2', 'Noite', 'Sala 3', 50, 'Mirella Pereira');
INSERT INTO public.turmas VALUES (1019, 'LSEV313', '2025.1', 'Manha', 'Sala 2', 50, 'Breno Nunes');
INSERT INTO public.turmas VALUES (1020, 'JLKK128', '2025.1', 'Manha', 'Laboratorio 1', 50, 'JoÔö£├║o Pedro Viana');
INSERT INTO public.turmas VALUES (1021, 'JLKK128', '2025.2', 'Tarde', 'Laboratorio 1', 24, 'Maria Helena Montenegro');
INSERT INTO public.turmas VALUES (1022, 'UAYQ942', '2025.2', 'Tarde', 'Sala 2', 50, 'Rodrigo da ConceiÔö£┬║Ôö£├║o');
INSERT INTO public.turmas VALUES (1023, 'UAYQ942', '2025.2', 'Noite', 'Sala 3', 70, 'Apollo Moura');
INSERT INTO public.turmas VALUES (1024, 'ZBFT202', '2025.2', 'Noite', 'Sala 5', 24, 'Gustavo da Rocha');
INSERT INTO public.turmas VALUES (1025, 'ZBFT202', '2025.1', 'Noite', 'Sala 4', 70, 'Caleb Borges');
INSERT INTO public.turmas VALUES (1026, 'IOIB247', '2025.1', 'Manha', 'Laboratorio 2', 50, 'Henry Azevedo');
INSERT INTO public.turmas VALUES (1027, 'IOIB247', '2025.1', 'Tarde', 'Laboratorio 2', 70, 'Marcela da Cruz');
INSERT INTO public.turmas VALUES (1028, 'FKLF581', '2025.1', 'Tarde', 'Sala 2', 50, 'Thiago Ribeiro');
INSERT INTO public.turmas VALUES (1029, 'FKLF581', '2025.1', 'Manha', 'Laboratorio 1', 24, 'JosÔö£┬« Miguel Novaes');
INSERT INTO public.turmas VALUES (1030, 'CAJC396', '2025.1', 'Manha', 'Laboratorio 2', 70, 'Laura Dias');
INSERT INTO public.turmas VALUES (1031, 'CAJC396', '2025.2', 'Noite', 'Sala 5', 24, 'Sara Pinto');
INSERT INTO public.turmas VALUES (1032, 'JRZI625', '2025.2', 'Noite', 'Laboratorio 2', 70, 'OlÔö£┬ívia Vasconcelos');
INSERT INTO public.turmas VALUES (1033, 'JRZI625', '2025.1', 'Noite', 'Laboratorio 3', 24, 'AntÔö£Ôöñnio Vasconcelos');
INSERT INTO public.turmas VALUES (1034, 'KFAS933', '2025.1', 'Noite', 'Sala 5', 50, 'Sophie Marques');
INSERT INTO public.turmas VALUES (1035, 'KFAS933', '2025.1', 'Tarde', 'Sala 4', 70, 'Mirella Peixoto');
INSERT INTO public.turmas VALUES (1036, 'COYP966', '2025.1', 'Manha', 'Sala 5', 70, 'Kevin Oliveira');
INSERT INTO public.turmas VALUES (1037, 'COYP966', '2025.2', 'Manha', 'Laboratorio 3', 50, 'Srta. LuÔö£┬ísa da Rosa');
INSERT INTO public.turmas VALUES (1038, 'ITWB921', '2025.2', 'Manha', 'Sala 2', 70, 'Igor Abreu');
INSERT INTO public.turmas VALUES (1039, 'ITWB921', '2025.1', 'Noite', 'Sala 3', 70, 'Sr. AntÔö£Ôöñnio Almeida');


--
-- Name: turmas_id_turma_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.turmas_id_turma_seq', 1, false);


--
-- Name: aluno aluno_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aluno
    ADD CONSTRAINT aluno_pkey PRIMARY KEY (matricula_aluno);


--
-- Name: disciplina disciplina_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disciplina
    ADD CONSTRAINT disciplina_pkey PRIMARY KEY (codigo_disciplina);


--
-- Name: historico_escolar pk_historico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_escolar
    ADD CONSTRAINT pk_historico PRIMARY KEY (matricula_aluno, codigo_disciplina);


--
-- Name: horarios pk_horarios; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.horarios
    ADD CONSTRAINT pk_horarios PRIMARY KEY (id_turma, horario_ini, dia_semana);


--
-- Name: matricula pk_matricula; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT pk_matricula PRIMARY KEY (id_turma, matricula_aluno);


--
-- Name: pre_requisitos pk_pre_requisitos; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_requisitos
    ADD CONSTRAINT pk_pre_requisitos PRIMARY KEY (codigo_disciplina_principal, codigo_disciplina_pre_requisito);


--
-- Name: turmas turmas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turmas
    ADD CONSTRAINT turmas_pkey PRIMARY KEY (id_turma);


--
-- Name: turmas fk_codigo_disciplina; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turmas
    ADD CONSTRAINT fk_codigo_disciplina FOREIGN KEY (codigo_disciplina) REFERENCES public.disciplina(codigo_disciplina);


--
-- Name: historico_escolar fk_codigo_disciplina; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_escolar
    ADD CONSTRAINT fk_codigo_disciplina FOREIGN KEY (codigo_disciplina) REFERENCES public.disciplina(codigo_disciplina);


--
-- Name: pre_requisitos fk_disciplina_pre_requisito; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_requisitos
    ADD CONSTRAINT fk_disciplina_pre_requisito FOREIGN KEY (codigo_disciplina_pre_requisito) REFERENCES public.disciplina(codigo_disciplina) ON UPDATE CASCADE;


--
-- Name: pre_requisitos fk_disciplina_principal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_requisitos
    ADD CONSTRAINT fk_disciplina_principal FOREIGN KEY (codigo_disciplina_principal) REFERENCES public.disciplina(codigo_disciplina);


--
-- Name: matricula fk_id_turma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT fk_id_turma FOREIGN KEY (id_turma) REFERENCES public.turmas(id_turma);


--
-- Name: horarios fk_id_turma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.horarios
    ADD CONSTRAINT fk_id_turma FOREIGN KEY (id_turma) REFERENCES public.turmas(id_turma);


--
-- Name: matricula fk_matricula_aluno; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT fk_matricula_aluno FOREIGN KEY (matricula_aluno) REFERENCES public.aluno(matricula_aluno);


--
-- Name: historico_escolar fk_matricula_aluno; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_escolar
    ADD CONSTRAINT fk_matricula_aluno FOREIGN KEY (matricula_aluno) REFERENCES public.aluno(matricula_aluno);


--
-- PostgreSQL database dump complete
--

