SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: aperturas_caja; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aperturas_caja (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    fecha date NOT NULL,
    estado character varying DEFAULT 'abierta'::character varying NOT NULL,
    monto_apertura numeric(10,2) DEFAULT 0.0 NOT NULL,
    monto_cierre numeric(10,2),
    total_pagos numeric(10,2) DEFAULT 0.0,
    total_ingresos numeric(10,2) DEFAULT 0.0,
    total_egresos numeric(10,2) DEFAULT 0.0,
    diferencia numeric(10,2),
    notas_apertura text,
    notas_cierre text,
    abierta_por_id bigint NOT NULL,
    cerrada_por_id bigint,
    cerrada_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: aperturas_caja_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aperturas_caja_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aperturas_caja_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aperturas_caja_id_seq OWNED BY public.aperturas_caja.id;


--
-- Name: aperturas_caja_numero_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aperturas_caja_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: carriers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carriers (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    tipo character varying,
    activo boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: carriers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carriers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: carriers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carriers_id_seq OWNED BY public.carriers.id;


--
-- Name: categoria_precios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categoria_precios (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    precio_libra_aereo numeric(10,2),
    precio_libra_maritimo numeric(10,2),
    precio_volumen numeric(10,2),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categoria_precios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categoria_precios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categoria_precios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categoria_precios_id_seq OWNED BY public.categoria_precios.id;


--
-- Name: cliente_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cliente_sessions (
    id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cliente_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cliente_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cliente_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cliente_sessions_id_seq OWNED BY public.cliente_sessions.id;


--
-- Name: clientes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clientes (
    id bigint NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    apellido character varying,
    identidad character varying,
    email character varying,
    telefono character varying,
    telefono_whatsapp character varying,
    direccion text,
    ciudad character varying,
    departamento character varying,
    saldo_pendiente numeric(10,2) DEFAULT 0.0,
    categoria_precio_id bigint,
    correo_enviado boolean DEFAULT false,
    correo_confirmado boolean DEFAULT false,
    activo boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    notas_miami text,
    notas_honduras text,
    password_digest character varying,
    notificar_facturas boolean DEFAULT true NOT NULL
);


--
-- Name: clientes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clientes_id_seq OWNED BY public.clientes.id;


--
-- Name: configuracions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configuracions (
    id bigint NOT NULL,
    clave character varying NOT NULL,
    valor text,
    tipo character varying,
    categoria character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: configuracions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.configuracions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configuracions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.configuracions_id_seq OWNED BY public.configuracions.id;


--
-- Name: consignatarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consignatarios (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    identidad character varying,
    direccion text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: consignatarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consignatarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: consignatarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consignatarios_id_seq OWNED BY public.consignatarios.id;


--
-- Name: cotizacion_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cotizacion_items (
    id bigint NOT NULL,
    cotizacion_id bigint NOT NULL,
    paquete_id bigint,
    concepto character varying NOT NULL,
    cantidad numeric(10,2) DEFAULT 1.0,
    precio_unitario numeric(10,2) DEFAULT 0.0,
    peso_cobrar numeric(10,2),
    precio_libra numeric(10,2),
    subtotal numeric(10,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cotizacion_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cotizacion_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cotizacion_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cotizacion_items_id_seq OWNED BY public.cotizacion_items.id;


--
-- Name: cotizaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cotizaciones (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    cliente_id bigint NOT NULL,
    estado character varying DEFAULT 'borrador'::character varying NOT NULL,
    subtotal numeric(10,2) DEFAULT 0.0,
    impuesto numeric(10,2) DEFAULT 0.0,
    total numeric(10,2) DEFAULT 0.0,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    tasa_cambio_aplicada numeric(10,4),
    notas text,
    terminos text,
    vigencia_dias integer DEFAULT 30,
    fecha_vencimiento date,
    creado_por_id bigint,
    enviada_at timestamp(6) without time zone,
    aceptada_at timestamp(6) without time zone,
    rechazada_at timestamp(6) without time zone,
    email_enviado_at timestamp(6) without time zone,
    venta_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cotizaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cotizaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cotizaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cotizaciones_id_seq OWNED BY public.cotizaciones.id;


--
-- Name: egresos_caja; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.egresos_caja (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    apertura_caja_id bigint NOT NULL,
    monto numeric(10,2) NOT NULL,
    concepto character varying NOT NULL,
    metodo_pago character varying NOT NULL,
    categoria character varying,
    notas text,
    registrado_por_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: egresos_caja_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.egresos_caja_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: egresos_caja_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.egresos_caja_id_seq OWNED BY public.egresos_caja.id;


--
-- Name: egresos_caja_numero_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.egresos_caja_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: empresa_manifiestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.empresa_manifiestos (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    activo boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: empresa_manifiestos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.empresa_manifiestos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: empresa_manifiestos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.empresa_manifiestos_id_seq OWNED BY public.empresa_manifiestos.id;


--
-- Name: empresas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.empresas (
    id bigint NOT NULL,
    nombre character varying DEFAULT 'Compras Express Cargo'::character varying NOT NULL,
    rtn character varying,
    telefono character varying,
    email_contacto character varying,
    direccion text,
    ciudad character varying DEFAULT 'San Pedro Sula'::character varying,
    pais character varying DEFAULT 'Honduras'::character varying,
    moneda_default character varying DEFAULT 'LPS'::character varying,
    isv_rate numeric(5,4) DEFAULT 0.15,
    sitio_web character varying,
    terminos_factura text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: empresas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.empresas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: empresas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.empresas_id_seq OWNED BY public.empresas.id;


--
-- Name: entrega_paquetes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entrega_paquetes (
    id bigint NOT NULL,
    entrega_id bigint NOT NULL,
    paquete_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entrega_paquetes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entrega_paquetes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entrega_paquetes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entrega_paquetes_id_seq OWNED BY public.entrega_paquetes.id;


--
-- Name: entregas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entregas (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    cliente_id bigint NOT NULL,
    tipo_entrega character varying DEFAULT 'retiro_oficina'::character varying NOT NULL,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    receptor_nombre character varying NOT NULL,
    receptor_identidad character varying NOT NULL,
    direccion_entrega text,
    repartidor_id bigint,
    creado_por_id bigint,
    notas text,
    despachado_at timestamp(6) without time zone,
    entregado_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entregas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entregas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entregas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entregas_id_seq OWNED BY public.entregas.id;


--
-- Name: entregas_numero_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entregas_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: financiamiento_cuotas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financiamiento_cuotas (
    id bigint NOT NULL,
    financiamiento_id bigint NOT NULL,
    numero_cuota integer NOT NULL,
    monto numeric(10,2) NOT NULL,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    fecha_vencimiento date NOT NULL,
    pagada_at timestamp(6) without time zone,
    pago_id bigint,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: financiamiento_cuotas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.financiamiento_cuotas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: financiamiento_cuotas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.financiamiento_cuotas_id_seq OWNED BY public.financiamiento_cuotas.id;


--
-- Name: financiamientos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financiamientos (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    venta_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    estado character varying DEFAULT 'activo'::character varying NOT NULL,
    numero_cuotas integer NOT NULL,
    monto_total numeric(10,2) NOT NULL,
    monto_cuota numeric(10,2) NOT NULL,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    tasa_cambio_aplicada numeric(10,4),
    frecuencia character varying DEFAULT 'mensual'::character varying NOT NULL,
    fecha_inicio date NOT NULL,
    notas text,
    creado_por_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: financiamientos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.financiamientos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: financiamientos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.financiamientos_id_seq OWNED BY public.financiamientos.id;


--
-- Name: ingresos_caja; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingresos_caja (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    apertura_caja_id bigint NOT NULL,
    monto numeric(10,2) NOT NULL,
    concepto character varying NOT NULL,
    metodo_pago character varying NOT NULL,
    notas text,
    registrado_por_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ingresos_caja_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ingresos_caja_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ingresos_caja_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ingresos_caja_id_seq OWNED BY public.ingresos_caja.id;


--
-- Name: ingresos_caja_numero_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ingresos_caja_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lugars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lugars (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    tipo character varying,
    direccion text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: lugars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lugars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lugars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lugars_id_seq OWNED BY public.lugars.id;


--
-- Name: manifiestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifiestos (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    numero_caja character varying,
    numero_guia character varying,
    empresa_manifiesto_id bigint,
    estado character varying DEFAULT 'creado'::character varying NOT NULL,
    tipo_envio character varying,
    expedido_por character varying,
    cantidad_paquetes integer DEFAULT 0,
    volumen_total numeric(10,2),
    peso_total numeric(10,2),
    fecha_enviado timestamp(6) without time zone,
    fecha_aduana timestamp(6) without time zone,
    user_id bigint,
    activo boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: manifiestos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manifiestos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manifiestos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manifiestos_id_seq OWNED BY public.manifiestos.id;


--
-- Name: nota_credito_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nota_credito_items (
    id bigint NOT NULL,
    nota_credito_id bigint NOT NULL,
    paquete_id bigint,
    concepto character varying NOT NULL,
    peso_cobrar numeric(10,2),
    precio_libra numeric(10,2),
    subtotal numeric(10,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nota_credito_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nota_credito_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nota_credito_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nota_credito_items_id_seq OWNED BY public.nota_credito_items.id;


--
-- Name: nota_debito_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nota_debito_items (
    id bigint NOT NULL,
    nota_debito_id bigint NOT NULL,
    paquete_id bigint,
    concepto character varying NOT NULL,
    peso_cobrar numeric(10,2),
    precio_libra numeric(10,2),
    subtotal numeric(10,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nota_debito_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nota_debito_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nota_debito_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nota_debito_items_id_seq OWNED BY public.nota_debito_items.id;


--
-- Name: notas_credito; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notas_credito (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    venta_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    estado character varying DEFAULT 'creado'::character varying NOT NULL,
    motivo character varying NOT NULL,
    subtotal numeric(10,2) DEFAULT 0.0,
    impuesto numeric(10,2) DEFAULT 0.0,
    total numeric(10,2) DEFAULT 0.0,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    notas text,
    creado_por_id bigint,
    emitido_at timestamp(6) without time zone,
    anulado_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tasa_cambio_aplicada numeric(10,4)
);


--
-- Name: notas_credito_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notas_credito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notas_credito_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notas_credito_id_seq OWNED BY public.notas_credito.id;


--
-- Name: notas_debito; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notas_debito (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    venta_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    estado character varying DEFAULT 'creado'::character varying NOT NULL,
    motivo character varying NOT NULL,
    subtotal numeric(10,2) DEFAULT 0.0,
    impuesto numeric(10,2) DEFAULT 0.0,
    total numeric(10,2) DEFAULT 0.0,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    notas text,
    creado_por_id bigint,
    emitido_at timestamp(6) without time zone,
    anulado_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tasa_cambio_aplicada numeric(10,4)
);


--
-- Name: notas_debito_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notas_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notas_debito_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notas_debito_id_seq OWNED BY public.notas_debito.id;


--
-- Name: pagos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pagos (
    id bigint NOT NULL,
    venta_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    monto numeric(10,2) NOT NULL,
    metodo_pago character varying NOT NULL,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    estado character varying DEFAULT 'completado'::character varying NOT NULL,
    pagado_at timestamp(6) without time zone,
    notas text,
    registrado_por_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tasa_cambio_aplicada numeric(10,4),
    apertura_caja_id bigint
);


--
-- Name: pagos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pagos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pagos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pagos_id_seq OWNED BY public.pagos.id;


--
-- Name: paquetes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paquetes (
    id bigint NOT NULL,
    tracking character varying NOT NULL,
    guia character varying NOT NULL,
    cliente_id bigint NOT NULL,
    manifiesto_id bigint,
    tipo_envio_id bigint,
    estado character varying DEFAULT 'recibido_miami'::character varying NOT NULL,
    peso numeric(10,2),
    volumen numeric(10,2),
    precio_libra numeric(10,2),
    monto_total numeric(10,2),
    alto numeric(8,2),
    largo numeric(8,2),
    ancho numeric(8,2),
    peso_volumetrico numeric(10,2),
    peso_cobrar numeric(10,2),
    cantidad_productos integer,
    cantidad_paquetes integer,
    numero_caja integer,
    descripcion text,
    remitente character varying,
    expedido_por character varying,
    proveedor character varying,
    notas_internas text,
    pre_alerta boolean DEFAULT false,
    pre_factura boolean DEFAULT false,
    solicito_cambio_servicio boolean DEFAULT false,
    retener_miami boolean DEFAULT false,
    fecha_recibido_miami timestamp(6) without time zone,
    fecha_enviado timestamp(6) without time zone,
    fecha_llegada_hn timestamp(6) without time zone,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pre_factura_id bigint,
    venta_id bigint,
    entrega_id bigint
);


--
-- Name: paquetes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.paquetes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: paquetes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.paquetes_id_seq OWNED BY public.paquetes.id;


--
-- Name: pre_alerta_paquetes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pre_alerta_paquetes (
    id bigint NOT NULL,
    pre_alerta_id bigint NOT NULL,
    paquete_id bigint,
    tracking character varying NOT NULL,
    descripcion text,
    fecha date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    instrucciones text
);


--
-- Name: pre_alerta_paquetes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pre_alerta_paquetes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pre_alerta_paquetes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pre_alerta_paquetes_id_seq OWNED BY public.pre_alerta_paquetes.id;


--
-- Name: pre_alertas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pre_alertas (
    id bigint NOT NULL,
    numero_documento character varying NOT NULL,
    cliente_id bigint NOT NULL,
    tipo_envio_id bigint NOT NULL,
    consolidado boolean DEFAULT false,
    con_reempaque boolean DEFAULT false,
    notas_grupo text,
    estado character varying DEFAULT 'pre_alerta'::character varying NOT NULL,
    notificado boolean DEFAULT false,
    creado_por_tipo character varying,
    creado_por_id bigint,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    titulo character varying,
    proveedor character varying
);


--
-- Name: pre_alertas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pre_alertas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pre_alertas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pre_alertas_id_seq OWNED BY public.pre_alertas.id;


--
-- Name: pre_factura_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pre_factura_items (
    id bigint NOT NULL,
    pre_factura_id bigint NOT NULL,
    paquete_id bigint,
    concepto character varying NOT NULL,
    peso_cobrar numeric(10,2),
    precio_libra numeric(10,2),
    subtotal numeric(10,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pre_factura_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pre_factura_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pre_factura_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pre_factura_items_id_seq OWNED BY public.pre_factura_items.id;


--
-- Name: pre_facturas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pre_facturas (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    cliente_id bigint NOT NULL,
    estado character varying DEFAULT 'creado'::character varying NOT NULL,
    subtotal numeric(10,2) DEFAULT 0.0,
    impuesto numeric(10,2) DEFAULT 0.0,
    total numeric(10,2) DEFAULT 0.0,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    fecha_trabajo date,
    notas text,
    creado_por_id bigint,
    confirmado_at timestamp(6) without time zone,
    facturado_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tasa_cambio_aplicada numeric(10,4)
);


--
-- Name: pre_facturas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pre_facturas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pre_facturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pre_facturas_id_seq OWNED BY public.pre_facturas.id;


--
-- Name: recibos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recibos (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    venta_id bigint NOT NULL,
    pago_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    monto numeric(10,2) NOT NULL,
    forma_pago character varying,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tasa_cambio_aplicada numeric(10,4)
);


--
-- Name: recibos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recibos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recibos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recibos_id_seq OWNED BY public.recibos.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: tamano_cajas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tamano_cajas (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    largo numeric(8,2),
    ancho numeric(8,2),
    alto numeric(8,2),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tamano_cajas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tamano_cajas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tamano_cajas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tamano_cajas_id_seq OWNED BY public.tamano_cajas.id;


--
-- Name: tipo_envios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipo_envios (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    codigo character varying,
    activo boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    con_reempaque boolean DEFAULT false NOT NULL,
    consolidable boolean DEFAULT false NOT NULL,
    precio_libra numeric(10,2),
    modalidad character varying,
    sla character varying,
    max_paquetes_por_accion integer
);


--
-- Name: tipo_envios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipo_envios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_envios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipo_envios_id_seq OWNED BY public.tipo_envios.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    nombre character varying DEFAULT ''::character varying NOT NULL,
    rol character varying DEFAULT 'digitador_miami'::character varying NOT NULL,
    ubicacion character varying DEFAULT 'honduras'::character varying,
    activo boolean DEFAULT true NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: venta_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venta_items (
    id bigint NOT NULL,
    venta_id bigint NOT NULL,
    paquete_id bigint,
    concepto character varying NOT NULL,
    peso_cobrar numeric(10,2),
    precio_libra numeric(10,2),
    subtotal numeric(10,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: venta_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.venta_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: venta_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.venta_items_id_seq OWNED BY public.venta_items.id;


--
-- Name: ventas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ventas (
    id bigint NOT NULL,
    numero character varying NOT NULL,
    cliente_id bigint NOT NULL,
    pre_factura_id bigint,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    subtotal numeric(10,2) DEFAULT 0.0,
    impuesto numeric(10,2) DEFAULT 0.0,
    total numeric(10,2) DEFAULT 0.0,
    saldo_pendiente numeric(10,2) DEFAULT 0.0,
    moneda character varying DEFAULT 'LPS'::character varying NOT NULL,
    notas text,
    creado_por_id bigint,
    pagada_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    email_pendiente_enviado_at timestamp(6) without time zone,
    email_pagada_enviado_at timestamp(6) without time zone,
    tasa_cambio_aplicada numeric(10,4),
    financiamiento_id bigint
);


--
-- Name: ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ventas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ventas_id_seq OWNED BY public.ventas.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: aperturas_caja id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aperturas_caja ALTER COLUMN id SET DEFAULT nextval('public.aperturas_caja_id_seq'::regclass);


--
-- Name: carriers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carriers ALTER COLUMN id SET DEFAULT nextval('public.carriers_id_seq'::regclass);


--
-- Name: categoria_precios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categoria_precios ALTER COLUMN id SET DEFAULT nextval('public.categoria_precios_id_seq'::regclass);


--
-- Name: cliente_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente_sessions ALTER COLUMN id SET DEFAULT nextval('public.cliente_sessions_id_seq'::regclass);


--
-- Name: clientes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes ALTER COLUMN id SET DEFAULT nextval('public.clientes_id_seq'::regclass);


--
-- Name: configuracions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracions ALTER COLUMN id SET DEFAULT nextval('public.configuracions_id_seq'::regclass);


--
-- Name: consignatarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignatarios ALTER COLUMN id SET DEFAULT nextval('public.consignatarios_id_seq'::regclass);


--
-- Name: cotizacion_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizacion_items ALTER COLUMN id SET DEFAULT nextval('public.cotizacion_items_id_seq'::regclass);


--
-- Name: cotizaciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones ALTER COLUMN id SET DEFAULT nextval('public.cotizaciones_id_seq'::regclass);


--
-- Name: egresos_caja id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egresos_caja ALTER COLUMN id SET DEFAULT nextval('public.egresos_caja_id_seq'::regclass);


--
-- Name: empresa_manifiestos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresa_manifiestos ALTER COLUMN id SET DEFAULT nextval('public.empresa_manifiestos_id_seq'::regclass);


--
-- Name: empresas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas ALTER COLUMN id SET DEFAULT nextval('public.empresas_id_seq'::regclass);


--
-- Name: entrega_paquetes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_paquetes ALTER COLUMN id SET DEFAULT nextval('public.entrega_paquetes_id_seq'::regclass);


--
-- Name: entregas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas ALTER COLUMN id SET DEFAULT nextval('public.entregas_id_seq'::regclass);


--
-- Name: financiamiento_cuotas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamiento_cuotas ALTER COLUMN id SET DEFAULT nextval('public.financiamiento_cuotas_id_seq'::regclass);


--
-- Name: financiamientos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamientos ALTER COLUMN id SET DEFAULT nextval('public.financiamientos_id_seq'::regclass);


--
-- Name: ingresos_caja id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingresos_caja ALTER COLUMN id SET DEFAULT nextval('public.ingresos_caja_id_seq'::regclass);


--
-- Name: lugars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lugars ALTER COLUMN id SET DEFAULT nextval('public.lugars_id_seq'::regclass);


--
-- Name: manifiestos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos ALTER COLUMN id SET DEFAULT nextval('public.manifiestos_id_seq'::regclass);


--
-- Name: nota_credito_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_credito_items ALTER COLUMN id SET DEFAULT nextval('public.nota_credito_items_id_seq'::regclass);


--
-- Name: nota_debito_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_debito_items ALTER COLUMN id SET DEFAULT nextval('public.nota_debito_items_id_seq'::regclass);


--
-- Name: notas_credito id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_credito ALTER COLUMN id SET DEFAULT nextval('public.notas_credito_id_seq'::regclass);


--
-- Name: notas_debito id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_debito ALTER COLUMN id SET DEFAULT nextval('public.notas_debito_id_seq'::regclass);


--
-- Name: pagos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id SET DEFAULT nextval('public.pagos_id_seq'::regclass);


--
-- Name: paquetes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes ALTER COLUMN id SET DEFAULT nextval('public.paquetes_id_seq'::regclass);


--
-- Name: pre_alerta_paquetes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alerta_paquetes ALTER COLUMN id SET DEFAULT nextval('public.pre_alerta_paquetes_id_seq'::regclass);


--
-- Name: pre_alertas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alertas ALTER COLUMN id SET DEFAULT nextval('public.pre_alertas_id_seq'::regclass);


--
-- Name: pre_factura_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items ALTER COLUMN id SET DEFAULT nextval('public.pre_factura_items_id_seq'::regclass);


--
-- Name: pre_facturas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_facturas ALTER COLUMN id SET DEFAULT nextval('public.pre_facturas_id_seq'::regclass);


--
-- Name: recibos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos ALTER COLUMN id SET DEFAULT nextval('public.recibos_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: tamano_cajas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tamano_cajas ALTER COLUMN id SET DEFAULT nextval('public.tamano_cajas_id_seq'::regclass);


--
-- Name: tipo_envios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_envios ALTER COLUMN id SET DEFAULT nextval('public.tipo_envios_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: venta_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venta_items ALTER COLUMN id SET DEFAULT nextval('public.venta_items_id_seq'::regclass);


--
-- Name: ventas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas ALTER COLUMN id SET DEFAULT nextval('public.ventas_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: aperturas_caja aperturas_caja_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aperturas_caja
    ADD CONSTRAINT aperturas_caja_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: carriers carriers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carriers
    ADD CONSTRAINT carriers_pkey PRIMARY KEY (id);


--
-- Name: categoria_precios categoria_precios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categoria_precios
    ADD CONSTRAINT categoria_precios_pkey PRIMARY KEY (id);


--
-- Name: cliente_sessions cliente_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente_sessions
    ADD CONSTRAINT cliente_sessions_pkey PRIMARY KEY (id);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);


--
-- Name: configuracions configuracions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracions
    ADD CONSTRAINT configuracions_pkey PRIMARY KEY (id);


--
-- Name: consignatarios consignatarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignatarios
    ADD CONSTRAINT consignatarios_pkey PRIMARY KEY (id);


--
-- Name: cotizacion_items cotizacion_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizacion_items
    ADD CONSTRAINT cotizacion_items_pkey PRIMARY KEY (id);


--
-- Name: cotizaciones cotizaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones
    ADD CONSTRAINT cotizaciones_pkey PRIMARY KEY (id);


--
-- Name: egresos_caja egresos_caja_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egresos_caja
    ADD CONSTRAINT egresos_caja_pkey PRIMARY KEY (id);


--
-- Name: empresa_manifiestos empresa_manifiestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresa_manifiestos
    ADD CONSTRAINT empresa_manifiestos_pkey PRIMARY KEY (id);


--
-- Name: empresas empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_pkey PRIMARY KEY (id);


--
-- Name: entrega_paquetes entrega_paquetes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_paquetes
    ADD CONSTRAINT entrega_paquetes_pkey PRIMARY KEY (id);


--
-- Name: entregas entregas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_pkey PRIMARY KEY (id);


--
-- Name: financiamiento_cuotas financiamiento_cuotas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamiento_cuotas
    ADD CONSTRAINT financiamiento_cuotas_pkey PRIMARY KEY (id);


--
-- Name: financiamientos financiamientos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamientos
    ADD CONSTRAINT financiamientos_pkey PRIMARY KEY (id);


--
-- Name: ingresos_caja ingresos_caja_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingresos_caja
    ADD CONSTRAINT ingresos_caja_pkey PRIMARY KEY (id);


--
-- Name: lugars lugars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lugars
    ADD CONSTRAINT lugars_pkey PRIMARY KEY (id);


--
-- Name: manifiestos manifiestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos
    ADD CONSTRAINT manifiestos_pkey PRIMARY KEY (id);


--
-- Name: nota_credito_items nota_credito_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_credito_items
    ADD CONSTRAINT nota_credito_items_pkey PRIMARY KEY (id);


--
-- Name: nota_debito_items nota_debito_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_debito_items
    ADD CONSTRAINT nota_debito_items_pkey PRIMARY KEY (id);


--
-- Name: notas_credito notas_credito_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_credito
    ADD CONSTRAINT notas_credito_pkey PRIMARY KEY (id);


--
-- Name: notas_debito notas_debito_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_debito
    ADD CONSTRAINT notas_debito_pkey PRIMARY KEY (id);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);


--
-- Name: paquetes paquetes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_pkey PRIMARY KEY (id);


--
-- Name: pre_alerta_paquetes pre_alerta_paquetes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alerta_paquetes
    ADD CONSTRAINT pre_alerta_paquetes_pkey PRIMARY KEY (id);


--
-- Name: pre_alertas pre_alertas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alertas
    ADD CONSTRAINT pre_alertas_pkey PRIMARY KEY (id);


--
-- Name: pre_factura_items pre_factura_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT pre_factura_items_pkey PRIMARY KEY (id);


--
-- Name: pre_facturas pre_facturas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_facturas
    ADD CONSTRAINT pre_facturas_pkey PRIMARY KEY (id);


--
-- Name: recibos recibos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos
    ADD CONSTRAINT recibos_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: tamano_cajas tamano_cajas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tamano_cajas
    ADD CONSTRAINT tamano_cajas_pkey PRIMARY KEY (id);


--
-- Name: tipo_envios tipo_envios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_envios
    ADD CONSTRAINT tipo_envios_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: venta_items venta_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venta_items
    ADD CONSTRAINT venta_items_pkey PRIMARY KEY (id);


--
-- Name: ventas ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);


--
-- Name: idx_fin_cuotas_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_fin_cuotas_unique ON public.financiamiento_cuotas USING btree (financiamiento_id, numero_cuota);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_aperturas_caja_on_abierta_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aperturas_caja_on_abierta_por_id ON public.aperturas_caja USING btree (abierta_por_id);


--
-- Name: index_aperturas_caja_on_cerrada_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aperturas_caja_on_cerrada_por_id ON public.aperturas_caja USING btree (cerrada_por_id);


--
-- Name: index_aperturas_caja_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aperturas_caja_on_estado ON public.aperturas_caja USING btree (estado);


--
-- Name: index_aperturas_caja_on_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aperturas_caja_on_fecha ON public.aperturas_caja USING btree (fecha);


--
-- Name: index_aperturas_caja_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aperturas_caja_on_numero ON public.aperturas_caja USING btree (numero);


--
-- Name: index_cliente_sessions_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cliente_sessions_on_cliente_id ON public.cliente_sessions USING btree (cliente_id);


--
-- Name: index_clientes_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clientes_on_activo ON public.clientes USING btree (activo);


--
-- Name: index_clientes_on_categoria_precio_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clientes_on_categoria_precio_id ON public.clientes USING btree (categoria_precio_id);


--
-- Name: index_clientes_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clientes_on_codigo ON public.clientes USING btree (codigo);


--
-- Name: index_clientes_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clientes_on_email ON public.clientes USING btree (email);


--
-- Name: index_configuracions_on_clave; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_configuracions_on_clave ON public.configuracions USING btree (clave);


--
-- Name: index_cotizacion_items_on_cotizacion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizacion_items_on_cotizacion_id ON public.cotizacion_items USING btree (cotizacion_id);


--
-- Name: index_cotizacion_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizacion_items_on_paquete_id ON public.cotizacion_items USING btree (paquete_id);


--
-- Name: index_cotizaciones_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizaciones_on_cliente_id ON public.cotizaciones USING btree (cliente_id);


--
-- Name: index_cotizaciones_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizaciones_on_creado_por_id ON public.cotizaciones USING btree (creado_por_id);


--
-- Name: index_cotizaciones_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizaciones_on_estado ON public.cotizaciones USING btree (estado);


--
-- Name: index_cotizaciones_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cotizaciones_on_numero ON public.cotizaciones USING btree (numero);


--
-- Name: index_cotizaciones_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cotizaciones_on_venta_id ON public.cotizaciones USING btree (venta_id);


--
-- Name: index_egresos_caja_on_apertura_caja_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_egresos_caja_on_apertura_caja_id ON public.egresos_caja USING btree (apertura_caja_id);


--
-- Name: index_egresos_caja_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_egresos_caja_on_numero ON public.egresos_caja USING btree (numero);


--
-- Name: index_egresos_caja_on_registrado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_egresos_caja_on_registrado_por_id ON public.egresos_caja USING btree (registrado_por_id);


--
-- Name: index_entrega_paquetes_on_entrega_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entrega_paquetes_on_entrega_id ON public.entrega_paquetes USING btree (entrega_id);


--
-- Name: index_entrega_paquetes_on_entrega_id_and_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entrega_paquetes_on_entrega_id_and_paquete_id ON public.entrega_paquetes USING btree (entrega_id, paquete_id);


--
-- Name: index_entrega_paquetes_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entrega_paquetes_on_paquete_id ON public.entrega_paquetes USING btree (paquete_id);


--
-- Name: index_entregas_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entregas_on_cliente_id ON public.entregas USING btree (cliente_id);


--
-- Name: index_entregas_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entregas_on_creado_por_id ON public.entregas USING btree (creado_por_id);


--
-- Name: index_entregas_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entregas_on_estado ON public.entregas USING btree (estado);


--
-- Name: index_entregas_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entregas_on_numero ON public.entregas USING btree (numero);


--
-- Name: index_entregas_on_repartidor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entregas_on_repartidor_id ON public.entregas USING btree (repartidor_id);


--
-- Name: index_entregas_on_tipo_entrega; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entregas_on_tipo_entrega ON public.entregas USING btree (tipo_entrega);


--
-- Name: index_financiamiento_cuotas_on_financiamiento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamiento_cuotas_on_financiamiento_id ON public.financiamiento_cuotas USING btree (financiamiento_id);


--
-- Name: index_financiamiento_cuotas_on_pago_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamiento_cuotas_on_pago_id ON public.financiamiento_cuotas USING btree (pago_id);


--
-- Name: index_financiamientos_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamientos_on_cliente_id ON public.financiamientos USING btree (cliente_id);


--
-- Name: index_financiamientos_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamientos_on_creado_por_id ON public.financiamientos USING btree (creado_por_id);


--
-- Name: index_financiamientos_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamientos_on_estado ON public.financiamientos USING btree (estado);


--
-- Name: index_financiamientos_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_financiamientos_on_numero ON public.financiamientos USING btree (numero);


--
-- Name: index_financiamientos_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_financiamientos_on_venta_id ON public.financiamientos USING btree (venta_id);


--
-- Name: index_ingresos_caja_on_apertura_caja_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ingresos_caja_on_apertura_caja_id ON public.ingresos_caja USING btree (apertura_caja_id);


--
-- Name: index_ingresos_caja_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ingresos_caja_on_numero ON public.ingresos_caja USING btree (numero);


--
-- Name: index_ingresos_caja_on_registrado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ingresos_caja_on_registrado_por_id ON public.ingresos_caja USING btree (registrado_por_id);


--
-- Name: index_manifiestos_on_empresa_manifiesto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiestos_on_empresa_manifiesto_id ON public.manifiestos USING btree (empresa_manifiesto_id);


--
-- Name: index_manifiestos_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiestos_on_estado ON public.manifiestos USING btree (estado);


--
-- Name: index_manifiestos_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_manifiestos_on_numero ON public.manifiestos USING btree (numero);


--
-- Name: index_manifiestos_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiestos_on_user_id ON public.manifiestos USING btree (user_id);


--
-- Name: index_nota_credito_items_on_nota_credito_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nota_credito_items_on_nota_credito_id ON public.nota_credito_items USING btree (nota_credito_id);


--
-- Name: index_nota_credito_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nota_credito_items_on_paquete_id ON public.nota_credito_items USING btree (paquete_id);


--
-- Name: index_nota_debito_items_on_nota_debito_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nota_debito_items_on_nota_debito_id ON public.nota_debito_items USING btree (nota_debito_id);


--
-- Name: index_nota_debito_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nota_debito_items_on_paquete_id ON public.nota_debito_items USING btree (paquete_id);


--
-- Name: index_notas_credito_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_credito_on_cliente_id ON public.notas_credito USING btree (cliente_id);


--
-- Name: index_notas_credito_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_credito_on_creado_por_id ON public.notas_credito USING btree (creado_por_id);


--
-- Name: index_notas_credito_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_credito_on_estado ON public.notas_credito USING btree (estado);


--
-- Name: index_notas_credito_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notas_credito_on_numero ON public.notas_credito USING btree (numero);


--
-- Name: index_notas_credito_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_credito_on_venta_id ON public.notas_credito USING btree (venta_id);


--
-- Name: index_notas_debito_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_debito_on_cliente_id ON public.notas_debito USING btree (cliente_id);


--
-- Name: index_notas_debito_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_debito_on_creado_por_id ON public.notas_debito USING btree (creado_por_id);


--
-- Name: index_notas_debito_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_debito_on_estado ON public.notas_debito USING btree (estado);


--
-- Name: index_notas_debito_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notas_debito_on_numero ON public.notas_debito USING btree (numero);


--
-- Name: index_notas_debito_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notas_debito_on_venta_id ON public.notas_debito USING btree (venta_id);


--
-- Name: index_pagos_on_apertura_caja_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagos_on_apertura_caja_id ON public.pagos USING btree (apertura_caja_id);


--
-- Name: index_pagos_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagos_on_cliente_id ON public.pagos USING btree (cliente_id);


--
-- Name: index_pagos_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagos_on_estado ON public.pagos USING btree (estado);


--
-- Name: index_pagos_on_registrado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagos_on_registrado_por_id ON public.pagos USING btree (registrado_por_id);


--
-- Name: index_pagos_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagos_on_venta_id ON public.pagos USING btree (venta_id);


--
-- Name: index_paquetes_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_cliente_id ON public.paquetes USING btree (cliente_id);


--
-- Name: index_paquetes_on_entrega_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_entrega_id ON public.paquetes USING btree (entrega_id);


--
-- Name: index_paquetes_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_estado ON public.paquetes USING btree (estado);


--
-- Name: index_paquetes_on_guia; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_paquetes_on_guia ON public.paquetes USING btree (guia);


--
-- Name: index_paquetes_on_manifiesto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_manifiesto_id ON public.paquetes USING btree (manifiesto_id);


--
-- Name: index_paquetes_on_pre_factura_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_pre_factura_id ON public.paquetes USING btree (pre_factura_id);


--
-- Name: index_paquetes_on_tipo_envio_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tipo_envio_id ON public.paquetes USING btree (tipo_envio_id);


--
-- Name: index_paquetes_on_tracking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tracking ON public.paquetes USING btree (tracking);


--
-- Name: index_paquetes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_user_id ON public.paquetes USING btree (user_id);


--
-- Name: index_paquetes_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_venta_id ON public.paquetes USING btree (venta_id);


--
-- Name: index_pre_alerta_paquetes_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alerta_paquetes_on_paquete_id ON public.pre_alerta_paquetes USING btree (paquete_id);


--
-- Name: index_pre_alerta_paquetes_on_pre_alerta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alerta_paquetes_on_pre_alerta_id ON public.pre_alerta_paquetes USING btree (pre_alerta_id);


--
-- Name: index_pre_alerta_paquetes_on_pre_alerta_id_and_tracking; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pre_alerta_paquetes_on_pre_alerta_id_and_tracking ON public.pre_alerta_paquetes USING btree (pre_alerta_id, tracking);


--
-- Name: index_pre_alerta_paquetes_on_tracking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alerta_paquetes_on_tracking ON public.pre_alerta_paquetes USING btree (tracking);


--
-- Name: index_pre_alertas_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alertas_on_cliente_id ON public.pre_alertas USING btree (cliente_id);


--
-- Name: index_pre_alertas_on_creado_por_tipo_and_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alertas_on_creado_por_tipo_and_creado_por_id ON public.pre_alertas USING btree (creado_por_tipo, creado_por_id);


--
-- Name: index_pre_alertas_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alertas_on_deleted_at ON public.pre_alertas USING btree (deleted_at);


--
-- Name: index_pre_alertas_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alertas_on_estado ON public.pre_alertas USING btree (estado);


--
-- Name: index_pre_alertas_on_numero_documento; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pre_alertas_on_numero_documento ON public.pre_alertas USING btree (numero_documento);


--
-- Name: index_pre_alertas_on_tipo_envio_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_alertas_on_tipo_envio_id ON public.pre_alertas USING btree (tipo_envio_id);


--
-- Name: index_pre_factura_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_paquete_id ON public.pre_factura_items USING btree (paquete_id);


--
-- Name: index_pre_factura_items_on_pre_factura_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_pre_factura_id ON public.pre_factura_items USING btree (pre_factura_id);


--
-- Name: index_pre_facturas_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_facturas_on_cliente_id ON public.pre_facturas USING btree (cliente_id);


--
-- Name: index_pre_facturas_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_facturas_on_creado_por_id ON public.pre_facturas USING btree (creado_por_id);


--
-- Name: index_pre_facturas_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_facturas_on_estado ON public.pre_facturas USING btree (estado);


--
-- Name: index_pre_facturas_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pre_facturas_on_numero ON public.pre_facturas USING btree (numero);


--
-- Name: index_recibos_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recibos_on_cliente_id ON public.recibos USING btree (cliente_id);


--
-- Name: index_recibos_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recibos_on_numero ON public.recibos USING btree (numero);


--
-- Name: index_recibos_on_pago_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recibos_on_pago_id ON public.recibos USING btree (pago_id);


--
-- Name: index_recibos_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recibos_on_venta_id ON public.recibos USING btree (venta_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_activo ON public.users USING btree (activo);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_rol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_rol ON public.users USING btree (rol);


--
-- Name: index_users_on_ubicacion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_ubicacion ON public.users USING btree (ubicacion);


--
-- Name: index_venta_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_venta_items_on_paquete_id ON public.venta_items USING btree (paquete_id);


--
-- Name: index_venta_items_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_venta_items_on_venta_id ON public.venta_items USING btree (venta_id);


--
-- Name: index_ventas_on_cliente_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ventas_on_cliente_id ON public.ventas USING btree (cliente_id);


--
-- Name: index_ventas_on_creado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ventas_on_creado_por_id ON public.ventas USING btree (creado_por_id);


--
-- Name: index_ventas_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ventas_on_estado ON public.ventas USING btree (estado);


--
-- Name: index_ventas_on_financiamiento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ventas_on_financiamiento_id ON public.ventas USING btree (financiamiento_id);


--
-- Name: index_ventas_on_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ventas_on_numero ON public.ventas USING btree (numero);


--
-- Name: index_ventas_on_pre_factura_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ventas_on_pre_factura_id ON public.ventas USING btree (pre_factura_id);


--
-- Name: pre_alerta_paquetes fk_rails_057a3229ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alerta_paquetes
    ADD CONSTRAINT fk_rails_057a3229ab FOREIGN KEY (pre_alerta_id) REFERENCES public.pre_alertas(id);


--
-- Name: recibos fk_rails_0984618e5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos
    ADD CONSTRAINT fk_rails_0984618e5f FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: financiamientos fk_rails_0b0ebfbfc1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamientos
    ADD CONSTRAINT fk_rails_0b0ebfbfc1 FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: cotizaciones fk_rails_0bf5758b31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones
    ADD CONSTRAINT fk_rails_0bf5758b31 FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: pagos fk_rails_0cf0314e3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_rails_0cf0314e3c FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: paquetes fk_rails_0ded221a2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_0ded221a2c FOREIGN KEY (manifiesto_id) REFERENCES public.manifiestos(id);


--
-- Name: ventas fk_rails_0f15e6f8ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_rails_0f15e6f8ea FOREIGN KEY (pre_factura_id) REFERENCES public.pre_facturas(id);


--
-- Name: notas_debito fk_rails_10ff795c5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_debito
    ADD CONSTRAINT fk_rails_10ff795c5f FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: paquetes fk_rails_136d15a3bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_136d15a3bf FOREIGN KEY (tipo_envio_id) REFERENCES public.tipo_envios(id);


--
-- Name: cotizacion_items fk_rails_1551bf9841; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizacion_items
    ADD CONSTRAINT fk_rails_1551bf9841 FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: pre_facturas fk_rails_16be8ee9dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_facturas
    ADD CONSTRAINT fk_rails_16be8ee9dd FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: nota_debito_items fk_rails_1b6eb53363; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_debito_items
    ADD CONSTRAINT fk_rails_1b6eb53363 FOREIGN KEY (nota_debito_id) REFERENCES public.notas_debito(id);


--
-- Name: pre_alertas fk_rails_1c36982d64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alertas
    ADD CONSTRAINT fk_rails_1c36982d64 FOREIGN KEY (tipo_envio_id) REFERENCES public.tipo_envios(id);


--
-- Name: clientes fk_rails_2ead6dd043; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT fk_rails_2ead6dd043 FOREIGN KEY (categoria_precio_id) REFERENCES public.categoria_precios(id);


--
-- Name: recibos fk_rails_2f5aebc4a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos
    ADD CONSTRAINT fk_rails_2f5aebc4a3 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: entrega_paquetes fk_rails_349a6780c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_paquetes
    ADD CONSTRAINT fk_rails_349a6780c3 FOREIGN KEY (entrega_id) REFERENCES public.entregas(id);


--
-- Name: pre_factura_items fk_rails_3838674e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT fk_rails_3838674e35 FOREIGN KEY (pre_factura_id) REFERENCES public.pre_facturas(id);


--
-- Name: recibos fk_rails_43e602f4c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos
    ADD CONSTRAINT fk_rails_43e602f4c1 FOREIGN KEY (pago_id) REFERENCES public.pagos(id);


--
-- Name: pagos fk_rails_44e0f08817; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_rails_44e0f08817 FOREIGN KEY (registrado_por_id) REFERENCES public.users(id);


--
-- Name: pre_facturas fk_rails_4771dee5f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_facturas
    ADD CONSTRAINT fk_rails_4771dee5f9 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: cotizaciones fk_rails_54a36869dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones
    ADD CONSTRAINT fk_rails_54a36869dd FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: entregas fk_rails_5acc57e1ba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT fk_rails_5acc57e1ba FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_5b61a4fa9e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_5b61a4fa9e FOREIGN KEY (entrega_id) REFERENCES public.entregas(id);


--
-- Name: venta_items fk_rails_5dcbb32fc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venta_items
    ADD CONSTRAINT fk_rails_5dcbb32fc2 FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: aperturas_caja fk_rails_684d1326d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aperturas_caja
    ADD CONSTRAINT fk_rails_684d1326d2 FOREIGN KEY (cerrada_por_id) REFERENCES public.users(id);


--
-- Name: aperturas_caja fk_rails_697c60a45e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aperturas_caja
    ADD CONSTRAINT fk_rails_697c60a45e FOREIGN KEY (abierta_por_id) REFERENCES public.users(id);


--
-- Name: notas_debito fk_rails_69ea87712f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_debito
    ADD CONSTRAINT fk_rails_69ea87712f FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_6fd48bb9d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_6fd48bb9d4 FOREIGN KEY (pre_factura_id) REFERENCES public.pre_facturas(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: entregas fk_rails_7ee1ee7e61; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT fk_rails_7ee1ee7e61 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: egresos_caja fk_rails_7fa3410cc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egresos_caja
    ADD CONSTRAINT fk_rails_7fa3410cc4 FOREIGN KEY (registrado_por_id) REFERENCES public.users(id);


--
-- Name: nota_credito_items fk_rails_80067ecece; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_credito_items
    ADD CONSTRAINT fk_rails_80067ecece FOREIGN KEY (nota_credito_id) REFERENCES public.notas_credito(id);


--
-- Name: pre_alertas fk_rails_800e05e6d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alertas
    ADD CONSTRAINT fk_rails_800e05e6d2 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: notas_credito fk_rails_81056e6cc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_credito
    ADD CONSTRAINT fk_rails_81056e6cc2 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: financiamientos fk_rails_8536c7615a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamientos
    ADD CONSTRAINT fk_rails_8536c7615a FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: egresos_caja fk_rails_8acd1a6009; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egresos_caja
    ADD CONSTRAINT fk_rails_8acd1a6009 FOREIGN KEY (apertura_caja_id) REFERENCES public.aperturas_caja(id);


--
-- Name: paquetes fk_rails_8bb0460b57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_8bb0460b57 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notas_credito fk_rails_8c7b98254b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_credito
    ADD CONSTRAINT fk_rails_8c7b98254b FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: notas_debito fk_rails_959289c6e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_debito
    ADD CONSTRAINT fk_rails_959289c6e4 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: pagos fk_rails_99c87016a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_rails_99c87016a7 FOREIGN KEY (apertura_caja_id) REFERENCES public.aperturas_caja(id);


--
-- Name: entregas fk_rails_9f9db40a27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT fk_rails_9f9db40a27 FOREIGN KEY (repartidor_id) REFERENCES public.users(id);


--
-- Name: cotizaciones fk_rails_a6a86a6366; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones
    ADD CONSTRAINT fk_rails_a6a86a6366 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: ventas fk_rails_a70a7aa019; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_rails_a70a7aa019 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: entrega_paquetes fk_rails_a710547135; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_paquetes
    ADD CONSTRAINT fk_rails_a710547135 FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: manifiestos fk_rails_a737f28500; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos
    ADD CONSTRAINT fk_rails_a737f28500 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ingresos_caja fk_rails_ac3bbd36d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingresos_caja
    ADD CONSTRAINT fk_rails_ac3bbd36d7 FOREIGN KEY (registrado_por_id) REFERENCES public.users(id);


--
-- Name: cliente_sessions fk_rails_ac937f4aa8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente_sessions
    ADD CONSTRAINT fk_rails_ac937f4aa8 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: ingresos_caja fk_rails_aca2db36e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingresos_caja
    ADD CONSTRAINT fk_rails_aca2db36e1 FOREIGN KEY (apertura_caja_id) REFERENCES public.aperturas_caja(id);


--
-- Name: nota_credito_items fk_rails_be235163df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_credito_items
    ADD CONSTRAINT fk_rails_be235163df FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: financiamientos fk_rails_c368bc42b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamientos
    ADD CONSTRAINT fk_rails_c368bc42b3 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: pagos fk_rails_c3e774b6aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_rails_c3e774b6aa FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: venta_items fk_rails_c4435e5926; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venta_items
    ADD CONSTRAINT fk_rails_c4435e5926 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: pre_factura_items fk_rails_ca1057ddd4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT fk_rails_ca1057ddd4 FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: cotizacion_items fk_rails_cee3403c1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizacion_items
    ADD CONSTRAINT fk_rails_cee3403c1e FOREIGN KEY (cotizacion_id) REFERENCES public.cotizaciones(id);


--
-- Name: notas_credito fk_rails_d13d5954e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notas_credito
    ADD CONSTRAINT fk_rails_d13d5954e1 FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: ventas fk_rails_d3a4e528c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_rails_d3a4e528c1 FOREIGN KEY (financiamiento_id) REFERENCES public.financiamientos(id);


--
-- Name: ventas fk_rails_d8655b3ca7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_rails_d8655b3ca7 FOREIGN KEY (creado_por_id) REFERENCES public.users(id);


--
-- Name: pre_alerta_paquetes fk_rails_d98af13fbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_alerta_paquetes
    ADD CONSTRAINT fk_rails_d98af13fbd FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: manifiestos fk_rails_e55f679c59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos
    ADD CONSTRAINT fk_rails_e55f679c59 FOREIGN KEY (empresa_manifiesto_id) REFERENCES public.empresa_manifiestos(id);


--
-- Name: nota_debito_items fk_rails_e8aa65ac3d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_debito_items
    ADD CONSTRAINT fk_rails_e8aa65ac3d FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: financiamiento_cuotas fk_rails_ee080782c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamiento_cuotas
    ADD CONSTRAINT fk_rails_ee080782c8 FOREIGN KEY (financiamiento_id) REFERENCES public.financiamientos(id);


--
-- Name: paquetes fk_rails_eeda9f916d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_eeda9f916d FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: financiamiento_cuotas fk_rails_f9c6e674df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamiento_cuotas
    ADD CONSTRAINT fk_rails_f9c6e674df FOREIGN KEY (pago_id) REFERENCES public.pagos(id);


--
-- Name: paquetes fk_rails_fd73715478; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_fd73715478 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260412060700'),
('20260412060600'),
('20260412060500'),
('20260412060400'),
('20260412060300'),
('20260412060200'),
('20260412060100'),
('20260412060000'),
('20260412050500'),
('20260412050400'),
('20260412050300'),
('20260412050200'),
('20260412050100'),
('20260412050000'),
('20260412040000'),
('20260412021926'),
('20260412011407'),
('20260412011406'),
('20260412011405'),
('20260412011404'),
('20260412011403'),
('20260412011402'),
('20260412011401'),
('20260411211424'),
('20260411211423'),
('20260411211422'),
('20260411211421'),
('20260411211420'),
('20260411211419'),
('20260411211418'),
('20260407194516'),
('20260406164622'),
('20260405235030'),
('20260404214941'),
('20260404205022'),
('20260404091042'),
('20260404060005'),
('20260404060004'),
('20260404060003'),
('20260404060002'),
('20260404060001'),
('20260404051642'),
('20260404051355'),
('20260404051336'),
('20260331051755'),
('20260331051350'),
('20260331051349'),
('20260331051348'),
('20260331051347'),
('20260331051341'),
('20260331051340'),
('20260331051339'),
('20260331051338'),
('20260331042739'),
('20260331042618'),
('20260331042617');

