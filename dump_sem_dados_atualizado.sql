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
        SELECT h.codigo_disciplina 
        FROM historico_escolar h 
        WHERE h.matricula_aluno = p_matricula_aluno
          AND h.situacao = 'Aprovado'
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



--
-- Data for Name: disciplina; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: historico_escolar; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: horarios; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: matricula; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: pre_requisitos; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: turmas; Type: TABLE DATA; Schema: public; Owner: -
--



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

