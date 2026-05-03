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
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    destination_city character varying,
    destination_country character varying DEFAULT 'Honduras'::character varying,
    activo boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agents_id_seq OWNED BY public.agents.id;


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
    notificar_facturas boolean DEFAULT true NOT NULL,
    tema character varying,
    notas_caja text,
    notas_sac text
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
-- Name: ep_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ep_counters (
    id bigint NOT NULL,
    anio integer NOT NULL,
    sucursal_id bigint NOT NULL,
    proveedor_id bigint NOT NULL,
    last_value integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ep_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ep_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ep_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ep_counters_id_seq OWNED BY public.ep_counters.id;


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
-- Name: manifiesto_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifiesto_counters (
    id bigint NOT NULL,
    sucursal_id bigint NOT NULL,
    anio integer NOT NULL,
    ultimo_numero integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: manifiesto_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manifiesto_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manifiesto_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manifiesto_counters_id_seq OWNED BY public.manifiesto_counters.id;


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
    updated_at timestamp(6) without time zone NOT NULL,
    sucursal_origen_id bigint
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
-- Name: motivos_retencion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motivos_retencion (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    descripcion text,
    "position" integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motivos_retencion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motivos_retencion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motivos_retencion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motivos_retencion_id_seq OWNED BY public.motivos_retencion.id;


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
-- Name: numero_recepcion_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.numero_recepcion_counters (
    id bigint NOT NULL,
    sucursal_id bigint NOT NULL,
    anio integer NOT NULL,
    ultimo_numero integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: numero_recepcion_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.numero_recepcion_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: numero_recepcion_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.numero_recepcion_counters_id_seq OWNED BY public.numero_recepcion_counters.id;


--
-- Name: numero_recepcion_rh_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.numero_recepcion_rh_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: numero_recepcion_rm_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.numero_recepcion_rm_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: numero_recepcion_rs_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.numero_recepcion_rs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


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
-- Name: paquete_motivos_retencion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paquete_motivos_retencion (
    id bigint NOT NULL,
    paquete_id bigint NOT NULL,
    motivo_retencion_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: paquete_motivos_retencion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.paquete_motivos_retencion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: paquete_motivos_retencion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.paquete_motivos_retencion_id_seq OWNED BY public.paquete_motivos_retencion.id;


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
    entrega_id bigint,
    sucursal_id bigint,
    numero_recepcion character varying,
    fecha_disponible timestamp(6) without time zone,
    warehouse_receipt_id bigint,
    fecha_solicito_recolecta timestamp(6) without time zone,
    fecha_pre_alerta timestamp(6) without time zone,
    fecha_empacado timestamp(6) without time zone,
    fecha_aduana timestamp(6) without time zone,
    fecha_consolidando timestamp(6) without time zone,
    fecha_en_reparto timestamp(6) without time zone,
    fecha_entregado timestamp(6) without time zone,
    fecha_posible_entrega timestamp(6) without time zone,
    fecha_recibido_miami_by_user_id bigint,
    fecha_enviado_by_user_id bigint,
    fecha_disponible_by_user_id bigint,
    fecha_solicito_recolecta_by_user_id bigint,
    fecha_pre_alerta_by_user_id bigint,
    fecha_empacado_by_user_id bigint,
    fecha_aduana_by_user_id bigint,
    fecha_consolidando_by_user_id bigint,
    fecha_en_reparto_by_user_id bigint,
    fecha_entregado_by_user_id bigint,
    fecha_posible_entrega_by_user_id bigint,
    sucursal_actual_id bigint,
    sub_localidad_actual_id bigint,
    recolecta_solicitada boolean DEFAULT false NOT NULL,
    recolecta_monto numeric(10,2),
    recolecta_moneda character varying DEFAULT 'USD'::character varying,
    tracking_secundario character varying,
    notas_consolidacion text,
    notas_retencion text,
    notas_al_cliente text,
    proveedor_id bigint,
    tercero_id bigint,
    tarifa_recolecta_id bigint
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
-- Name: plantillas_notas_cliente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plantillas_notas_cliente (
    id bigint NOT NULL,
    titulo character varying NOT NULL,
    texto text NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: plantillas_notas_cliente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plantillas_notas_cliente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plantillas_notas_cliente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plantillas_notas_cliente_id_seq OWNED BY public.plantillas_notas_cliente.id;


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
    proveedor character varying,
    finalizado boolean DEFAULT false NOT NULL,
    historial text
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
    updated_at timestamp(6) without time zone NOT NULL,
    origen character varying DEFAULT 'manual'::character varying NOT NULL,
    tarifa_recolecta_id bigint,
    servicio_extra_id bigint
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
-- Name: proveedores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proveedores (
    id bigint NOT NULL,
    nombre character varying NOT NULL,
    codigo character varying(8) NOT NULL,
    tipo character varying DEFAULT 'comercio'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: proveedores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.proveedores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proveedores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.proveedores_id_seq OWNED BY public.proveedores.id;


--
-- Name: rc_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rc_counters (
    id bigint NOT NULL,
    anio integer NOT NULL,
    sucursal_id bigint NOT NULL,
    proveedor_id bigint NOT NULL,
    last_value integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rc_counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rc_counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rc_counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rc_counters_id_seq OWNED BY public.rc_counters.id;


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
-- Name: reempaques; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reempaques (
    id bigint NOT NULL,
    paquete_id bigint NOT NULL,
    hecho_por_id bigint,
    tarea_id bigint,
    alto_antes numeric(8,2),
    largo_antes numeric(8,2),
    ancho_antes numeric(8,2),
    peso_antes numeric(10,2),
    alto_despues numeric(8,2),
    largo_despues numeric(8,2),
    ancho_despues numeric(8,2),
    peso_despues numeric(10,2),
    notas text,
    realizado_en timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: reempaques_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reempaques_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reempaques_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reempaques_id_seq OWNED BY public.reempaques.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: servicios_extra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servicios_extra (
    id bigint NOT NULL,
    codigo character varying NOT NULL,
    descripcion character varying NOT NULL,
    costo numeric(10,2) DEFAULT 0.0 NOT NULL,
    precio_venta numeric(10,2) NOT NULL,
    moneda character varying DEFAULT 'USD'::character varying NOT NULL,
    precio_incluye_isv boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: servicios_extra_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.servicios_extra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servicios_extra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servicios_extra_id_seq OWNED BY public.servicios_extra.id;


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
-- Name: sub_localidades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sub_localidades (
    id bigint NOT NULL,
    sucursal_id bigint NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sub_localidades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sub_localidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sub_localidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sub_localidades_id_seq OWNED BY public.sub_localidades.id;


--
-- Name: sucursales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sucursales (
    id bigint NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    pais character varying,
    ubicacion character varying,
    codigo_recepcion_prefix character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    codigo_ep character varying(3)
);


--
-- Name: sucursales_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sucursales_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sucursales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sucursales_id_seq OWNED BY public.sucursales.id;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id bigint NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    tipo character varying DEFAULT 'comercio'::character varying NOT NULL,
    street_address character varying,
    city character varying,
    state character varying,
    postal_code character varying,
    country character varying DEFAULT 'USA'::character varying,
    activo boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: suppliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.suppliers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: suppliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.suppliers_id_seq OWNED BY public.suppliers.id;


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
-- Name: tareas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tareas (
    id bigint NOT NULL,
    paquete_id bigint NOT NULL,
    asignado_a_id bigint,
    completado_por_id bigint,
    titulo character varying NOT NULL,
    descripcion text,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    completada_en timestamp(6) without time zone,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tareas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tareas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tareas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tareas_id_seq OWNED BY public.tareas.id;


--
-- Name: tarifas_recolecta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tarifas_recolecta (
    id bigint NOT NULL,
    zona character varying NOT NULL,
    monto numeric(10,2) NOT NULL,
    moneda character varying DEFAULT 'USD'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tarifas_recolecta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tarifas_recolecta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tarifas_recolecta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tarifas_recolecta_id_seq OWNED BY public.tarifas_recolecta.id;


--
-- Name: terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms (
    id bigint NOT NULL,
    version character varying NOT NULL,
    language character varying NOT NULL,
    body text NOT NULL,
    effective_from date NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.terms_id_seq OWNED BY public.terms.id;


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
    activo boolean DEFAULT true NOT NULL,
    tema character varying,
    iniciales character varying(8)
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
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id bigint NOT NULL,
    whodunnit character varying,
    created_at timestamp(6) without time zone,
    item_id bigint NOT NULL,
    item_type character varying NOT NULL,
    event character varying NOT NULL,
    object text,
    object_changes text
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: warehouse_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.warehouse_receipts (
    id bigint NOT NULL,
    receipt_number character varying NOT NULL,
    issued_on date NOT NULL,
    printed_at timestamp(6) without time zone,
    printed_by_initials character varying,
    supplier_id bigint,
    consignee_id bigint,
    agent_id bigint,
    user_id bigint,
    pre_alerta_id bigint,
    sucursal_id bigint,
    service_code character varying,
    repackaging_type character varying,
    consolidation boolean DEFAULT false NOT NULL,
    declared_value_cents integer DEFAULT 0 NOT NULL,
    declared_value_currency character varying DEFAULT 'USD'::character varying NOT NULL,
    total_pieces integer DEFAULT 0 NOT NULL,
    total_weight_lb numeric(10,2) DEFAULT 0.0,
    total_volumetric_weight_lb numeric(10,2) DEFAULT 0.0,
    total_volume_cuft numeric(10,2) DEFAULT 0.0,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    terms_version character varying,
    notes_internal text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: warehouse_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.warehouse_receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: warehouse_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.warehouse_receipts_id_seq OWNED BY public.warehouse_receipts.id;


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
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


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
-- Name: entregas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas ALTER COLUMN id SET DEFAULT nextval('public.entregas_id_seq'::regclass);


--
-- Name: ep_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ep_counters ALTER COLUMN id SET DEFAULT nextval('public.ep_counters_id_seq'::regclass);


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
-- Name: manifiesto_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiesto_counters ALTER COLUMN id SET DEFAULT nextval('public.manifiesto_counters_id_seq'::regclass);


--
-- Name: manifiestos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos ALTER COLUMN id SET DEFAULT nextval('public.manifiestos_id_seq'::regclass);


--
-- Name: motivos_retencion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motivos_retencion ALTER COLUMN id SET DEFAULT nextval('public.motivos_retencion_id_seq'::regclass);


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
-- Name: numero_recepcion_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.numero_recepcion_counters ALTER COLUMN id SET DEFAULT nextval('public.numero_recepcion_counters_id_seq'::regclass);


--
-- Name: pagos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id SET DEFAULT nextval('public.pagos_id_seq'::regclass);


--
-- Name: paquete_motivos_retencion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquete_motivos_retencion ALTER COLUMN id SET DEFAULT nextval('public.paquete_motivos_retencion_id_seq'::regclass);


--
-- Name: paquetes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes ALTER COLUMN id SET DEFAULT nextval('public.paquetes_id_seq'::regclass);


--
-- Name: plantillas_notas_cliente id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plantillas_notas_cliente ALTER COLUMN id SET DEFAULT nextval('public.plantillas_notas_cliente_id_seq'::regclass);


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
-- Name: proveedores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores ALTER COLUMN id SET DEFAULT nextval('public.proveedores_id_seq'::regclass);


--
-- Name: rc_counters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rc_counters ALTER COLUMN id SET DEFAULT nextval('public.rc_counters_id_seq'::regclass);


--
-- Name: recibos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos ALTER COLUMN id SET DEFAULT nextval('public.recibos_id_seq'::regclass);


--
-- Name: reempaques id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reempaques ALTER COLUMN id SET DEFAULT nextval('public.reempaques_id_seq'::regclass);


--
-- Name: servicios_extra id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicios_extra ALTER COLUMN id SET DEFAULT nextval('public.servicios_extra_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: sub_localidades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sub_localidades ALTER COLUMN id SET DEFAULT nextval('public.sub_localidades_id_seq'::regclass);


--
-- Name: sucursales id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursales ALTER COLUMN id SET DEFAULT nextval('public.sucursales_id_seq'::regclass);


--
-- Name: suppliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN id SET DEFAULT nextval('public.suppliers_id_seq'::regclass);


--
-- Name: tamano_cajas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tamano_cajas ALTER COLUMN id SET DEFAULT nextval('public.tamano_cajas_id_seq'::regclass);


--
-- Name: tareas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas ALTER COLUMN id SET DEFAULT nextval('public.tareas_id_seq'::regclass);


--
-- Name: tarifas_recolecta id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifas_recolecta ALTER COLUMN id SET DEFAULT nextval('public.tarifas_recolecta_id_seq'::regclass);


--
-- Name: terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms ALTER COLUMN id SET DEFAULT nextval('public.terms_id_seq'::regclass);


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
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: warehouse_receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts ALTER COLUMN id SET DEFAULT nextval('public.warehouse_receipts_id_seq'::regclass);


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
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


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
-- Name: entregas entregas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_pkey PRIMARY KEY (id);


--
-- Name: ep_counters ep_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ep_counters
    ADD CONSTRAINT ep_counters_pkey PRIMARY KEY (id);


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
-- Name: manifiesto_counters manifiesto_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiesto_counters
    ADD CONSTRAINT manifiesto_counters_pkey PRIMARY KEY (id);


--
-- Name: manifiestos manifiestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos
    ADD CONSTRAINT manifiestos_pkey PRIMARY KEY (id);


--
-- Name: motivos_retencion motivos_retencion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motivos_retencion
    ADD CONSTRAINT motivos_retencion_pkey PRIMARY KEY (id);


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
-- Name: numero_recepcion_counters numero_recepcion_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.numero_recepcion_counters
    ADD CONSTRAINT numero_recepcion_counters_pkey PRIMARY KEY (id);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);


--
-- Name: paquete_motivos_retencion paquete_motivos_retencion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquete_motivos_retencion
    ADD CONSTRAINT paquete_motivos_retencion_pkey PRIMARY KEY (id);


--
-- Name: paquetes paquetes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_pkey PRIMARY KEY (id);


--
-- Name: plantillas_notas_cliente plantillas_notas_cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plantillas_notas_cliente
    ADD CONSTRAINT plantillas_notas_cliente_pkey PRIMARY KEY (id);


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
-- Name: proveedores proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);


--
-- Name: rc_counters rc_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rc_counters
    ADD CONSTRAINT rc_counters_pkey PRIMARY KEY (id);


--
-- Name: recibos recibos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recibos
    ADD CONSTRAINT recibos_pkey PRIMARY KEY (id);


--
-- Name: reempaques reempaques_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reempaques
    ADD CONSTRAINT reempaques_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: servicios_extra servicios_extra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicios_extra
    ADD CONSTRAINT servicios_extra_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sub_localidades sub_localidades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sub_localidades
    ADD CONSTRAINT sub_localidades_pkey PRIMARY KEY (id);


--
-- Name: sucursales sucursales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursales
    ADD CONSTRAINT sucursales_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: tamano_cajas tamano_cajas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tamano_cajas
    ADD CONSTRAINT tamano_cajas_pkey PRIMARY KEY (id);


--
-- Name: tareas tareas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT tareas_pkey PRIMARY KEY (id);


--
-- Name: tarifas_recolecta tarifas_recolecta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifas_recolecta
    ADD CONSTRAINT tarifas_recolecta_pkey PRIMARY KEY (id);


--
-- Name: terms terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_pkey PRIMARY KEY (id);


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
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: warehouse_receipts warehouse_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT warehouse_receipts_pkey PRIMARY KEY (id);


--
-- Name: idx_ep_counter_combo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ep_counter_combo ON public.ep_counters USING btree (anio, sucursal_id, proveedor_id);


--
-- Name: idx_fin_cuotas_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_fin_cuotas_unique ON public.financiamiento_cuotas USING btree (financiamiento_id, numero_cuota);


--
-- Name: idx_manifiesto_counters_sucursal_anio; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_manifiesto_counters_sucursal_anio ON public.manifiesto_counters USING btree (sucursal_id, anio);


--
-- Name: idx_paquete_motivos_retencion_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_paquete_motivos_retencion_pair ON public.paquete_motivos_retencion USING btree (paquete_id, motivo_retencion_id);


--
-- Name: idx_paquetes_warehouse_receipt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_paquetes_warehouse_receipt ON public.paquetes USING btree (warehouse_receipt_id);


--
-- Name: idx_rc_counter_combo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rc_counter_combo ON public.rc_counters USING btree (anio, sucursal_id, proveedor_id);


--
-- Name: idx_recepcion_counters_sucursal_anio; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_recepcion_counters_sucursal_anio ON public.numero_recepcion_counters USING btree (sucursal_id, anio);


--
-- Name: idx_sub_localidades_sucursal_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_sub_localidades_sucursal_codigo ON public.sub_localidades USING btree (sucursal_id, codigo);


--
-- Name: idx_terms_version_language; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_terms_version_language ON public.terms USING btree (version, language);


--
-- Name: idx_wr_receipt_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_wr_receipt_number ON public.warehouse_receipts USING btree (receipt_number);


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
-- Name: index_agents_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_activo ON public.agents USING btree (activo);


--
-- Name: index_agents_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_codigo ON public.agents USING btree (codigo);


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
-- Name: index_ep_counters_on_proveedor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ep_counters_on_proveedor_id ON public.ep_counters USING btree (proveedor_id);


--
-- Name: index_ep_counters_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ep_counters_on_sucursal_id ON public.ep_counters USING btree (sucursal_id);


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
-- Name: index_manifiesto_counters_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiesto_counters_on_sucursal_id ON public.manifiesto_counters USING btree (sucursal_id);


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
-- Name: index_manifiestos_on_sucursal_origen_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiestos_on_sucursal_origen_id ON public.manifiestos USING btree (sucursal_origen_id);


--
-- Name: index_manifiestos_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifiestos_on_user_id ON public.manifiestos USING btree (user_id);


--
-- Name: index_motivos_retencion_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motivos_retencion_on_activo ON public.motivos_retencion USING btree (activo);


--
-- Name: index_motivos_retencion_on_nombre; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_motivos_retencion_on_nombre ON public.motivos_retencion USING btree (nombre);


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
-- Name: index_numero_recepcion_counters_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_numero_recepcion_counters_on_sucursal_id ON public.numero_recepcion_counters USING btree (sucursal_id);


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
-- Name: index_paquete_motivos_retencion_on_motivo_retencion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquete_motivos_retencion_on_motivo_retencion_id ON public.paquete_motivos_retencion USING btree (motivo_retencion_id);


--
-- Name: index_paquete_motivos_retencion_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquete_motivos_retencion_on_paquete_id ON public.paquete_motivos_retencion USING btree (paquete_id);


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
-- Name: index_paquetes_on_fecha_disponible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_fecha_disponible ON public.paquetes USING btree (fecha_disponible);


--
-- Name: index_paquetes_on_guia; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_paquetes_on_guia ON public.paquetes USING btree (guia);


--
-- Name: index_paquetes_on_manifiesto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_manifiesto_id ON public.paquetes USING btree (manifiesto_id);


--
-- Name: index_paquetes_on_numero_recepcion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_numero_recepcion ON public.paquetes USING btree (numero_recepcion);


--
-- Name: index_paquetes_on_numero_recepcion_caja; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_paquetes_on_numero_recepcion_caja ON public.paquetes USING btree (numero_recepcion, numero_caja);


--
-- Name: index_paquetes_on_pre_factura_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_pre_factura_id ON public.paquetes USING btree (pre_factura_id);


--
-- Name: index_paquetes_on_proveedor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_proveedor_id ON public.paquetes USING btree (proveedor_id);


--
-- Name: index_paquetes_on_sub_localidad_actual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_sub_localidad_actual_id ON public.paquetes USING btree (sub_localidad_actual_id);


--
-- Name: index_paquetes_on_sucursal_actual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_sucursal_actual_id ON public.paquetes USING btree (sucursal_actual_id);


--
-- Name: index_paquetes_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_sucursal_id ON public.paquetes USING btree (sucursal_id);


--
-- Name: index_paquetes_on_tarifa_recolecta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tarifa_recolecta_id ON public.paquetes USING btree (tarifa_recolecta_id);


--
-- Name: index_paquetes_on_tercero_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tercero_id ON public.paquetes USING btree (tercero_id);


--
-- Name: index_paquetes_on_tipo_envio_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tipo_envio_id ON public.paquetes USING btree (tipo_envio_id);


--
-- Name: index_paquetes_on_tracking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tracking ON public.paquetes USING btree (tracking);


--
-- Name: index_paquetes_on_tracking_secundario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_tracking_secundario ON public.paquetes USING btree (tracking_secundario);


--
-- Name: index_paquetes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_user_id ON public.paquetes USING btree (user_id);


--
-- Name: index_paquetes_on_venta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_paquetes_on_venta_id ON public.paquetes USING btree (venta_id);


--
-- Name: index_plantillas_notas_cliente_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plantillas_notas_cliente_on_activo ON public.plantillas_notas_cliente USING btree (activo);


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
-- Name: index_pre_factura_items_on_origen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_origen ON public.pre_factura_items USING btree (origen);


--
-- Name: index_pre_factura_items_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_paquete_id ON public.pre_factura_items USING btree (paquete_id);


--
-- Name: index_pre_factura_items_on_pre_factura_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_pre_factura_id ON public.pre_factura_items USING btree (pre_factura_id);


--
-- Name: index_pre_factura_items_on_servicio_extra_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_servicio_extra_id ON public.pre_factura_items USING btree (servicio_extra_id);


--
-- Name: index_pre_factura_items_on_tarifa_recolecta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pre_factura_items_on_tarifa_recolecta_id ON public.pre_factura_items USING btree (tarifa_recolecta_id);


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
-- Name: index_proveedores_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proveedores_on_activo ON public.proveedores USING btree (activo);


--
-- Name: index_proveedores_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_proveedores_on_codigo ON public.proveedores USING btree (codigo);


--
-- Name: index_proveedores_on_nombre; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_proveedores_on_nombre ON public.proveedores USING btree (nombre);


--
-- Name: index_proveedores_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proveedores_on_tipo ON public.proveedores USING btree (tipo);


--
-- Name: index_rc_counters_on_proveedor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rc_counters_on_proveedor_id ON public.rc_counters USING btree (proveedor_id);


--
-- Name: index_rc_counters_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rc_counters_on_sucursal_id ON public.rc_counters USING btree (sucursal_id);


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
-- Name: index_reempaques_on_hecho_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reempaques_on_hecho_por_id ON public.reempaques USING btree (hecho_por_id);


--
-- Name: index_reempaques_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reempaques_on_paquete_id ON public.reempaques USING btree (paquete_id);


--
-- Name: index_reempaques_on_tarea_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reempaques_on_tarea_id ON public.reempaques USING btree (tarea_id);


--
-- Name: index_servicios_extra_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_servicios_extra_on_activo ON public.servicios_extra USING btree (activo);


--
-- Name: index_servicios_extra_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_servicios_extra_on_codigo ON public.servicios_extra USING btree (codigo);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_sub_localidades_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sub_localidades_on_activo ON public.sub_localidades USING btree (activo);


--
-- Name: index_sub_localidades_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sub_localidades_on_sucursal_id ON public.sub_localidades USING btree (sucursal_id);


--
-- Name: index_sucursales_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sucursales_on_codigo ON public.sucursales USING btree (codigo);


--
-- Name: index_sucursales_on_codigo_ep; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sucursales_on_codigo_ep ON public.sucursales USING btree (codigo_ep) WHERE (codigo_ep IS NOT NULL);


--
-- Name: index_sucursales_on_codigo_recepcion_prefix; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sucursales_on_codigo_recepcion_prefix ON public.sucursales USING btree (codigo_recepcion_prefix);


--
-- Name: index_suppliers_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_activo ON public.suppliers USING btree (activo);


--
-- Name: index_suppliers_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_suppliers_on_codigo ON public.suppliers USING btree (codigo);


--
-- Name: index_suppliers_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_tipo ON public.suppliers USING btree (tipo);


--
-- Name: index_tareas_on_asignado_a_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tareas_on_asignado_a_id ON public.tareas USING btree (asignado_a_id);


--
-- Name: index_tareas_on_completado_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tareas_on_completado_por_id ON public.tareas USING btree (completado_por_id);


--
-- Name: index_tareas_on_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tareas_on_estado ON public.tareas USING btree (estado);


--
-- Name: index_tareas_on_paquete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tareas_on_paquete_id ON public.tareas USING btree (paquete_id);


--
-- Name: index_tarifas_recolecta_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tarifas_recolecta_on_activo ON public.tarifas_recolecta USING btree (activo);


--
-- Name: index_tarifas_recolecta_on_zona; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tarifas_recolecta_on_zona ON public.tarifas_recolecta USING btree (zona);


--
-- Name: index_terms_on_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_terms_on_activo ON public.terms USING btree (activo);


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
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: index_warehouse_receipts_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_agent_id ON public.warehouse_receipts USING btree (agent_id);


--
-- Name: index_warehouse_receipts_on_consignee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_consignee_id ON public.warehouse_receipts USING btree (consignee_id);


--
-- Name: index_warehouse_receipts_on_issued_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_issued_on ON public.warehouse_receipts USING btree (issued_on);


--
-- Name: index_warehouse_receipts_on_pre_alerta_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_pre_alerta_id ON public.warehouse_receipts USING btree (pre_alerta_id);


--
-- Name: index_warehouse_receipts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_status ON public.warehouse_receipts USING btree (status);


--
-- Name: index_warehouse_receipts_on_sucursal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_sucursal_id ON public.warehouse_receipts USING btree (sucursal_id);


--
-- Name: index_warehouse_receipts_on_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_supplier_id ON public.warehouse_receipts USING btree (supplier_id);


--
-- Name: index_warehouse_receipts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_warehouse_receipts_on_user_id ON public.warehouse_receipts USING btree (user_id);


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
-- Name: paquetes fk_rails_0b62b01889; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_0b62b01889 FOREIGN KEY (fecha_recibido_miami_by_user_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_0ba9c43e6b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_0ba9c43e6b FOREIGN KEY (sub_localidad_actual_id) REFERENCES public.sub_localidades(id);


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
-- Name: paquetes fk_rails_19b48ef815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_19b48ef815 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id);


--
-- Name: reempaques fk_rails_1a20685463; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reempaques
    ADD CONSTRAINT fk_rails_1a20685463 FOREIGN KEY (tarea_id) REFERENCES public.tareas(id);


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
-- Name: warehouse_receipts fk_rails_206d572a0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_206d572a0b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: manifiesto_counters fk_rails_23887ed0e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiesto_counters
    ADD CONSTRAINT fk_rails_23887ed0e1 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id);


--
-- Name: tareas fk_rails_239a2c336c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT fk_rails_239a2c336c FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: paquetes fk_rails_275a8504d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_275a8504d5 FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id) ON DELETE RESTRICT;


--
-- Name: rc_counters fk_rails_2a65b6f8a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rc_counters
    ADD CONSTRAINT fk_rails_2a65b6f8a6 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id) ON DELETE RESTRICT;


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
-- Name: warehouse_receipts fk_rails_318e9c5df4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_318e9c5df4 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: warehouse_receipts fk_rails_35c83da0a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_35c83da0a8 FOREIGN KEY (pre_alerta_id) REFERENCES public.pre_alertas(id);


--
-- Name: pre_factura_items fk_rails_3838674e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT fk_rails_3838674e35 FOREIGN KEY (pre_factura_id) REFERENCES public.pre_facturas(id);


--
-- Name: manifiestos fk_rails_3935231297; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifiestos
    ADD CONSTRAINT fk_rails_3935231297 FOREIGN KEY (sucursal_origen_id) REFERENCES public.sucursales(id);


--
-- Name: ep_counters fk_rails_3c629b8689; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ep_counters
    ADD CONSTRAINT fk_rails_3c629b8689 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id) ON DELETE RESTRICT;


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
-- Name: paquetes fk_rails_498bb416af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_498bb416af FOREIGN KEY (fecha_aduana_by_user_id) REFERENCES public.users(id);


--
-- Name: reempaques fk_rails_4c184d921a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reempaques
    ADD CONSTRAINT fk_rails_4c184d921a FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: paquete_motivos_retencion fk_rails_4ee027132c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquete_motivos_retencion
    ADD CONSTRAINT fk_rails_4ee027132c FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id) ON DELETE CASCADE;


--
-- Name: reempaques fk_rails_4fd8dd567a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reempaques
    ADD CONSTRAINT fk_rails_4fd8dd567a FOREIGN KEY (hecho_por_id) REFERENCES public.users(id);


--
-- Name: cotizaciones fk_rails_54a36869dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cotizaciones
    ADD CONSTRAINT fk_rails_54a36869dd FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: rc_counters fk_rails_55c124a7bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rc_counters
    ADD CONSTRAINT fk_rails_55c124a7bf FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id) ON DELETE RESTRICT;


--
-- Name: warehouse_receipts fk_rails_56a042f43b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_56a042f43b FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id);


--
-- Name: pre_factura_items fk_rails_58cfd992c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT fk_rails_58cfd992c2 FOREIGN KEY (tarifa_recolecta_id) REFERENCES public.tarifas_recolecta(id) ON DELETE SET NULL;


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
-- Name: pre_factura_items fk_rails_640d1bf992; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pre_factura_items
    ADD CONSTRAINT fk_rails_640d1bf992 FOREIGN KEY (servicio_extra_id) REFERENCES public.servicios_extra(id) ON DELETE SET NULL;


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
-- Name: paquetes fk_rails_69f5991b3d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_69f5991b3d FOREIGN KEY (fecha_enviado_by_user_id) REFERENCES public.users(id);


--
-- Name: numero_recepcion_counters fk_rails_6b50eeee77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.numero_recepcion_counters
    ADD CONSTRAINT fk_rails_6b50eeee77 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id);


--
-- Name: paquetes fk_rails_6d731d3733; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_6d731d3733 FOREIGN KEY (tarifa_recolecta_id) REFERENCES public.tarifas_recolecta(id) ON DELETE SET NULL;


--
-- Name: paquetes fk_rails_6fd48bb9d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_6fd48bb9d4 FOREIGN KEY (pre_factura_id) REFERENCES public.pre_facturas(id);


--
-- Name: paquetes fk_rails_72e789d8fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_72e789d8fd FOREIGN KEY (fecha_empacado_by_user_id) REFERENCES public.users(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_7d1067208a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_7d1067208a FOREIGN KEY (fecha_posible_entrega_by_user_id) REFERENCES public.users(id);


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
-- Name: paquetes fk_rails_803b2d84ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_803b2d84ac FOREIGN KEY (tercero_id) REFERENCES public.clientes(id) ON DELETE SET NULL;


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
-- Name: tareas fk_rails_95011bfdd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT fk_rails_95011bfdd3 FOREIGN KEY (completado_por_id) REFERENCES public.users(id);


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
-- Name: paquetes fk_rails_ad55b41320; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_ad55b41320 FOREIGN KEY (fecha_en_reparto_by_user_id) REFERENCES public.users(id);


--
-- Name: paquete_motivos_retencion fk_rails_bb4a99be86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquete_motivos_retencion
    ADD CONSTRAINT fk_rails_bb4a99be86 FOREIGN KEY (motivo_retencion_id) REFERENCES public.motivos_retencion(id) ON DELETE RESTRICT;


--
-- Name: warehouse_receipts fk_rails_bd11b17ab6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_bd11b17ab6 FOREIGN KEY (consignee_id) REFERENCES public.clientes(id);


--
-- Name: nota_credito_items fk_rails_be235163df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nota_credito_items
    ADD CONSTRAINT fk_rails_be235163df FOREIGN KEY (paquete_id) REFERENCES public.paquetes(id);


--
-- Name: paquetes fk_rails_c06a4ad9ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_c06a4ad9ac FOREIGN KEY (sucursal_actual_id) REFERENCES public.sucursales(id);


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
-- Name: paquetes fk_rails_cb242c76fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_cb242c76fb FOREIGN KEY (fecha_disponible_by_user_id) REFERENCES public.users(id);


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
-- Name: sub_localidades fk_rails_d342595a12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sub_localidades
    ADD CONSTRAINT fk_rails_d342595a12 FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id);


--
-- Name: ventas fk_rails_d3a4e528c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_rails_d3a4e528c1 FOREIGN KEY (financiamiento_id) REFERENCES public.financiamientos(id);


--
-- Name: tareas fk_rails_d5800c2f0f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT fk_rails_d5800c2f0f FOREIGN KEY (asignado_a_id) REFERENCES public.users(id);


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
-- Name: warehouse_receipts fk_rails_d9ce00665a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_receipts
    ADD CONSTRAINT fk_rails_d9ce00665a FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


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
-- Name: paquetes fk_rails_e8cced4358; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_e8cced4358 FOREIGN KEY (fecha_pre_alerta_by_user_id) REFERENCES public.users(id);


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
-- Name: paquetes fk_rails_f54229c82d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_f54229c82d FOREIGN KEY (fecha_solicito_recolecta_by_user_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_f762ed6e03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_f762ed6e03 FOREIGN KEY (fecha_entregado_by_user_id) REFERENCES public.users(id);


--
-- Name: paquetes fk_rails_f7d2d37727; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_f7d2d37727 FOREIGN KEY (fecha_consolidando_by_user_id) REFERENCES public.users(id);


--
-- Name: financiamiento_cuotas fk_rails_f9c6e674df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financiamiento_cuotas
    ADD CONSTRAINT fk_rails_f9c6e674df FOREIGN KEY (pago_id) REFERENCES public.pagos(id);


--
-- Name: paquetes fk_rails_fa39c85169; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_fa39c85169 FOREIGN KEY (warehouse_receipt_id) REFERENCES public.warehouse_receipts(id);


--
-- Name: paquetes fk_rails_fd73715478; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT fk_rails_fd73715478 FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: ep_counters fk_rails_fed4cab9d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ep_counters
    ADD CONSTRAINT fk_rails_fed4cab9d1 FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260503050815'),
('20260502150000'),
('20260502130000'),
('20260501180000'),
('20260501160000'),
('20260501150000'),
('20260501100000'),
('20260430052744'),
('20260430052743'),
('20260430052742'),
('20260430043555'),
('20260430043116'),
('20260430042343'),
('20260430042342'),
('20260430034028'),
('20260430034027'),
('20260429235510'),
('20260429235509'),
('20260429234222'),
('20260429231028'),
('20260429231027'),
('20260429231026'),
('20260429231025'),
('20260428233900'),
('20260425225919'),
('20260425033302'),
('20260425031409'),
('20260425031408'),
('20260424142626'),
('20260424142625'),
('20260424040301'),
('20260424034720'),
('20260414022221'),
('20260413024624'),
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

