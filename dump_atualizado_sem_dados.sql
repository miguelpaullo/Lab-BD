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

