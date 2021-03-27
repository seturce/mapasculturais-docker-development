--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.21
-- Dumped by pg_dump version 9.6.21

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

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: frequency; Type: DOMAIN; Schema: public; Owner: mapas
--

CREATE DOMAIN public.frequency AS character varying
	CONSTRAINT frequency_check CHECK (((VALUE)::text = ANY (ARRAY[('once'::character varying)::text, ('daily'::character varying)::text, ('weekly'::character varying)::text, ('monthly'::character varying)::text, ('yearly'::character varying)::text])));


ALTER DOMAIN public.frequency OWNER TO mapas;

--
-- Name: object_type; Type: TYPE; Schema: public; Owner: mapas
--

CREATE TYPE public.object_type AS ENUM (
    'MapasCulturais\Entities\Agent',
    'MapasCulturais\Entities\EvaluationMethodConfiguration',
    'MapasCulturais\Entities\Event',
    'MapasCulturais\Entities\Notification',
    'MapasCulturais\Entities\Opportunity',
    'MapasCulturais\Entities\Project',
    'MapasCulturais\Entities\Registration',
    'MapasCulturais\Entities\RegistrationFileConfiguration',
    'MapasCulturais\Entities\Request',
    'MapasCulturais\Entities\Seal',
    'MapasCulturais\Entities\Space',
    'MapasCulturais\Entities\Subsite'
);


ALTER TYPE public.object_type OWNER TO mapas;

--
-- Name: permission_action; Type: TYPE; Schema: public; Owner: mapas
--

CREATE TYPE public.permission_action AS ENUM (
    'approve',
    'archive',
    'changeOwner',
    'changeStatus',
    '@control',
    'create',
    'createAgentRelation',
    'createAgentRelationWithControl',
    'createEvents',
    'createSealRelation',
    'createSpaceRelation',
    'destroy',
    'evaluate',
    'evaluateRegistrations',
    'modify',
    'modifyRegistrationFields',
    'modifyValuers',
    'publish',
    'publishRegistrations',
    'register',
    'reject',
    'remove',
    'removeAgentRelation',
    'removeAgentRelationWithControl',
    'removeSealRelation',
    'removeSpaceRelation',
    'reopenValuerEvaluations',
    'requestEventRelation',
    'send',
    'sendUserEvaluations',
    'unpublish',
    'view',
    'viewConsolidatedResult',
    'viewEvaluations',
    'viewPrivateData',
    'viewPrivateFiles',
    'viewRegistrations',
    'viewUserEvaluation'
);


ALTER TYPE public.permission_action OWNER TO mapas;

--
-- Name: days_in_month(date); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.days_in_month(check_date date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  first_of_month DATE := check_date - ((extract(day from check_date) - 1)||' days')::interval;
BEGIN
  RETURN extract(day from first_of_month + '1 month'::interval - first_of_month);
END;
$$;


ALTER FUNCTION public.days_in_month(check_date date) OWNER TO mapas;

--
-- Name: generate_recurrences(interval, date, date, date, date, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.generate_recurrences(duration interval, original_start_date date, original_end_date date, range_start date, range_end date, repeat_month integer, repeat_week integer, repeat_day integer) RETURNS SETOF date
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  start_date DATE := original_start_date;
  next_date DATE;
  intervals INT := FLOOR(intervals_between(original_start_date, range_start, duration));
  current_month INT;
  current_week INT;
BEGIN
  IF repeat_month IS NOT NULL THEN
    start_date := start_date + (((12 + repeat_month - cast(extract(month from start_date) as int)) % 12) || ' months')::interval;
  END IF;
  IF repeat_week IS NULL AND repeat_day IS NOT NULL THEN
    IF duration = '7 days'::interval THEN
      start_date := start_date + (((7 + repeat_day - cast(extract(dow from start_date) as int)) % 7) || ' days')::interval;
    ELSE
      start_date := start_date + (repeat_day - extract(day from start_date) || ' days')::interval;
    END IF;
  END IF;
  LOOP
    next_date := start_date + duration * intervals;
    IF repeat_week IS NOT NULL AND repeat_day IS NOT NULL THEN
      current_month := extract(month from next_date);
      next_date := next_date + (((7 + repeat_day - cast(extract(dow from next_date) as int)) % 7) || ' days')::interval;
      IF extract(month from next_date) != current_month THEN
        next_date := next_date - '7 days'::interval;
      END IF;
      IF repeat_week > 0 THEN
        current_week := CEIL(extract(day from next_date) / 7);
      ELSE
        current_week := -CEIL((1 + days_in_month(next_date) - extract(day from next_date)) / 7);
      END IF;
      next_date := next_date + (repeat_week - current_week) * '7 days'::interval;
    END IF;
    EXIT WHEN next_date > range_end;

    IF next_date >= range_start AND next_date >= original_start_date THEN
      RETURN NEXT next_date;
    END IF;

    if original_end_date IS NOT NULL AND range_start >= original_start_date + (duration*intervals) AND range_start <= original_end_date + (duration*intervals) THEN
      RETURN NEXT next_date;
    END IF;
    intervals := intervals + 1;
  END LOOP;
END;
$$;


ALTER FUNCTION public.generate_recurrences(duration interval, original_start_date date, original_end_date date, range_start date, range_end date, repeat_month integer, repeat_week integer, repeat_day integer) OWNER TO mapas;

--
-- Name: interval_for(public.frequency); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.interval_for(recurs public.frequency) RETURNS interval
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  IF recurs = 'daily' THEN
    RETURN '1 day'::interval;
  ELSIF recurs = 'weekly' THEN
    RETURN '7 days'::interval;
  ELSIF recurs = 'monthly' THEN
    RETURN '1 month'::interval;
  ELSIF recurs = 'yearly' THEN
    RETURN '1 year'::interval;
  ELSE
    RAISE EXCEPTION 'Recurrence % not supported by generate_recurrences()', recurs;
  END IF;
END;
$$;


ALTER FUNCTION public.interval_for(recurs public.frequency) OWNER TO mapas;

--
-- Name: intervals_between(date, date, interval); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.intervals_between(start_date date, end_date date, duration interval) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  count FLOAT := 0;
  multiplier INT := 512;
BEGIN
  IF start_date > end_date THEN
    RETURN 0;
  END IF;
  LOOP
    WHILE start_date + (count + multiplier) * duration < end_date LOOP
      count := count + multiplier;
    END LOOP;
    EXIT WHEN multiplier = 1;
    multiplier := multiplier / 2;
  END LOOP;
  count := count + (extract(epoch from end_date) - extract(epoch from (start_date + count * duration))) / (extract(epoch from end_date + duration) - extract(epoch from end_date))::int;
  RETURN count;
END
$$;


ALTER FUNCTION public.intervals_between(start_date date, end_date date, duration interval) OWNER TO mapas;

--
-- Name: pseudo_random_id_generator(); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.pseudo_random_id_generator() RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
                DECLARE
                    l1 int;
                    l2 int;
                    r1 int;
                    r2 int;
                    VALUE int;
                    i int:=0;
                BEGIN
                    VALUE:= nextval('pseudo_random_id_seq');
                    l1:= (VALUE >> 16) & 65535;
                    r1:= VALUE & 65535;
                    WHILE i < 3 LOOP
                        l2 := r1;
                        r2 := l1 # ((((1366 * r1 + 150889) % 714025) / 714025.0) * 32767)::int;
                        l1 := l2;
                        r1 := r2;
                        i := i + 1;
                    END LOOP;
                    RETURN ((r1 << 16) + l1);
                END;
            $$;


ALTER FUNCTION public.pseudo_random_id_generator() OWNER TO mapas;

--
-- Name: random_id_generator(character varying, bigint); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.random_id_generator(table_name character varying, initial_range bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$DECLARE
              rand_int INTEGER;
              count INTEGER := 1;
              statement TEXT;
            BEGIN
              WHILE count > 0 LOOP
                initial_range := initial_range * 10;

                rand_int := (RANDOM() * initial_range)::BIGINT + initial_range / 10;

                statement := CONCAT('SELECT count(id) FROM ', table_name, ' WHERE id = ', rand_int);

                EXECUTE statement;
                IF NOT FOUND THEN
                  count := 0;
                END IF;

              END LOOP;
              RETURN rand_int;
            END;
            $$;


ALTER FUNCTION public.random_id_generator(table_name character varying, initial_range bigint) OWNER TO mapas;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: event_occurrence; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event_occurrence (
    id integer NOT NULL,
    space_id integer NOT NULL,
    event_id integer NOT NULL,
    rule text,
    starts_on date,
    ends_on date,
    starts_at timestamp without time zone,
    ends_at timestamp without time zone,
    frequency public.frequency,
    separation integer DEFAULT 1 NOT NULL,
    count integer,
    until date,
    timezone_name text DEFAULT 'Etc/UTC'::text NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    CONSTRAINT positive_separation CHECK ((separation > 0))
);


ALTER TABLE public.event_occurrence OWNER TO mapas;

--
-- Name: recurrences_for(public.event_occurrence, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.recurrences_for(event public.event_occurrence, range_start timestamp without time zone, range_end timestamp without time zone) RETURNS SETOF date
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  recurrence event_occurrence_recurrence;
  recurrences_start DATE := COALESCE(event.starts_at::date, event.starts_on);
  recurrences_end DATE := range_end;
  duration INTERVAL := interval_for(event.frequency) * event.separation;
  next_date DATE;
BEGIN
  IF event.until IS NOT NULL AND event.until < recurrences_end THEN
    recurrences_end := event.until;
  END IF;
  IF event.count IS NOT NULL AND recurrences_start + (event.count - 1) * duration < recurrences_end THEN
    recurrences_end := recurrences_start + (event.count - 1) * duration;
  END IF;

  FOR recurrence IN
    SELECT event_occurrence_recurrence.*
      FROM (SELECT NULL) AS foo
      LEFT JOIN event_occurrence_recurrence
        ON event_occurrence_id = event.id
  LOOP
    FOR next_date IN
      SELECT *
        FROM generate_recurrences(
          duration,
          recurrences_start,
          COALESCE(event.ends_at::date, event.ends_on),
          range_start::date,
          recurrences_end,
          recurrence.month,
          recurrence.week,
          recurrence.day
        )
    LOOP
      RETURN NEXT next_date;
    END LOOP;
  END LOOP;
  RETURN;
END;
$$;


ALTER FUNCTION public.recurrences_for(event public.event_occurrence, range_start timestamp without time zone, range_end timestamp without time zone) OWNER TO mapas;

--
-- Name: recurring_event_occurrence_for(timestamp without time zone, timestamp without time zone, character varying, integer); Type: FUNCTION; Schema: public; Owner: mapas
--

CREATE FUNCTION public.recurring_event_occurrence_for(range_start timestamp without time zone, range_end timestamp without time zone, time_zone character varying, event_occurrence_limit integer) RETURNS SETOF public.event_occurrence
    LANGUAGE plpgsql STABLE
    AS $$
            DECLARE
              event event_occurrence;
              original_date DATE;
              original_date_in_zone DATE;
              start_time TIME;
              start_time_in_zone TIME;
              next_date DATE;
              next_time_in_zone TIME;
              duration INTERVAL;
              time_offset INTERVAL;
              r_start DATE := (timezone('UTC', range_start) AT TIME ZONE time_zone)::DATE;
              r_end DATE := (timezone('UTC', range_end) AT TIME ZONE time_zone)::DATE;

              recurrences_start DATE := CASE WHEN r_start < range_start THEN r_start ELSE range_start END;
              recurrences_end DATE := CASE WHEN r_end > range_end THEN r_end ELSE range_end END;

              inc_interval INTERVAL := '2 hours'::INTERVAL;

              ext_start TIMESTAMP := range_start::TIMESTAMP - inc_interval;
              ext_end   TIMESTAMP := range_end::TIMESTAMP   + inc_interval;
            BEGIN
              FOR event IN
                SELECT *
                  FROM event_occurrence
                  WHERE
                    status > 0
                    AND
                    (
                      (frequency = 'once' AND
                      ((starts_on IS NOT NULL AND ends_on IS NOT NULL AND starts_on <= r_end AND ends_on >= r_start) OR
                       (starts_on IS NOT NULL AND starts_on <= r_end AND starts_on >= r_start) OR
                       (starts_at <= range_end AND ends_at >= range_start)))

                      OR

                      (
                        frequency <> 'once' AND
                        (
                          ( starts_on IS NOT NULL AND starts_on <= ext_end ) OR
                          ( starts_at IS NOT NULL AND starts_at <= ext_end )
                        ) AND (
                          (until IS NULL AND ends_at IS NULL AND ends_on IS NULL) OR
                          (until IS NOT NULL AND until >= ext_start) OR
                          (ends_on IS NOT NULL AND ends_on >= ext_start) OR
                          (ends_at IS NOT NULL AND ends_at >= ext_start)
                        )
                      )
                    )

              LOOP
                IF event.frequency = 'once' THEN
                  RETURN NEXT event;
                  CONTINUE;
                END IF;

                -- All-day event
                IF event.starts_on IS NOT NULL AND event.ends_on IS NULL THEN
                  original_date := event.starts_on;
                  duration := '1 day'::interval;
                -- Multi-day event
                ELSIF event.starts_on IS NOT NULL AND event.ends_on IS NOT NULL THEN
                  original_date := event.starts_on;
                  duration := timezone(time_zone, event.ends_on) - timezone(time_zone, event.starts_on);
                -- Timespan event
                ELSE
                  original_date := event.starts_at::date;
                  original_date_in_zone := (timezone('UTC', event.starts_at) AT TIME ZONE event.timezone_name)::date;
                  start_time := event.starts_at::time;
                  start_time_in_zone := (timezone('UTC', event.starts_at) AT time ZONE event.timezone_name)::time;
                  duration := event.ends_at - event.starts_at;
                END IF;

                IF event.count IS NOT NULL THEN
                  recurrences_start := original_date;
                END IF;

                FOR next_date IN
                  SELECT occurrence
                    FROM (
                      SELECT * FROM recurrences_for(event, recurrences_start, recurrences_end) AS occurrence
                      UNION SELECT original_date
                      LIMIT event.count
                    ) AS occurrences
                    WHERE
                      occurrence::date <= recurrences_end AND
                      (occurrence + duration)::date >= recurrences_start AND
                      occurrence NOT IN (SELECT date FROM event_occurrence_cancellation WHERE event_occurrence_id = event.id)
                    LIMIT event_occurrence_limit
                LOOP
                  -- All-day event
                  IF event.starts_on IS NOT NULL AND event.ends_on IS NULL THEN
                    CONTINUE WHEN next_date < r_start OR next_date > r_end;
                    event.starts_on := next_date;

                  -- Multi-day event
                  ELSIF event.starts_on IS NOT NULL AND event.ends_on IS NOT NULL THEN
                    event.starts_on := next_date;
                    CONTINUE WHEN event.starts_on > r_end;
                    event.ends_on := next_date + duration;
                    CONTINUE WHEN event.ends_on < r_start;

                  -- Timespan event
                  ELSE
                    next_time_in_zone := (timezone('UTC', (next_date + start_time)) at time zone event.timezone_name)::time;
                    time_offset := (original_date_in_zone + next_time_in_zone) - (original_date_in_zone + start_time_in_zone);
                    event.starts_at := next_date + start_time - time_offset;

                    CONTINUE WHEN event.starts_at > range_end;
                    event.ends_at := event.starts_at + duration;
                    CONTINUE WHEN event.ends_at < range_start;
                  END IF;

                  RETURN NEXT event;
                END LOOP;
              END LOOP;
              RETURN;
            END;
            $$;


ALTER FUNCTION public.recurring_event_occurrence_for(range_start timestamp without time zone, range_end timestamp without time zone, time_zone character varying, event_occurrence_limit integer) OWNER TO mapas;

--
-- Name: _mesoregiao; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public._mesoregiao (
    gid integer NOT NULL,
    id double precision,
    nm_meso character varying(100),
    cd_geocodu character varying(2),
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public._mesoregiao OWNER TO mapas;

--
-- Name: _mesoregiao_gid_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public._mesoregiao_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public._mesoregiao_gid_seq OWNER TO mapas;

--
-- Name: _mesoregiao_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public._mesoregiao_gid_seq OWNED BY public._mesoregiao.gid;


--
-- Name: _microregiao; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public._microregiao (
    gid integer NOT NULL,
    id double precision,
    nm_micro character varying(100),
    cd_geocodu character varying(2),
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public._microregiao OWNER TO mapas;

--
-- Name: _microregiao_gid_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public._microregiao_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public._microregiao_gid_seq OWNER TO mapas;

--
-- Name: _microregiao_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public._microregiao_gid_seq OWNED BY public._microregiao.gid;


--
-- Name: _municipios; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public._municipios (
    gid integer NOT NULL,
    id double precision,
    cd_geocodm character varying(20),
    nm_municip character varying(60),
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public._municipios OWNER TO mapas;

--
-- Name: _municipios_gid_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public._municipios_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public._municipios_gid_seq OWNER TO mapas;

--
-- Name: _municipios_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public._municipios_gid_seq OWNED BY public._municipios.gid;


--
-- Name: agent_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.agent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agent_id_seq OWNER TO mapas;

--
-- Name: agent; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.agent (
    id integer DEFAULT nextval('public.agent_id_seq'::regclass) NOT NULL,
    parent_id integer,
    user_id integer NOT NULL,
    type smallint NOT NULL,
    name character varying(255) NOT NULL,
    location point,
    _geo_location public.geography,
    short_description text,
    long_description text,
    create_timestamp timestamp without time zone NOT NULL,
    status smallint NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    public_location boolean,
    update_timestamp timestamp(0) without time zone,
    subsite_id integer
);


ALTER TABLE public.agent OWNER TO mapas;

--
-- Name: COLUMN agent.location; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.agent.location IS 'type=POINT';


--
-- Name: agent_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.agent_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.agent_meta OWNER TO mapas;

--
-- Name: agent_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.agent_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agent_meta_id_seq OWNER TO mapas;

--
-- Name: agent_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.agent_meta_id_seq OWNED BY public.agent_meta.id;


--
-- Name: agent_relation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.agent_relation (
    id integer NOT NULL,
    agent_id integer NOT NULL,
    object_type public.object_type NOT NULL,
    object_id integer NOT NULL,
    type character varying(64),
    has_control boolean DEFAULT false NOT NULL,
    create_timestamp timestamp without time zone,
    status smallint
);


ALTER TABLE public.agent_relation OWNER TO mapas;

--
-- Name: agent_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.agent_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agent_relation_id_seq OWNER TO mapas;

--
-- Name: agent_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.agent_relation_id_seq OWNED BY public.agent_relation.id;


--
-- Name: db_update; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.db_update (
    name character varying(255) NOT NULL,
    exec_time timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.db_update OWNER TO mapas;

--
-- Name: entity_revision; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.entity_revision (
    id integer NOT NULL,
    user_id integer,
    object_id integer NOT NULL,
    object_type public.object_type NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL,
    action character varying(255) NOT NULL,
    message text NOT NULL
);


ALTER TABLE public.entity_revision OWNER TO mapas;

--
-- Name: entity_revision_data; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.entity_revision_data (
    id integer NOT NULL,
    "timestamp" timestamp(0) without time zone NOT NULL,
    key character varying(255) NOT NULL,
    value text
);


ALTER TABLE public.entity_revision_data OWNER TO mapas;

--
-- Name: entity_revision_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.entity_revision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_revision_id_seq OWNER TO mapas;

--
-- Name: entity_revision_revision_data; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.entity_revision_revision_data (
    revision_id integer NOT NULL,
    revision_data_id integer NOT NULL
);


ALTER TABLE public.entity_revision_revision_data OWNER TO mapas;

--
-- Name: evaluation_method_configuration; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.evaluation_method_configuration (
    id integer NOT NULL,
    opportunity_id integer NOT NULL,
    type character varying(255) NOT NULL
);


ALTER TABLE public.evaluation_method_configuration OWNER TO mapas;

--
-- Name: evaluation_method_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.evaluation_method_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evaluation_method_configuration_id_seq OWNER TO mapas;

--
-- Name: evaluation_method_configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.evaluation_method_configuration_id_seq OWNED BY public.evaluation_method_configuration.id;


--
-- Name: evaluationmethodconfiguration_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.evaluationmethodconfiguration_meta (
    id integer NOT NULL,
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text
);


ALTER TABLE public.evaluationmethodconfiguration_meta OWNER TO mapas;

--
-- Name: evaluationmethodconfiguration_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.evaluationmethodconfiguration_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evaluationmethodconfiguration_meta_id_seq OWNER TO mapas;

--
-- Name: event; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event (
    id integer NOT NULL,
    project_id integer,
    name character varying(255) NOT NULL,
    short_description text NOT NULL,
    long_description text,
    rules text,
    create_timestamp timestamp without time zone NOT NULL,
    status smallint NOT NULL,
    agent_id integer,
    is_verified boolean DEFAULT false NOT NULL,
    type smallint NOT NULL,
    update_timestamp timestamp(0) without time zone,
    subsite_id integer
);


ALTER TABLE public.event OWNER TO mapas;

--
-- Name: event_attendance; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event_attendance (
    id integer NOT NULL,
    user_id integer NOT NULL,
    event_occurrence_id integer NOT NULL,
    event_id integer NOT NULL,
    space_id integer NOT NULL,
    type character varying(255) NOT NULL,
    reccurrence_string text,
    start_timestamp timestamp(0) without time zone NOT NULL,
    end_timestamp timestamp(0) without time zone NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.event_attendance OWNER TO mapas;

--
-- Name: event_attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_attendance_id_seq OWNER TO mapas;

--
-- Name: event_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_id_seq OWNER TO mapas;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.event_id_seq OWNED BY public.event.id;


--
-- Name: event_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event_meta (
    key character varying(255) NOT NULL,
    object_id integer NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.event_meta OWNER TO mapas;

--
-- Name: event_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_meta_id_seq OWNER TO mapas;

--
-- Name: event_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.event_meta_id_seq OWNED BY public.event_meta.id;


--
-- Name: event_occurrence_cancellation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event_occurrence_cancellation (
    id integer NOT NULL,
    event_occurrence_id integer,
    date date
);


ALTER TABLE public.event_occurrence_cancellation OWNER TO mapas;

--
-- Name: event_occurrence_cancellation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_occurrence_cancellation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_occurrence_cancellation_id_seq OWNER TO mapas;

--
-- Name: event_occurrence_cancellation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.event_occurrence_cancellation_id_seq OWNED BY public.event_occurrence_cancellation.id;


--
-- Name: event_occurrence_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_occurrence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_occurrence_id_seq OWNER TO mapas;

--
-- Name: event_occurrence_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.event_occurrence_id_seq OWNED BY public.event_occurrence.id;


--
-- Name: event_occurrence_recurrence; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.event_occurrence_recurrence (
    id integer NOT NULL,
    event_occurrence_id integer,
    month integer,
    day integer,
    week integer
);


ALTER TABLE public.event_occurrence_recurrence OWNER TO mapas;

--
-- Name: event_occurrence_recurrence_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.event_occurrence_recurrence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_occurrence_recurrence_id_seq OWNER TO mapas;

--
-- Name: event_occurrence_recurrence_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.event_occurrence_recurrence_id_seq OWNED BY public.event_occurrence_recurrence.id;


--
-- Name: file_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.file_id_seq OWNER TO mapas;

--
-- Name: file; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.file (
    id integer DEFAULT nextval('public.file_id_seq'::regclass) NOT NULL,
    md5 character varying(32) NOT NULL,
    mime_type character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    object_type public.object_type NOT NULL,
    object_id integer NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    grp character varying(32) NOT NULL,
    description character varying(255),
    parent_id integer,
    path character varying(1024) DEFAULT NULL::character varying,
    private boolean DEFAULT false NOT NULL
);


ALTER TABLE public.file OWNER TO mapas;

--
-- Name: geo_division_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.geo_division_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.geo_division_id_seq OWNER TO mapas;

--
-- Name: geo_division; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.geo_division (
    id integer DEFAULT nextval('public.geo_division_id_seq'::regclass) NOT NULL,
    parent_id integer,
    type character varying(32) NOT NULL,
    cod character varying(32),
    name character varying(128) NOT NULL,
    geom public.geometry,
    CONSTRAINT enforce_dims_geom CHECK ((public.st_ndims(geom) = 2)),
    CONSTRAINT enforce_geotype_geom CHECK (((public.geometrytype(geom) = 'MULTIPOLYGON'::text) OR (geom IS NULL))),
    CONSTRAINT enforce_srid_geom CHECK ((public.st_srid(geom) = 4326))
);


ALTER TABLE public.geo_division OWNER TO mapas;

--
-- Name: metadata; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.metadata (
    object_id integer NOT NULL,
    object_type public.object_type NOT NULL,
    key character varying(32) NOT NULL,
    value text
);


ALTER TABLE public.metadata OWNER TO mapas;

--
-- Name: metalist_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.metalist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.metalist_id_seq OWNER TO mapas;

--
-- Name: metalist; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.metalist (
    id integer DEFAULT nextval('public.metalist_id_seq'::regclass) NOT NULL,
    object_type character varying(255) NOT NULL,
    object_id integer NOT NULL,
    grp character varying(32) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    value character varying(2048) NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    "order" smallint
);


ALTER TABLE public.metalist OWNER TO mapas;

--
-- Name: notification_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_id_seq OWNER TO mapas;

--
-- Name: notification; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.notification (
    id integer DEFAULT nextval('public.notification_id_seq'::regclass) NOT NULL,
    user_id integer NOT NULL,
    request_id integer,
    message text NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    action_timestamp timestamp without time zone,
    status smallint NOT NULL
);


ALTER TABLE public.notification OWNER TO mapas;

--
-- Name: notification_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.notification_meta (
    id integer NOT NULL,
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text
);


ALTER TABLE public.notification_meta OWNER TO mapas;

--
-- Name: notification_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.notification_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_meta_id_seq OWNER TO mapas;

--
-- Name: occurrence_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.occurrence_id_seq
    START WITH 100000
    INCREMENT BY 1
    MINVALUE 100000
    NO MAXVALUE
    CACHE 1
    CYCLE;


ALTER TABLE public.occurrence_id_seq OWNER TO mapas;

--
-- Name: opportunity_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.opportunity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.opportunity_id_seq OWNER TO mapas;

--
-- Name: opportunity; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.opportunity (
    id integer DEFAULT nextval('public.opportunity_id_seq'::regclass) NOT NULL,
    parent_id integer,
    agent_id integer NOT NULL,
    type smallint,
    name character varying(255) NOT NULL,
    short_description text,
    long_description text,
    registration_from timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    registration_to timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    published_registrations boolean NOT NULL,
    registration_categories text,
    create_timestamp timestamp(0) without time zone NOT NULL,
    update_timestamp timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    status smallint NOT NULL,
    subsite_id integer,
    object_type character varying(255) NOT NULL,
    object_id integer NOT NULL
);


ALTER TABLE public.opportunity OWNER TO mapas;

--
-- Name: opportunity_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.opportunity_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.opportunity_meta_id_seq OWNER TO mapas;

--
-- Name: opportunity_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.opportunity_meta (
    id integer DEFAULT nextval('public.opportunity_meta_id_seq'::regclass) NOT NULL,
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text
);


ALTER TABLE public.opportunity_meta OWNER TO mapas;

--
-- Name: pcache_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.pcache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pcache_id_seq OWNER TO mapas;

--
-- Name: pcache; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.pcache (
    id integer DEFAULT nextval('public.pcache_id_seq'::regclass) NOT NULL,
    user_id integer NOT NULL,
    action public.permission_action NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL,
    object_type public.object_type NOT NULL,
    object_id integer
);


ALTER TABLE public.pcache OWNER TO mapas;

--
-- Name: permission_cache_pending; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.permission_cache_pending (
    id integer NOT NULL,
    object_id integer NOT NULL,
    object_type character varying(255) NOT NULL,
    status smallint DEFAULT 0
);


ALTER TABLE public.permission_cache_pending OWNER TO mapas;

--
-- Name: permission_cache_pending_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.permission_cache_pending_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.permission_cache_pending_seq OWNER TO mapas;

--
-- Name: procuration; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.procuration (
    token character varying(32) NOT NULL,
    usr_id integer NOT NULL,
    attorney_user_id integer NOT NULL,
    action character varying(255) NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL,
    valid_until_timestamp timestamp(0) without time zone DEFAULT NULL::timestamp without time zone
);


ALTER TABLE public.procuration OWNER TO mapas;

--
-- Name: project; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.project (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    short_description text,
    long_description text,
    create_timestamp timestamp without time zone NOT NULL,
    status smallint NOT NULL,
    agent_id integer,
    is_verified boolean DEFAULT false NOT NULL,
    type smallint NOT NULL,
    parent_id integer,
    registration_from timestamp without time zone,
    registration_to timestamp without time zone,
    update_timestamp timestamp(0) without time zone,
    subsite_id integer
);


ALTER TABLE public.project OWNER TO mapas;

--
-- Name: project_event; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.project_event (
    id integer NOT NULL,
    event_id integer NOT NULL,
    project_id integer NOT NULL,
    type smallint NOT NULL,
    status smallint NOT NULL
);


ALTER TABLE public.project_event OWNER TO mapas;

--
-- Name: project_event_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.project_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.project_event_id_seq OWNER TO mapas;

--
-- Name: project_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.project_event_id_seq OWNED BY public.project_event.id;


--
-- Name: project_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.project_id_seq OWNER TO mapas;

--
-- Name: project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.project_id_seq OWNED BY public.project.id;


--
-- Name: project_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.project_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.project_meta OWNER TO mapas;

--
-- Name: project_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.project_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.project_meta_id_seq OWNER TO mapas;

--
-- Name: project_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.project_meta_id_seq OWNED BY public.project_meta.id;


--
-- Name: pseudo_random_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.pseudo_random_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pseudo_random_id_seq OWNER TO mapas;

--
-- Name: registration; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.registration (
    id integer DEFAULT public.pseudo_random_id_generator() NOT NULL,
    opportunity_id integer NOT NULL,
    category character varying(255),
    agent_id integer NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    sent_timestamp timestamp without time zone,
    status smallint NOT NULL,
    agents_data text,
    subsite_id integer,
    consolidated_result character varying(255) DEFAULT NULL::character varying,
    space_data text,
    number character varying(24),
    valuers_exceptions_list text DEFAULT '{"include": [], "exclude": []}'::text NOT NULL
);


ALTER TABLE public.registration OWNER TO mapas;

--
-- Name: registration_evaluation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.registration_evaluation (
    id integer NOT NULL,
    registration_id integer DEFAULT public.pseudo_random_id_generator() NOT NULL,
    user_id integer NOT NULL,
    result character varying(255) DEFAULT NULL::character varying,
    evaluation_data text NOT NULL,
    status smallint
);


ALTER TABLE public.registration_evaluation OWNER TO mapas;

--
-- Name: registration_evaluation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.registration_evaluation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_evaluation_id_seq OWNER TO mapas;

--
-- Name: registration_field_configuration; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.registration_field_configuration (
    id integer NOT NULL,
    opportunity_id integer,
    title character varying(255) NOT NULL,
    description text,
    categories text,
    required boolean NOT NULL,
    field_type character varying(255) NOT NULL,
    field_options text NOT NULL,
    max_size text,
    display_order smallint DEFAULT 255,
    config text,
    mask text,
    mask_options text
);


ALTER TABLE public.registration_field_configuration OWNER TO mapas;

--
-- Name: COLUMN registration_field_configuration.categories; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.registration_field_configuration.categories IS '(DC2Type:array)';


--
-- Name: registration_field_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.registration_field_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_field_configuration_id_seq OWNER TO mapas;

--
-- Name: registration_file_configuration; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.registration_file_configuration (
    id integer NOT NULL,
    opportunity_id integer,
    title character varying(255) NOT NULL,
    description text,
    required boolean NOT NULL,
    categories text,
    display_order smallint DEFAULT 255
);


ALTER TABLE public.registration_file_configuration OWNER TO mapas;

--
-- Name: COLUMN registration_file_configuration.categories; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.registration_file_configuration.categories IS '(DC2Type:array)';


--
-- Name: registration_file_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.registration_file_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_file_configuration_id_seq OWNER TO mapas;

--
-- Name: registration_file_configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.registration_file_configuration_id_seq OWNED BY public.registration_file_configuration.id;


--
-- Name: registration_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.registration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_id_seq OWNER TO mapas;

--
-- Name: registration_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.registration_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.registration_meta OWNER TO mapas;

--
-- Name: registration_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.registration_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_meta_id_seq OWNER TO mapas;

--
-- Name: registration_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.registration_meta_id_seq OWNED BY public.registration_meta.id;


--
-- Name: request_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.request_id_seq OWNER TO mapas;

--
-- Name: request; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.request (
    id integer DEFAULT nextval('public.request_id_seq'::regclass) NOT NULL,
    request_uid character varying(32) NOT NULL,
    requester_user_id integer NOT NULL,
    origin_type character varying(255) NOT NULL,
    origin_id integer NOT NULL,
    destination_type character varying(255) NOT NULL,
    destination_id integer NOT NULL,
    metadata text,
    type character varying(255) NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    action_timestamp timestamp without time zone,
    status smallint NOT NULL
);


ALTER TABLE public.request OWNER TO mapas;

--
-- Name: revision_data_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.revision_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.revision_data_id_seq OWNER TO mapas;

--
-- Name: role; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.role (
    id integer NOT NULL,
    usr_id integer,
    name character varying(32) NOT NULL,
    subsite_id integer
);


ALTER TABLE public.role OWNER TO mapas;

--
-- Name: role_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.role_id_seq OWNER TO mapas;

--
-- Name: role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.role_id_seq OWNED BY public.role.id;


--
-- Name: seal; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.seal (
    id integer NOT NULL,
    agent_id integer NOT NULL,
    name character varying(255) NOT NULL,
    short_description text,
    long_description text,
    valid_period smallint NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL,
    status smallint NOT NULL,
    certificate_text text,
    update_timestamp timestamp(0) without time zone,
    subsite_id integer
);


ALTER TABLE public.seal OWNER TO mapas;

--
-- Name: seal_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.seal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seal_id_seq OWNER TO mapas;

--
-- Name: seal_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.seal_meta (
    id integer NOT NULL,
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text
);


ALTER TABLE public.seal_meta OWNER TO mapas;

--
-- Name: seal_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.seal_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seal_meta_id_seq OWNER TO mapas;

--
-- Name: seal_relation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.seal_relation (
    id integer NOT NULL,
    seal_id integer,
    object_id integer NOT NULL,
    create_timestamp timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    status smallint,
    object_type character varying(255) NOT NULL,
    agent_id integer NOT NULL,
    owner_id integer,
    validate_date date,
    renovation_request boolean
);


ALTER TABLE public.seal_relation OWNER TO mapas;

--
-- Name: seal_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.seal_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seal_relation_id_seq OWNER TO mapas;

--
-- Name: space; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.space (
    id integer NOT NULL,
    parent_id integer,
    location point,
    _geo_location public.geography,
    name character varying(255) NOT NULL,
    short_description text,
    long_description text,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    status smallint NOT NULL,
    type smallint NOT NULL,
    agent_id integer,
    is_verified boolean DEFAULT false NOT NULL,
    public boolean DEFAULT false NOT NULL,
    update_timestamp timestamp(0) without time zone,
    subsite_id integer
);


ALTER TABLE public.space OWNER TO mapas;

--
-- Name: COLUMN space.location; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.space.location IS 'type=POINT';


--
-- Name: space_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.space_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.space_id_seq OWNER TO mapas;

--
-- Name: space_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.space_id_seq OWNED BY public.space.id;


--
-- Name: space_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.space_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.space_meta OWNER TO mapas;

--
-- Name: space_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.space_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.space_meta_id_seq OWNER TO mapas;

--
-- Name: space_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.space_meta_id_seq OWNED BY public.space_meta.id;


--
-- Name: space_relation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.space_relation (
    id integer NOT NULL,
    space_id integer,
    object_id integer NOT NULL,
    create_timestamp timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    status smallint,
    object_type character varying(255) NOT NULL
);


ALTER TABLE public.space_relation OWNER TO mapas;

--
-- Name: space_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.space_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.space_relation_id_seq OWNER TO mapas;

--
-- Name: subsite; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.subsite (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    create_timestamp timestamp(0) without time zone NOT NULL,
    status smallint NOT NULL,
    agent_id integer NOT NULL,
    url character varying(255) NOT NULL,
    namespace character varying(50) NOT NULL,
    alias_url character varying(255) DEFAULT NULL::character varying,
    verified_seals character varying(512) DEFAULT '[]'::character varying
);


ALTER TABLE public.subsite OWNER TO mapas;

--
-- Name: subsite_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.subsite_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subsite_id_seq OWNER TO mapas;

--
-- Name: subsite_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.subsite_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.subsite_meta OWNER TO mapas;

--
-- Name: subsite_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.subsite_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subsite_meta_id_seq OWNER TO mapas;

--
-- Name: term; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.term (
    id integer NOT NULL,
    taxonomy character varying(64) NOT NULL,
    term character varying(255) NOT NULL,
    description text
);


ALTER TABLE public.term OWNER TO mapas;

--
-- Name: COLUMN term.taxonomy; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.term.taxonomy IS '1=tag';


--
-- Name: term_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.term_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.term_id_seq OWNER TO mapas;

--
-- Name: term_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.term_id_seq OWNED BY public.term.id;


--
-- Name: term_relation; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.term_relation (
    term_id integer NOT NULL,
    object_type public.object_type NOT NULL,
    object_id integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.term_relation OWNER TO mapas;

--
-- Name: term_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.term_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.term_relation_id_seq OWNER TO mapas;

--
-- Name: term_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mapas
--

ALTER SEQUENCE public.term_relation_id_seq OWNED BY public.term_relation.id;


--
-- Name: user_app; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.user_app (
    public_key character varying(64) NOT NULL,
    private_key character varying(128) NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    status integer NOT NULL,
    create_timestamp timestamp without time zone NOT NULL,
    subsite_id integer
);


ALTER TABLE public.user_app OWNER TO mapas;

--
-- Name: user_meta; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.user_meta (
    object_id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    id integer NOT NULL
);


ALTER TABLE public.user_meta OWNER TO mapas;

--
-- Name: user_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.user_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_meta_id_seq OWNER TO mapas;

--
-- Name: usr_id_seq; Type: SEQUENCE; Schema: public; Owner: mapas
--

CREATE SEQUENCE public.usr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usr_id_seq OWNER TO mapas;

--
-- Name: usr; Type: TABLE; Schema: public; Owner: mapas
--

CREATE TABLE public.usr (
    id integer DEFAULT nextval('public.usr_id_seq'::regclass) NOT NULL,
    auth_provider smallint NOT NULL,
    auth_uid character varying(512) NOT NULL,
    email character varying(255) NOT NULL,
    last_login_timestamp timestamp without time zone NOT NULL,
    create_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    status smallint NOT NULL,
    profile_id integer
);


ALTER TABLE public.usr OWNER TO mapas;

--
-- Name: COLUMN usr.auth_provider; Type: COMMENT; Schema: public; Owner: mapas
--

COMMENT ON COLUMN public.usr.auth_provider IS '1=openid';


--
-- Name: _mesoregiao gid; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._mesoregiao ALTER COLUMN gid SET DEFAULT nextval('public._mesoregiao_gid_seq'::regclass);


--
-- Name: _microregiao gid; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._microregiao ALTER COLUMN gid SET DEFAULT nextval('public._microregiao_gid_seq'::regclass);


--
-- Name: _municipios gid; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._municipios ALTER COLUMN gid SET DEFAULT nextval('public._municipios_gid_seq'::regclass);


--
-- Name: agent_relation id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent_relation ALTER COLUMN id SET DEFAULT nextval('public.agent_relation_id_seq'::regclass);


--
-- Name: evaluation_method_configuration id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.evaluation_method_configuration ALTER COLUMN id SET DEFAULT nextval('public.evaluation_method_configuration_id_seq'::regclass);


--
-- Name: event id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event ALTER COLUMN id SET DEFAULT nextval('public.event_id_seq'::regclass);


--
-- Name: event_occurrence id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence ALTER COLUMN id SET DEFAULT nextval('public.event_occurrence_id_seq'::regclass);


--
-- Name: event_occurrence_cancellation id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_cancellation ALTER COLUMN id SET DEFAULT nextval('public.event_occurrence_cancellation_id_seq'::regclass);


--
-- Name: event_occurrence_recurrence id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_recurrence ALTER COLUMN id SET DEFAULT nextval('public.event_occurrence_recurrence_id_seq'::regclass);


--
-- Name: project id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project ALTER COLUMN id SET DEFAULT nextval('public.project_id_seq'::regclass);


--
-- Name: project_event id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project_event ALTER COLUMN id SET DEFAULT nextval('public.project_event_id_seq'::regclass);


--
-- Name: space id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space ALTER COLUMN id SET DEFAULT nextval('public.space_id_seq'::regclass);


--
-- Name: term id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.term ALTER COLUMN id SET DEFAULT nextval('public.term_id_seq'::regclass);


--
-- Name: term_relation id; Type: DEFAULT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.term_relation ALTER COLUMN id SET DEFAULT nextval('public.term_relation_id_seq'::regclass);


--
-- Data for Name: _mesoregiao; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public._mesoregiao (gid, id, nm_meso, cd_geocodu, geom) FROM stdin;
\.


--
-- Name: _mesoregiao_gid_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public._mesoregiao_gid_seq', 1, false);


--
-- Data for Name: _microregiao; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public._microregiao (gid, id, nm_micro, cd_geocodu, geom) FROM stdin;
\.


--
-- Name: _microregiao_gid_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public._microregiao_gid_seq', 1, false);


--
-- Data for Name: _municipios; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public._municipios (gid, id, cd_geocodm, nm_municip, geom) FROM stdin;
\.


--
-- Name: _municipios_gid_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public._municipios_gid_seq', 1, false);


--
-- Data for Name: agent; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.agent (id, parent_id, user_id, type, name, location, _geo_location, short_description, long_description, create_timestamp, status, is_verified, public_location, update_timestamp, subsite_id) FROM stdin;
1	\N	1	1	Ben Rainir	(0,0)	0101000020E610000000000000000000000000000000000000	Descrição Curta		2021-03-20 00:00:00	1	f	f	2021-03-22 14:20:58	\N
3	\N	3	1	Valesca Dantas	(0,0)	0101000020E610000000000000000000000000000000000000	.		2021-03-22 14:32:57	1	f	f	2021-03-22 18:56:00	\N
5	\N	4	1	Valdo Mesquita	(0,0)	\N	\N	\N	2021-03-22 19:15:39	1	f	f	\N	\N
6	\N	5	1	LUIZ CARLOS DA COSTA	(-38.4921852000000015,-3.80296879999999993)	0101000020E6100000A1C9B4ECFF3E43C0BBAAFDE77A6C0EC0	Servidor Público da Setur-CE	Servidor Público da Setur-CE	2021-03-23 09:10:26	1	f	f	2021-03-23 09:48:48	\N
9	\N	8	1	Maria José Teste	(0,0)	0101000020E610000000000000000000000000000000000000	garçonete		2021-03-23 16:08:02	1	f	f	2021-03-23 16:12:30	\N
8	\N	7	1	Antonio Marques de Oliveira Junior	(0,0)	0101000020E610000000000000000000000000000000000000	Analista		2021-03-23 14:41:48	1	f	f	2021-03-23 16:19:28	\N
10	\N	9	1	Bruno	(0,0)	0101000020E610000000000000000000000000000000000000	Descrição do Bruno		2021-03-24 01:46:12	1	f	f	2021-03-24 01:46:46	\N
4	3	3	2	SECRETARIA DO TURISMO DO ESTADO DO CEARÁ	(0,0)	0101000020E610000000000000000000000000000000000000	SECRETARIA DO TURISMO DO ESTADO DO CEARÁ- SETUR		2021-03-22 17:24:47	1	f	t	2021-03-22 17:26:45	\N
11	\N	10	1	JOSE TEXTE	(0,0)	\N	\N	\N	2021-03-24 09:32:31	1	f	f	\N	\N
12	\N	11	1	JOAO TEXXTE	(-38.4803519000000023,-3.79196840000000002)	0101000020E61000002689CA2B7C3D43C03CB94B87F3550EC0	TEXXTE TEXXTE	KJLKDJKJKLF KLJKLFJKL JKLJKLKJKLJFD	2021-03-24 09:40:09	1	f	f	2021-03-24 09:47:16	\N
13	\N	12	1	MARIA TEXXTE	(-38.4803519000000023,-3.79196840000000002)	0101000020E61000002689CA2B7C3D43C03CB94B87F3550EC0	maria texxte texxte	TEXXTE TEXXTE	2021-03-24 09:57:53	1	f	f	2021-03-24 10:01:06	\N
15	\N	14	1	MARIA TEXXXTE	(-38.4915457000000032,-3.73843810000000021)	0101000020E6100000A6FE30F8EA3E43C089F60C3C52E80DC0	kljkkjjfkj jkjkfjkj kkjklfjklj jkljkljkl jk		2021-03-24 19:51:17	1	f	f	2021-03-24 19:53:58	\N
14	\N	13	1	JOSE TEXXTE	(-39.489252045750618,-5.85923348715112002)	0101000020E61000000000A0CF9FBE43C0B5C43BE7DA6F17C0	Yesye		2021-03-24 19:32:10	1	f	f	2021-03-25 09:52:57	\N
17	\N	16	1	MARIO TEXXTE	(-38.4915457000000032,-3.73843810000000021)	0101000020E6100000A6FE30F8EA3E43C089F60C3C52E80DC0	fkljkjkj kjkjkj kjkfj kjkfjk jdf	KJKLJKL KJKJFK JK KFJ KJK JKJF	2021-03-25 10:06:25	1	f	f	2021-03-25 10:08:43	\N
16	\N	15	1	maria Florencia fidalgo	(-38.4805563999999976,-3.84503210000000006)	0101000020E610000016F142DF823D43C0C68F8C30A0C20EC0	teste teste teste		2021-03-25 09:59:26	1	f	f	2021-03-25 10:08:56	\N
18	\N	17	1	Antonia Rodrigues Mesquita	(0,0)	\N	\N	\N	2021-03-25 10:09:04	1	f	f	\N	\N
20	\N	19	1	Francisco Borges	(0,0)	\N	\N	\N	2021-03-25 10:27:39	1	f	f	\N	\N
19	\N	18	1	Ana Clara Beco da Silva	(-38.5009719000000032,-3.73971749999999981)	0101000020E6100000855BE3D81F4043C0253B3602F1EA0DC0	Gerente de restaurante e bar		2021-03-25 10:18:26	1	f	t	2021-03-25 10:29:19	\N
21	\N	20	1	Alice Becco da Silva Rios	(-38.5009719000000032,-3.73971749999999981)	0101000020E6100000855BE3D81F4043C0253B3602F1EA0DC0	Arquiteta e urbanista		2021-03-25 10:51:35	1	f	f	2021-03-25 10:54:46	\N
22	\N	21	1	NAIRTON OLIVEIRA	(0,0)	0101000020E610000000000000000000000000000000000000	Nairton		2021-03-25 11:41:53	1	f	f	2021-03-25 11:45:40	\N
7	\N	6	1	FABRICIO FIDALGO LOUSADA REGADAS	(0,0)	0101000020E610000000000000000000000000000000000000	Validador		2021-03-23 09:27:18	1	f	f	2021-03-25 14:55:52	\N
23	\N	22	1	carlos texxte	(0,0)	0101000020E610000000000000000000000000000000000000	kjkjkl kjkjkjk kjkkjj kjkjkj gkjklgfjkj kjkjfkjk kjdkjkfjkj 		2021-03-26 09:09:42	1	f	f	2021-03-26 09:14:45	\N
24	\N	23	1	silvio texxte	(-38.4803519000000023,-3.79196840000000002)	0101000020E61000002689CA2B7C3D43C03CB94B87F3550EC0	kjkjkf kjjfj kjfjkjkljdfkjfkjdf jhjj jhjhjhjh  jhjhjh		2021-03-26 10:07:10	1	f	f	2021-03-26 10:14:16	\N
\.


--
-- Name: agent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.agent_id_seq', 24, true);


--
-- Data for Name: agent_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.agent_meta (object_id, key, value, id) FROM stdin;
1	documento	012.930.843-95	1
3	documento	057.499.873-02	3
3	emailPrivado	valescadant@gmail.com	4
3	emailPublico	valescadant@gmail.com	5
4	site	https://www.setur.ce.gov.br/	6
4	telefonePublico	(85) 3195-0200	7
4	telefone1	(85) 3195-0200	8
4	En_Municipio	FORTALEZA	9
4	En_Estado	CE	10
5	emailPrivado	valdo.mesquita@gmail.com	12
5	emailPublico	valdo.mesquita@gmail.com	13
6	documento	231.833.223-15	14
6	emailPrivado	luiz.carlos@setur.ce.gov.br	15
6	emailPublico	luiz.carlos@setur.ce.gov.br	16
7	documento	018.413.443-97	17
7	emailPrivado	fabricio.fidalgo@setur.ce.gov.br	18
7	emailPublico	fabricio.fidalgo@setur.ce.gov.br	19
6	nomeCompleto	LUIZ CARLOS DA COSTA	20
6	dataDeNascimento	1963-07-16	21
6	genero	Homem Cis	22
6	orientacaoSexual	Heterossexual	23
6	raca	Parda	24
6	telefonePublico	(85) 3195-0265	25
6	endereco	Rua Doutor Walter Porto, 235 , Cambeba, 60822-250, Fortaleza, CE	27
6	En_CEP	60822-250	28
6	En_Nome_Logradouro	Rua Doutor Walter Porto	29
6	En_Num	235	30
6	En_Bairro	Cambeba	31
6	En_Municipio	Fortaleza	32
6	En_Estado	CE	33
8	documento	641.830.173-00	34
8	emailPrivado	marques.junior@setur.ce.gov.br	35
8	emailPublico	marques.junior@setur.ce.gov.br	36
9	documento	021.270.050-23	37
9	emailPrivado	valescad192@gmail.com	38
9	emailPublico	valescad192@gmail.com	39
9	nomeCompleto	gatarrefbsnsm	40
9	dataDeNascimento	2000-03-02	41
9	telefone1	(58) 245974452	42
9	En_CEP	60015-141	43
9	En_Nome_Logradouro	Rua Teresa Cristina	44
9	En_Num	025	45
9	En_Bairro	Farias Brito	46
9	En_Municipio	Fortaleza	47
9	En_Estado	CE	48
9	genero	Mulher Cis	49
9	raca	Branca	50
8	dataDeNascimento	1986-03-18	51
13	genero	Mulher Cis	107
6	telefone1	(85) 32711312	26
6	telefone2	(85) 985473896	52
7	nomeCompleto	FABRICIO FIDALGO LOUSADA REGADAS	53
7	dataDeNascimento	1993-04-07	54
7	telefone1	(85) 996303822	55
7	telefone2	(85) 996303822	56
7	En_CEP	60871-165	57
7	En_Nome_Logradouro	Estrada Barão de Aquiraz	58
7	En_Num	980	59
7	En_Bairro	Messejana	60
7	En_Municipio	Fortaleza	61
7	En_Estado	CE	62
7	genero	Homem Cis	63
7	raca	Branca	64
10	documento	604.344.523-94	65
10	emailPrivado	bruno@gmail.com	66
10	emailPublico	bruno@gmail.com	67
5	documento	323.019.363-68	11
5	nomeCompleto	JOSÉ VALDO MESQUITA	68
5	telefone1	(85) 986122132	70
5	telefone2	(85) 986122132	71
5	En_CEP	60810-786	72
5	En_Nome_Logradouro	Avenida Rogaciano Leite	73
5	En_Num	800	74
5	En_Complemento	aPT 203 a	75
5	En_Bairro	Salinas	76
5	En_Municipio	Fortaleza	77
5	En_Estado	CE	78
5	genero	Homem Cis	79
5	raca	Branca	80
11	documento	123.456.789-09	81
11	emailPrivado	jose.texte@gmail.com	82
11	emailPublico	jose.texte@gmail.com	83
12	documento	234.567.890-92	84
12	emailPrivado	joao.texxte@gmail.com	85
12	emailPublico	joao.texxte@gmail.com	86
12	nomeCompleto	JOAO TEXXTE	87
12	dataDeNascimento	1970-01-15	88
12	genero	Homem Cis	89
12	orientacaoSexual	Heterossexual	90
12	raca	Branca	91
12	telefonePublico	(85) 23456-7890	92
12	endereco	Avenida Washington Soares, 2345 , Edson Queiroz, 60811-341, Fortaleza, CE	94
12	En_CEP	60811-341	95
12	En_Nome_Logradouro	Avenida Washington Soares	96
12	En_Num	2345	97
12	En_Bairro	Edson Queiroz	98
12	En_Municipio	Fortaleza	99
12	En_Estado	CE	100
12	telefone1	(85) 234567890	93
12	telefone2	(85) 234566789	101
13	documento	345.678.901-75	102
13	emailPrivado	maria.texxte@gmail.com	103
13	emailPublico	maria.texxte@gmail.com	104
13	nomeCompleto	MARIA TEXXTE	105
13	dataDeNascimento	1980-01-15	106
13	orientacaoSexual	Heterossexual	108
13	telefonePublico	(85) 4567-8900	109
13	endereco	Avenida Washington Soares, 3456 , Edson Queiroz, 60811-341, Fortaleza, CE	111
13	En_CEP	60811-341	112
13	En_Nome_Logradouro	Avenida Washington Soares	113
13	En_Num	3456	114
13	En_Bairro	Edson Queiroz	115
13	En_Municipio	Fortaleza	116
13	En_Estado	CE	117
13	telefone1	(85) 46789000	110
13	telefone2	(85) 456789000	118
13	raca	Parda	119
5	dataDeNascimento	1970-03-28	69
14	emailPrivado	jose.texxte@gmail.com	121
14	emailPublico	jose.texxte@gmail.com	122
15	documento	901.234.567-70	123
15	emailPrivado	maria.texxxte@gmail.com	124
15	emailPublico	maria.texxxte@gmail.com	125
15	nomeCompleto	MARIA TEXXXTE	126
15	dataDeNascimento	1981-02-15	127
15	genero	Mulher Cis	128
15	telefonePublico	(85) 3145-2300	129
15	endereco	Avenida Santos Dumont, 1517, Apt 1720, Aldeota, 60150-161, Fortaleza, CE	131
15	En_CEP	60150-161	132
15	En_Nome_Logradouro	Avenida Santos Dumont	133
15	En_Num	1517	134
15	En_Complemento	Apt 1720	135
15	En_Bairro	Aldeota	136
15	En_Municipio	Fortaleza	137
15	En_Estado	CE	138
15	telefone1	(85) 931452300	130
15	raca	Não Informar	139
14	documento	05749987302	120
14	telefonePublico	(88) 88888-8888	140
14	telefone1	(88) 88888-8888	141
16	documento	758.359.753-68	142
16	emailPrivado	fabricio.fidalgo@hotmail.com	143
16	emailPublico	fabricio.fidalgo@hotmail.com	144
17	documento	546.225.326-54	145
17	emailPrivado	mario.texxte@gmail.com	146
17	emailPublico	mario.texxte@gmail.com	147
17	nomeCompleto	MARIO TEXXTE	148
17	dataDeNascimento	1979-01-25	149
17	genero	Homem Cis	150
17	raca	Amarela	151
17	telefonePublico	(85) 3245-5654	152
17	endereco	Avenida Santos Dumont, 322 , Aldeota, 60150-161, Fortaleza, CE	154
17	En_CEP	60150-161	155
17	En_Nome_Logradouro	Avenida Santos Dumont	156
17	En_Num	322	157
17	En_Bairro	Aldeota	158
17	En_Municipio	Fortaleza	159
17	En_Estado	CE	160
16	nomeCompleto	MARIA FLOrENCIA FIDALGO	161
16	dataDeNascimento	1967-10-23	162
16	genero	Mulher Cis	163
16	orientacaoSexual	Heterossexual	164
16	raca	Branca	165
16	telefonePublico	(85) 3459-0352	166
16	endereco	Estrada Barão de Aquiraz, 980 , Messejana, 60871-165, Fortaleza, CE	168
16	En_CEP	60871-165	169
16	En_Nome_Logradouro	Estrada Barão de Aquiraz	170
16	En_Num	980	171
16	En_Bairro	Messejana	172
16	En_Municipio	Fortaleza	173
16	En_Estado	CE	174
18	documento	555.195.473-00	175
18	emailPrivado	antoniarodrigues160646@gmail.com	176
18	emailPublico	antoniarodrigues160646@gmail.com	177
17	telefone1	(85) 32455654	153
17	telefone2	(85) 993245564	178
16	telefone1	(85) 34590352	167
19	documento	142.188.283-34	179
19	emailPrivado	anaclarabecco@hotmail.com	180
19	emailPublico	anaclarabecco@hotmail.com	181
20	documento	300.749.913-53	182
20	emailPrivado	borges.mesquita@gmail.com	183
20	emailPublico	borges.mesquita@gmail.com	184
19	nomeCompleto	Ana Clara Beco da Silva	185
19	dataDeNascimento	1950-06-12	186
19	genero	Mulher Cis	187
19	orientacaoSexual	Heterossexual	188
19	raca	Parda	189
19	telefonePublico	(85) 99989-7118	190
19	endereco	Avenida Padre Antônio Tomás, 3433, AP 900, Cocó, 60192-125, Fortaleza, CE	191
19	En_CEP	60192-125	192
19	En_Nome_Logradouro	Avenida Padre Antônio Tomás	193
19	En_Num	3433	194
19	En_Complemento	AP 900	195
19	En_Bairro	Cocó	196
19	En_Municipio	Fortaleza	197
19	En_Estado	CE	198
20	nomeCompleto	FRANCISCO BORGES	199
20	dataDeNascimento	1968-04-22	200
20	telefone1	(85) 986122132	201
20	telefone2	(85) 986122132	202
20	En_CEP	60830-105	203
20	En_Nome_Logradouro	Rua Rafael Tobias	204
20	En_Num	2113	205
20	En_Complemento	CASA 1	206
20	En_Bairro	José de Alencar	207
20	En_Municipio	Fortaleza	208
20	En_Estado	CE	209
20	genero	Homem Cis	210
20	raca	Branca	211
19	telefone1	(85) 999897118	212
19	telefone2	(85) 999240967	213
21	documento	902.909.333-15	214
21	emailPrivado	alicebecco@hotmail.com	215
21	emailPublico	alicebecco@hotmail.com	216
21	nomeCompleto	Alice Becco da Silva Rios	217
21	dataDeNascimento	1981-07-13	218
21	genero	Mulher Cis	219
21	orientacaoSexual	Heterossexual	220
21	raca	Parda	221
21	telefonePublico	(85) 99924-0967	222
21	endereco	Avenida Padre Antônio Tomás, 3433, AP 900, Cocó, 60192-125, Fortaleza, CE	223
21	En_CEP	60192-125	224
21	En_Nome_Logradouro	Avenida Padre Antônio Tomás	225
21	En_Num	3433	226
21	En_Complemento	AP 900	227
21	En_Bairro	Cocó	228
21	En_Municipio	Fortaleza	229
21	En_Estado	CE	230
22	documento	926.782.703-00	231
22	emailPrivado	nairton@gmail.com	232
22	emailPublico	nairton@gmail.com	233
22	dataDeNascimento	1981-07-06	234
22	genero	Homem Cis	235
22	orientacaoSexual	Heterossexual	236
22	raca	Branca	237
22	telefonePublico	(85) 98668-8091	238
22	telefone1	(85) 98668-8091	239
3	nomeCompleto	skgdsavjdgs	240
3	dataDeNascimento	2021-03-24	241
3	telefone1	(88) 888888888	242
3	En_CEP	63050-645	243
3	En_Nome_Logradouro	Rua Doutor José Paracampos	244
3	En_Num	222	245
3	En_Bairro	Romeirão	246
3	En_Municipio	Juazeiro do Norte	247
3	En_Estado	CE	248
3	genero	Mulher Cis	249
3	raca	Branca	250
23	documento	456.235.122-59	251
23	emailPrivado	carlos.texxte@gmail.com	252
23	emailPublico	carlos.texxte@gmail.com	253
23	nomeCompleto	carlos texxte	254
23	dataDeNascimento	1981-02-22	255
23	genero	Homem Cis	256
23	orientacaoSexual	Heterossexual	257
23	raca	Preta	258
23	telefonePublico	(85) 99688-2133	259
23	En_Nome_Logradouro	Praça das Graviolas	262
23	En_Bairro	Centro	263
23	En_Municipio	Fortaleza	264
23	En_Estado	CE	265
23	telefone1	(85) 996548556	266
23	endereco		260
23	En_CEP	60110-160	261
23	En_Num	894	267
23	En_Complemento	Fundos	268
24	documento	548.221.356-08	269
24	emailPrivado	silvio.texxte@gmail.com	270
24	emailPublico	silvio.texxte@gmail.com	271
24	nomeCompleto	empresa texxte	272
24	dataDeNascimento	1980-03-02	273
24	genero	Homem Cis	274
24	telefonePublico	(85) 99888-2512	275
24	endereco	Avenida Washington Soares, 546 , Edson Queiroz, 60811-341, Fortaleza, CE	276
24	En_CEP	60811-341	277
24	En_Nome_Logradouro	Avenida Washington Soares	278
24	En_Num	546	279
24	En_Bairro	Edson Queiroz	280
24	En_Municipio	Fortaleza	281
24	En_Estado	CE	282
24	raca	Branca	283
24	telefone1	(85) 996522145	284
\.


--
-- Name: agent_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.agent_meta_id_seq', 284, true);


--
-- Data for Name: agent_relation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.agent_relation (id, agent_id, object_type, object_id, type, has_control, create_timestamp, status) FROM stdin;
1	1	MapasCulturais\\Entities\\Project	2	group-admin	t	2021-03-22 15:23:13	1
2	3	MapasCulturais\\Entities\\Project	2	group-admin	t	2021-03-22 17:27:22	1
6	3	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1	group-admin	t	2021-03-23 16:04:26	1
10	7	MapasCulturais\\Entities\\Opportunity	1	group-admin	t	2021-03-24 18:07:57	1
11	6	MapasCulturais\\Entities\\Opportunity	1	group-admin	t	2021-03-24 18:09:29	1
12	8	MapasCulturais\\Entities\\Opportunity	1	group-admin	t	2021-03-24 18:09:47	1
13	21	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1	group-admin	t	2021-03-25 14:57:57	1
14	7	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1	group-admin	t	2021-03-25 14:58:07	1
15	6	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1	group-admin	t	2021-03-25 16:58:30	1
16	21	MapasCulturais\\Entities\\Opportunity	1	group-admin	t	2021-03-26 10:51:13	1
17	5	MapasCulturais\\Entities\\Opportunity	1	group-admin	t	2021-03-27 00:14:56	1
\.


--
-- Name: agent_relation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.agent_relation_id_seq', 17, true);


--
-- Data for Name: db_update; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.db_update (name, exec_time) FROM stdin;
alter tablel term taxonomy type	2021-03-20 21:49:20.379405
new random id generator	2021-03-20 21:49:20.379405
migrate gender	2021-03-20 21:49:20.379405
create table user apps	2021-03-20 21:49:20.379405
create table user_meta	2021-03-20 21:49:20.379405
create seal and seal relation tables	2021-03-20 21:49:20.379405
resize entity meta key columns	2021-03-20 21:49:20.379405
create registration field configuration table	2021-03-20 21:49:20.379405
alter table registration_file_configuration add categories	2021-03-20 21:49:20.379405
create saas tables	2021-03-20 21:49:20.379405
rename saas tables to subsite	2021-03-20 21:49:20.379405
remove parent_url and add alias_url	2021-03-20 21:49:20.379405
verified seal migration	2021-03-20 21:49:20.379405
create update timestamp entities	2021-03-20 21:49:20.379405
alter table role add column subsite_id	2021-03-20 21:49:20.379405
Fix field options field type from registration field configuration	2021-03-20 21:49:20.379405
ADD columns subsite_id	2021-03-20 21:49:20.379405
remove subsite slug column	2021-03-20 21:49:20.379405
add subsite verified_seals column	2021-03-20 21:49:20.379405
update entities last_update_timestamp with user last log timestamp	2021-03-20 21:49:20.379405
Created owner seal relation field	2021-03-20 21:49:20.379405
create table pcache	2021-03-20 21:49:20.379405
function create pcache id sequence 2	2021-03-20 21:49:20.379405
Add field for maximum size from registration field configuration	2021-03-20 21:49:20.379405
Add notification type for compliant and suggestion messages	2021-03-20 21:49:20.379405
create entity revision tables	2021-03-20 21:49:20.379405
ALTER TABLE file ADD COLUMN path	2021-03-20 21:49:20.379405
*_meta drop all indexes again	2021-03-20 21:49:20.379405
recreate *_meta indexes	2021-03-20 21:49:20.379405
create permission cache pending table2	2021-03-20 21:49:20.379405
create opportunity tables	2021-03-20 21:49:20.379405
DROP CONSTRAINT registration_project_fk");	2021-03-20 21:49:20.379405
fix opportunity parent FK	2021-03-20 21:49:20.379405
fix opportunity type 35	2021-03-20 21:49:20.379405
create opportunity sequence	2021-03-20 21:49:20.379405
update opportunity_meta_id sequence	2021-03-20 21:49:20.379405
rename opportunity_meta key isProjectPhase to isOpportunityPhase	2021-03-20 21:49:20.379405
migrate introInscricoes value to shortDescription	2021-03-20 21:49:20.379405
ALTER TABLE registration ADD consolidated_result	2021-03-20 21:49:20.379405
create evaluation methods tables	2021-03-20 21:49:20.379405
create registration_evaluation table	2021-03-20 21:49:20.379405
ALTER TABLE opportunity ALTER type DROP NOT NULL;	2021-03-20 21:49:20.379405
create seal relation renovation flag field	2021-03-20 21:49:20.379405
create seal relation validate date	2021-03-20 21:49:20.379405
update seal_relation set validate_date	2021-03-20 21:49:20.379405
refactor of entity meta keky value indexes	2021-03-20 21:49:20.379405
DROP index registration_meta_value_idx	2021-03-20 21:49:20.379405
CREATE SEQUENCE REGISTRATION SPACE RELATION registration_space_relation_id_seq	2021-03-20 21:49:20.379405
CREATE TABLE spacerelation	2021-03-20 21:49:20.379405
ALTER TABLE registration	2021-03-20 21:49:20.379405
altertable registration_file_and_files_add_order	2021-03-20 21:49:20.379405
replace subsite entidades_habilitadas values	2021-03-20 21:49:20.379405
replace subsite cor entidades values	2021-03-20 21:49:20.379405
ALTER TABLE file ADD private and update	2021-03-20 21:49:20.379405
move private files	2021-03-20 21:49:20.379405
create permission cache sequence	2021-03-20 21:49:20.379405
create evaluation methods sequence	2021-03-20 21:49:20.379405
change opportunity field agent_id not null	2021-03-20 21:49:20.379405
alter table registration add column number	2021-03-20 21:49:20.379405
update registrations set number fixed	2021-03-20 21:49:20.379405
alter table registration add column valuers_exceptions_list	2021-03-20 21:49:20.379405
create event attendance table	2021-03-20 21:49:20.379405
create procuration table	2021-03-20 21:49:20.379405
alter table registration_field_configuration add column config	2021-03-20 21:49:20.379405
recreate ALL FKs	2021-03-20 21:49:20.379405
create object_type enum type	2021-03-20 21:49:20.379405
create permission_action enum type	2021-03-20 21:49:20.379405
alter tables to use enum types	2021-03-20 21:49:20.379405
alter table permission_cache_pending add column status	2021-03-20 21:49:20.379405
Add field for mask from registration field configuration	2021-03-20 21:49:20.379405
Add field for mask_options size from registration field configuration	2021-03-20 21:49:20.379405
update taxonomy slug tag	2021-03-20 21:49:20.379405
update taxonomy slug area	2021-03-20 21:49:20.379405
update taxonomy slug linguagem	2021-03-20 21:49:20.379405
update taxonomy slug publico	2021-03-20 21:49:20.379405
update taxonomy slug municipio	2021-03-20 21:49:20.379405
change type of evaluation menthods configurations	2021-03-20 21:49:20.379405
recreate pcache	2021-03-20 21:49:22.397129
generate file path	2021-03-20 21:49:22.403626
create entities history entries	2021-03-20 21:49:22.409171
create entities updated revision	2021-03-20 21:49:22.415553
fix update timestamp of revisioned entities	2021-03-20 21:49:22.421103
consolidate registration result	2021-03-20 21:49:22.426557
create avatar thumbs	2021-03-20 22:02:47.464202
\.


--
-- Data for Name: entity_revision; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.entity_revision (id, user_id, object_id, object_type, create_timestamp, action, message) FROM stdin;
1	1	1	MapasCulturais\\Entities\\Agent	2021-03-20 00:00:00	created	Registro criado.
2	1	1	MapasCulturais\\Entities\\Agent	2021-03-20 19:23:25	modified	Registro atualizado.
3	1	1	MapasCulturais\\Entities\\Agent	2021-03-22 14:20:58	modified	Registro atualizado.
4	3	3	MapasCulturais\\Entities\\Agent	2021-03-22 14:32:57	created	Registro criado.
5	3	3	MapasCulturais\\Entities\\Agent	2021-03-22 14:34:10	modified	Registro atualizado.
6	3	4	MapasCulturais\\Entities\\Agent	2021-03-22 17:24:47	created	Registro criado.
7	3	4	MapasCulturais\\Entities\\Agent	2021-03-22 17:26:45	modified	Registro atualizado.
8	3	1	MapasCulturais\\Entities\\Space	2021-03-22 18:03:07	created	Registro criado.
9	3	3	MapasCulturais\\Entities\\Agent	2021-03-22 18:54:10	modified	Registro atualizado.
10	3	3	MapasCulturais\\Entities\\Agent	2021-03-22 18:56:01	modified	Registro atualizado.
11	4	5	MapasCulturais\\Entities\\Agent	2021-03-22 19:15:39	created	Registro criado.
12	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 09:10:26	created	Registro criado.
13	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 09:27:18	created	Registro criado.
14	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 09:44:58	modified	Registro atualizado.
15	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 09:45:11	modified	Registro atualizado.
16	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 09:48:48	modified	Registro atualizado.
17	7	8	MapasCulturais\\Entities\\Agent	2021-03-23 14:41:48	created	Registro criado.
18	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:08:02	created	Registro criado.
19	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:09:29	modified	Registro atualizado.
20	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:10:53	modified	Registro atualizado.
21	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:11:19	modified	Registro atualizado.
22	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:11:38	modified	Registro atualizado.
23	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:12:30	modified	Registro atualizado.
24	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:13:09	modified	Registro atualizado.
25	8	9	MapasCulturais\\Entities\\Agent	2021-03-23 16:13:12	modified	Registro atualizado.
26	7	8	MapasCulturais\\Entities\\Agent	2021-03-23 16:19:28	modified	Registro atualizado.
27	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 16:21:39	modified	Registro atualizado.
28	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 16:21:42	modified	Registro atualizado.
29	5	6	MapasCulturais\\Entities\\Agent	2021-03-23 16:21:56	modified	Registro atualizado.
30	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:24:30	modified	Registro atualizado.
31	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:24:49	modified	Registro atualizado.
32	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:25:00	modified	Registro atualizado.
33	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:25:08	modified	Registro atualizado.
34	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:25:21	modified	Registro atualizado.
35	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:25:33	modified	Registro atualizado.
36	6	7	MapasCulturais\\Entities\\Agent	2021-03-23 16:25:38	modified	Registro atualizado.
37	9	10	MapasCulturais\\Entities\\Agent	2021-03-24 01:46:12	created	Registro criado.
38	9	10	MapasCulturais\\Entities\\Agent	2021-03-24 01:46:46	modified	Registro atualizado.
39	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:05:31	modified	Registro atualizado.
40	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:06:36	modified	Registro atualizado.
41	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:06:54	modified	Registro atualizado.
42	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:07:03	modified	Registro atualizado.
43	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:07:13	modified	Registro atualizado.
44	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:09:33	modified	Registro atualizado.
45	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:10:18	modified	Registro atualizado.
46	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 09:10:22	modified	Registro atualizado.
47	10	11	MapasCulturais\\Entities\\Agent	2021-03-24 09:32:31	created	Registro criado.
48	11	12	MapasCulturais\\Entities\\Agent	2021-03-24 09:40:09	created	Registro criado.
49	11	12	MapasCulturais\\Entities\\Agent	2021-03-24 09:47:16	modified	Registro atualizado.
50	11	12	MapasCulturais\\Entities\\Agent	2021-03-24 09:49:50	modified	Registro atualizado.
51	11	12	MapasCulturais\\Entities\\Agent	2021-03-24 09:50:03	modified	Registro atualizado.
52	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 09:57:53	created	Registro criado.
53	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 10:00:56	modified	Registro atualizado.
54	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 10:01:06	modified	Registro atualizado.
55	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 10:02:15	modified	Registro atualizado.
56	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 10:02:26	modified	Registro atualizado.
57	12	13	MapasCulturais\\Entities\\Agent	2021-03-24 10:02:51	modified	Registro atualizado.
58	4	5	MapasCulturais\\Entities\\Agent	2021-03-24 18:22:39	modified	Registro atualizado.
59	13	14	MapasCulturais\\Entities\\Agent	2021-03-24 19:32:10	created	Registro criado.
60	14	15	MapasCulturais\\Entities\\Agent	2021-03-24 19:51:17	created	Registro criado.
61	14	15	MapasCulturais\\Entities\\Agent	2021-03-24 19:53:58	modified	Registro atualizado.
62	14	15	MapasCulturais\\Entities\\Agent	2021-03-24 19:56:25	modified	Registro atualizado.
63	14	15	MapasCulturais\\Entities\\Agent	2021-03-24 19:57:13	modified	Registro atualizado.
64	3	14	MapasCulturais\\Entities\\Agent	2021-03-25 09:52:57	modified	Registro atualizado.
65	15	16	MapasCulturais\\Entities\\Agent	2021-03-25 09:59:26	created	Registro criado.
66	16	17	MapasCulturais\\Entities\\Agent	2021-03-25 10:06:25	created	Registro criado.
67	16	17	MapasCulturais\\Entities\\Agent	2021-03-25 10:08:26	modified	Registro atualizado.
68	15	16	MapasCulturais\\Entities\\Agent	2021-03-25 10:08:31	modified	Registro atualizado.
69	16	17	MapasCulturais\\Entities\\Agent	2021-03-25 10:08:43	modified	Registro atualizado.
70	15	16	MapasCulturais\\Entities\\Agent	2021-03-25 10:08:56	modified	Registro atualizado.
71	17	18	MapasCulturais\\Entities\\Agent	2021-03-25 10:09:04	created	Registro criado.
72	16	17	MapasCulturais\\Entities\\Agent	2021-03-25 10:09:58	modified	Registro atualizado.
73	16	17	MapasCulturais\\Entities\\Agent	2021-03-25 10:10:14	modified	Registro atualizado.
74	15	16	MapasCulturais\\Entities\\Agent	2021-03-25 10:12:30	modified	Registro atualizado.
75	18	19	MapasCulturais\\Entities\\Agent	2021-03-25 10:18:26	created	Registro criado.
76	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:27:39	created	Registro criado.
77	18	19	MapasCulturais\\Entities\\Agent	2021-03-25 10:29:02	modified	Registro atualizado.
78	18	19	MapasCulturais\\Entities\\Agent	2021-03-25 10:29:19	modified	Registro atualizado.
79	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:30:48	modified	Registro atualizado.
80	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:31:05	modified	Registro atualizado.
81	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:31:15	modified	Registro atualizado.
82	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:31:30	modified	Registro atualizado.
83	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:32:04	modified	Registro atualizado.
84	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:32:19	modified	Registro atualizado.
85	19	20	MapasCulturais\\Entities\\Agent	2021-03-25 10:32:22	modified	Registro atualizado.
86	18	19	MapasCulturais\\Entities\\Agent	2021-03-25 10:34:28	modified	Registro atualizado.
87	18	19	MapasCulturais\\Entities\\Agent	2021-03-25 10:34:40	modified	Registro atualizado.
88	20	21	MapasCulturais\\Entities\\Agent	2021-03-25 10:51:35	created	Registro criado.
89	20	21	MapasCulturais\\Entities\\Agent	2021-03-25 10:54:46	modified	Registro atualizado.
90	21	22	MapasCulturais\\Entities\\Agent	2021-03-25 11:41:53	created	Registro criado.
91	21	22	MapasCulturais\\Entities\\Agent	2021-03-25 11:45:40	modified	Registro atualizado.
92	6	7	MapasCulturais\\Entities\\Agent	2021-03-25 14:55:52	modified	Registro atualizado.
93	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 16:59:59	modified	Registro atualizado.
94	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 17:00:05	modified	Registro atualizado.
95	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 17:00:12	modified	Registro atualizado.
96	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 17:00:28	modified	Registro atualizado.
97	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 17:00:46	modified	Registro atualizado.
98	3	3	MapasCulturais\\Entities\\Agent	2021-03-25 17:00:48	modified	Registro atualizado.
99	22	23	MapasCulturais\\Entities\\Agent	2021-03-26 09:09:42	created	Registro criado.
100	22	23	MapasCulturais\\Entities\\Agent	2021-03-26 09:14:45	modified	Registro atualizado.
101	22	23	MapasCulturais\\Entities\\Agent	2021-03-26 09:51:04	modified	Registro atualizado.
102	22	23	MapasCulturais\\Entities\\Agent	2021-03-26 09:51:55	modified	Registro atualizado.
103	23	24	MapasCulturais\\Entities\\Agent	2021-03-26 10:07:10	created	Registro criado.
104	23	24	MapasCulturais\\Entities\\Agent	2021-03-26 10:14:16	modified	Registro atualizado.
105	23	24	MapasCulturais\\Entities\\Agent	2021-03-26 10:28:26	modified	Registro atualizado.
106	23	24	MapasCulturais\\Entities\\Agent	2021-03-26 10:36:39	modified	Registro atualizado.
\.


--
-- Data for Name: entity_revision_data; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.entity_revision_data (id, "timestamp", key, value) FROM stdin;
1	2021-03-20 18:49:22	_type	1
2	2021-03-20 18:49:22	name	"Ben Rainir"
3	2021-03-20 18:49:22	publicLocation	null
4	2021-03-20 18:49:22	location	{"latitude":0,"longitude":0}
5	2021-03-20 18:49:22	shortDescription	null
6	2021-03-20 18:49:22	longDescription	null
7	2021-03-20 18:49:22	createTimestamp	{"date":"2021-03-20 00:00:00.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
8	2021-03-20 18:49:22	status	1
9	2021-03-20 18:49:22	updateTimestamp	{"date":"2021-03-20 00:00:00.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
10	2021-03-20 18:49:22	_subsiteId	null
11	2021-03-20 18:49:22	documento	"012.930.843-95"
12	2021-03-20 19:23:25	publicLocation	false
13	2021-03-20 19:23:25	location	{"latitude":"0","longitude":"0"}
14	2021-03-20 19:23:25	shortDescription	"Descri\\u00e7\\u00e3o Curta"
15	2021-03-20 19:23:25	longDescription	""
16	2021-03-20 19:23:25	updateTimestamp	{"date":"2021-03-20 19:23:25.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
17	2021-03-20 19:23:25	_terms	{"":["Produ\\u00e7\\u00e3o Cultural"]}
18	2021-03-22 14:20:58	updateTimestamp	{"date":"2021-03-22 14:20:58.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
19	2021-03-22 14:32:58	_type	1
20	2021-03-22 14:32:58	name	"Francisca Valesca Viana Dantas"
21	2021-03-22 14:32:58	publicLocation	false
22	2021-03-22 14:32:58	location	{"latitude":"0","longitude":"0"}
23	2021-03-22 14:32:58	shortDescription	null
24	2021-03-22 14:32:58	longDescription	null
25	2021-03-22 14:32:58	createTimestamp	{"date":"2021-03-22 14:32:57.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
26	2021-03-22 14:32:58	status	1
27	2021-03-22 14:32:58	updateTimestamp	null
28	2021-03-22 14:32:58	_subsiteId	null
29	2021-03-22 14:32:58	documento	"057.499.873-02"
30	2021-03-22 14:32:58	emailPrivado	"valescadant@gmail.com"
31	2021-03-22 14:32:58	emailPublico	"valescadant@gmail.com"
32	2021-03-22 14:34:10	shortDescription	"."
33	2021-03-22 14:34:10	longDescription	""
34	2021-03-22 14:34:10	updateTimestamp	{"date":"2021-03-22 14:34:10.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
35	2021-03-22 14:34:10	_terms	{"":["Literatura","Leitura","Livro"]}
36	2021-03-22 17:24:48	_type	2
37	2021-03-22 17:24:48	name	"SECRETARIA DO TURISMO DO ESTADO DO CEAR\\u00c1"
38	2021-03-22 17:24:48	publicLocation	false
39	2021-03-22 17:24:48	location	{"latitude":"0","longitude":"0"}
40	2021-03-22 17:24:48	shortDescription	"SECRETARIA DO TURISMO DO ESTADO DO CEAR\\u00c1- SETUR"
41	2021-03-22 17:24:48	longDescription	null
42	2021-03-22 17:24:48	createTimestamp	{"date":"2021-03-22 17:24:47.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
43	2021-03-22 17:24:48	status	1
44	2021-03-22 17:24:48	updateTimestamp	null
45	2021-03-22 17:24:48	_subsiteId	null
46	2021-03-22 17:24:48	_terms	{"":["Turismo"]}
47	2021-03-22 17:26:45	publicLocation	true
48	2021-03-22 17:26:45	longDescription	""
49	2021-03-22 17:26:45	updateTimestamp	{"date":"2021-03-22 17:26:45.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
50	2021-03-22 17:26:45	parent	{"id":3,"name":"Francisca Valesca Viana Dantas","revision":5}
51	2021-03-22 17:26:45	site	"https:\\/\\/www.setur.ce.gov.br\\/"
52	2021-03-22 17:26:45	telefonePublico	"(85) 3195-0200"
53	2021-03-22 17:26:45	telefone1	"(85) 3195-0200"
54	2021-03-22 17:26:45	En_Municipio	"FORTALEZA"
55	2021-03-22 17:26:45	En_Estado	"CE"
56	2021-03-22 18:03:07	location	{"latitude":"0","longitude":"0"}
57	2021-03-22 18:03:07	name	"b,jv"
58	2021-03-22 18:03:07	public	false
59	2021-03-22 18:03:07	shortDescription	"bfuct"
60	2021-03-22 18:03:07	longDescription	null
61	2021-03-22 18:03:07	createTimestamp	{"date":"2021-03-22 18:03:07.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
62	2021-03-22 18:03:07	status	1
63	2021-03-22 18:03:07	_type	10
64	2021-03-22 18:03:07	_ownerId	3
65	2021-03-22 18:03:07	updateTimestamp	null
66	2021-03-22 18:03:07	_subsiteId	null
67	2021-03-22 18:03:07	owner	{"id":3,"name":"Francisca Valesca Viana Dantas","shortDescription":".","revision":5}
68	2021-03-22 18:03:07	_terms	{"":["Antropologia"]}
69	2021-03-22 18:54:10	name	"Valesca Dantas"
70	2021-03-22 18:54:10	updateTimestamp	{"date":"2021-03-22 18:54:10.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
71	2021-03-22 18:54:10	_spaces	[{"id":1,"name":"b,jv","revision":8}]
72	2021-03-22 18:56:01	updateTimestamp	{"date":"2021-03-22 18:56:00.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
73	2021-03-22 19:15:39	_type	1
74	2021-03-22 19:15:39	name	"Valdo Mesquita"
75	2021-03-22 19:15:39	publicLocation	false
76	2021-03-22 19:15:39	location	{"latitude":"0","longitude":"0"}
77	2021-03-22 19:15:39	shortDescription	null
78	2021-03-22 19:15:39	longDescription	null
79	2021-03-22 19:15:39	createTimestamp	{"date":"2021-03-22 19:15:39.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
80	2021-03-22 19:15:39	status	1
81	2021-03-22 19:15:39	updateTimestamp	null
82	2021-03-22 19:15:39	_subsiteId	null
83	2021-03-22 19:15:39	documento	"996.630.460-66"
84	2021-03-22 19:15:39	emailPrivado	"valdo.mesquita@gmail.com"
85	2021-03-22 19:15:39	emailPublico	"valdo.mesquita@gmail.com"
86	2021-03-23 09:10:26	_type	1
87	2021-03-23 09:10:26	name	"LUIZ CARLOS DA COSTA"
88	2021-03-23 09:10:26	publicLocation	false
89	2021-03-23 09:10:26	location	{"latitude":"0","longitude":"0"}
90	2021-03-23 09:10:26	shortDescription	null
91	2021-03-23 09:10:26	longDescription	null
92	2021-03-23 09:10:26	createTimestamp	{"date":"2021-03-23 09:10:26.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
93	2021-03-23 09:10:26	status	1
94	2021-03-23 09:10:26	updateTimestamp	null
95	2021-03-23 09:10:26	_subsiteId	null
96	2021-03-23 09:10:26	documento	"231.833.223-15"
97	2021-03-23 09:10:26	emailPrivado	"luiz.carlos@setur.ce.gov.br"
198	2021-03-24 01:46:13	_type	1
98	2021-03-23 09:10:26	emailPublico	"luiz.carlos@setur.ce.gov.br"
99	2021-03-23 09:27:18	_type	1
100	2021-03-23 09:27:18	name	"FABRICIO FIDALGO LOUSADA REGADAS"
101	2021-03-23 09:27:18	publicLocation	false
102	2021-03-23 09:27:18	location	{"latitude":"0","longitude":"0"}
103	2021-03-23 09:27:18	shortDescription	null
104	2021-03-23 09:27:18	longDescription	null
105	2021-03-23 09:27:18	createTimestamp	{"date":"2021-03-23 09:27:18.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
106	2021-03-23 09:27:18	status	1
107	2021-03-23 09:27:18	updateTimestamp	null
108	2021-03-23 09:27:18	_subsiteId	null
109	2021-03-23 09:27:18	documento	"018.413.443-97"
110	2021-03-23 09:27:18	emailPrivado	"fabricio.fidalgo@setur.ce.gov.br"
111	2021-03-23 09:27:18	emailPublico	"fabricio.fidalgo@setur.ce.gov.br"
112	2021-03-23 09:44:58	location	{"latitude":"-3.8029688","longitude":"-38.4921852"}
113	2021-03-23 09:44:58	shortDescription	"Servidor P\\u00fablico da Setur-CE"
114	2021-03-23 09:44:58	longDescription	"Servidor P\\u00fablico da Setur-CE"
115	2021-03-23 09:44:58	updateTimestamp	{"date":"2021-03-23 09:44:58.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
116	2021-03-23 09:44:58	nomeCompleto	"LUIZ CARLOS DA COSTA"
117	2021-03-23 09:44:58	dataDeNascimento	"1963-07-16"
118	2021-03-23 09:44:58	genero	"Homem Cis"
119	2021-03-23 09:44:58	orientacaoSexual	"Heterossexual"
120	2021-03-23 09:44:58	raca	"Parda"
121	2021-03-23 09:44:58	telefonePublico	"(85) 3195-0265"
122	2021-03-23 09:44:58	telefone1	"(85) 98547-3896"
123	2021-03-23 09:44:58	endereco	"Rua Doutor Walter Porto, 235 , Cambeba, 60822-250, Fortaleza, CE"
124	2021-03-23 09:44:58	En_CEP	"60822-250"
125	2021-03-23 09:44:58	En_Nome_Logradouro	"Rua Doutor Walter Porto"
126	2021-03-23 09:44:58	En_Num	"235"
127	2021-03-23 09:44:58	En_Bairro	"Cambeba"
128	2021-03-23 09:44:58	En_Municipio	"Fortaleza"
129	2021-03-23 09:44:58	En_Estado	"CE"
130	2021-03-23 09:44:58	_terms	{"":["Turismo"]}
131	2021-03-23 09:45:11	updateTimestamp	{"date":"2021-03-23 09:45:11.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
132	2021-03-23 09:48:48	updateTimestamp	{"date":"2021-03-23 09:48:48.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
133	2021-03-23 09:48:48	_terms	{"":["Outros"]}
134	2021-03-23 14:41:48	_type	1
135	2021-03-23 14:41:48	name	"Antonio Marques de Oliveira Junior"
136	2021-03-23 14:41:48	publicLocation	false
137	2021-03-23 14:41:48	location	{"latitude":"0","longitude":"0"}
138	2021-03-23 14:41:48	shortDescription	null
139	2021-03-23 14:41:48	longDescription	null
140	2021-03-23 14:41:48	createTimestamp	{"date":"2021-03-23 14:41:48.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
141	2021-03-23 14:41:48	status	1
142	2021-03-23 14:41:48	updateTimestamp	null
143	2021-03-23 14:41:48	_subsiteId	null
144	2021-03-23 14:41:48	documento	"641.830.173-00"
145	2021-03-23 14:41:48	emailPrivado	"marques.junior@setur.ce.gov.br"
146	2021-03-23 14:41:48	emailPublico	"marques.junior@setur.ce.gov.br"
147	2021-03-23 16:08:02	_type	1
148	2021-03-23 16:08:02	name	"Maria Jos\\u00e9 Teste"
149	2021-03-23 16:08:02	publicLocation	false
150	2021-03-23 16:08:02	location	{"latitude":"0","longitude":"0"}
151	2021-03-23 16:08:02	shortDescription	null
152	2021-03-23 16:08:02	longDescription	null
153	2021-03-23 16:08:02	createTimestamp	{"date":"2021-03-23 16:08:02.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
154	2021-03-23 16:08:02	status	1
155	2021-03-23 16:08:02	updateTimestamp	null
156	2021-03-23 16:08:02	_subsiteId	null
157	2021-03-23 16:08:02	documento	"021.270.050-23"
158	2021-03-23 16:08:02	emailPrivado	"valescad192@gmail.com"
159	2021-03-23 16:08:02	emailPublico	"valescad192@gmail.com"
160	2021-03-23 16:09:29	publicLocation	true
161	2021-03-23 16:09:29	shortDescription	"gar\\u00e7onete"
162	2021-03-23 16:09:29	longDescription	""
163	2021-03-23 16:09:29	updateTimestamp	{"date":"2021-03-23 16:09:29.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
164	2021-03-23 16:09:29	_terms	{"":["Cultura Estrangeira (imigrantes)","Gastronomia"]}
165	2021-03-23 16:10:53	nomeCompleto	"gatarrefbsnsm"
166	2021-03-23 16:11:19	dataDeNascimento	"2000-03-02"
167	2021-03-23 16:11:38	telefone1	"(58) 245974452"
168	2021-03-23 16:12:30	publicLocation	false
169	2021-03-23 16:12:30	updateTimestamp	{"date":"2021-03-23 16:12:30.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
170	2021-03-23 16:12:30	En_CEP	"60015-141"
171	2021-03-23 16:12:30	En_Nome_Logradouro	"Rua Teresa Cristina"
172	2021-03-23 16:12:30	En_Num	"025"
173	2021-03-23 16:12:30	En_Bairro	"Farias Brito"
174	2021-03-23 16:12:30	En_Municipio	"Fortaleza"
175	2021-03-23 16:12:30	En_Estado	"CE"
176	2021-03-23 16:13:09	genero	"Mulher Cis"
177	2021-03-23 16:13:12	raca	"Branca"
178	2021-03-23 16:19:28	shortDescription	"Analista"
179	2021-03-23 16:19:28	longDescription	""
180	2021-03-23 16:19:28	updateTimestamp	{"date":"2021-03-23 16:19:28.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
181	2021-03-23 16:19:28	dataDeNascimento	"1986-03-18"
182	2021-03-23 16:19:28	_terms	{"":["Outros"]}
183	2021-03-23 16:21:39	telefone1	"(85) 985473896"
184	2021-03-23 16:21:42	telefone1	"(85) 32711312"
185	2021-03-23 16:21:56	telefone2	"(85) 985473896"
186	2021-03-23 16:24:30	nomeCompleto	"FABRICIO FIDALGO LOUSADA REGADAS"
187	2021-03-23 16:24:49	dataDeNascimento	"1993-04-07"
188	2021-03-23 16:25:00	telefone1	"(85) 996303822"
189	2021-03-23 16:25:08	telefone2	"(85) 996303822"
190	2021-03-23 16:25:21	En_CEP	"60871-165"
191	2021-03-23 16:25:21	En_Nome_Logradouro	"Estrada Bar\\u00e3o de Aquiraz"
192	2021-03-23 16:25:21	En_Num	"980"
193	2021-03-23 16:25:21	En_Bairro	"Messejana"
194	2021-03-23 16:25:21	En_Municipio	"Fortaleza"
195	2021-03-23 16:25:21	En_Estado	"CE"
196	2021-03-23 16:25:33	genero	"Homem Cis"
197	2021-03-23 16:25:38	raca	"Branca"
199	2021-03-24 01:46:13	name	"Bruno"
200	2021-03-24 01:46:13	publicLocation	false
201	2021-03-24 01:46:13	location	{"latitude":"0","longitude":"0"}
202	2021-03-24 01:46:13	shortDescription	null
203	2021-03-24 01:46:13	longDescription	null
204	2021-03-24 01:46:13	createTimestamp	{"date":"2021-03-24 01:46:12.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
205	2021-03-24 01:46:13	status	1
206	2021-03-24 01:46:13	updateTimestamp	null
207	2021-03-24 01:46:13	_subsiteId	null
208	2021-03-24 01:46:13	documento	"604.344.523-94"
209	2021-03-24 01:46:13	emailPrivado	"bruno@gmail.com"
210	2021-03-24 01:46:13	emailPublico	"bruno@gmail.com"
211	2021-03-24 01:46:46	shortDescription	"Descri\\u00e7\\u00e3o do Bruno"
212	2021-03-24 01:46:46	longDescription	""
213	2021-03-24 01:46:46	updateTimestamp	{"date":"2021-03-24 01:46:46.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
214	2021-03-24 01:46:46	_terms	{"":["Produ\\u00e7\\u00e3o Cultural"]}
215	2021-03-24 09:05:31	documento	"323.019.363-68"
216	2021-03-24 09:06:36	nomeCompleto	"JOS\\u00c9 VALDO MESQUITA"
217	2021-03-24 09:06:54	dataDeNascimento	"0319-08-05"
218	2021-03-24 09:07:03	telefone1	"(85) 986122132"
219	2021-03-24 09:07:13	telefone2	"(85) 986122132"
220	2021-03-24 09:09:33	En_CEP	"60810-786"
221	2021-03-24 09:09:33	En_Nome_Logradouro	"Avenida Rogaciano Leite"
222	2021-03-24 09:09:33	En_Num	"800"
223	2021-03-24 09:09:33	En_Complemento	"aPT 203 a"
224	2021-03-24 09:09:33	En_Bairro	"Salinas"
225	2021-03-24 09:09:33	En_Municipio	"Fortaleza"
226	2021-03-24 09:09:33	En_Estado	"CE"
227	2021-03-24 09:10:18	genero	"Homem Cis"
228	2021-03-24 09:10:22	raca	"Branca"
229	2021-03-24 09:32:31	_type	1
230	2021-03-24 09:32:31	name	"JOSE TEXTE"
231	2021-03-24 09:32:31	publicLocation	false
232	2021-03-24 09:32:31	location	{"latitude":"0","longitude":"0"}
233	2021-03-24 09:32:31	shortDescription	null
234	2021-03-24 09:32:31	longDescription	null
235	2021-03-24 09:32:31	createTimestamp	{"date":"2021-03-24 09:32:31.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
236	2021-03-24 09:32:31	status	1
237	2021-03-24 09:32:31	updateTimestamp	null
238	2021-03-24 09:32:31	_subsiteId	null
239	2021-03-24 09:32:31	documento	"123.456.789-09"
240	2021-03-24 09:32:31	emailPrivado	"jose.texte@gmail.com"
241	2021-03-24 09:32:31	emailPublico	"jose.texte@gmail.com"
242	2021-03-24 09:40:09	_type	1
243	2021-03-24 09:40:09	name	"JOAO TEXXTE"
244	2021-03-24 09:40:09	publicLocation	false
245	2021-03-24 09:40:09	location	{"latitude":"0","longitude":"0"}
246	2021-03-24 09:40:09	shortDescription	null
247	2021-03-24 09:40:09	longDescription	null
248	2021-03-24 09:40:09	createTimestamp	{"date":"2021-03-24 09:40:09.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
249	2021-03-24 09:40:09	status	1
250	2021-03-24 09:40:09	updateTimestamp	null
251	2021-03-24 09:40:09	_subsiteId	null
252	2021-03-24 09:40:09	documento	"234.567.890-92"
253	2021-03-24 09:40:09	emailPrivado	"joao.texxte@gmail.com"
254	2021-03-24 09:40:09	emailPublico	"joao.texxte@gmail.com"
255	2021-03-24 09:47:16	location	{"latitude":"-3.7919684","longitude":"-38.4803519"}
256	2021-03-24 09:47:16	shortDescription	"TEXXTE TEXXTE"
257	2021-03-24 09:47:16	longDescription	"KJLKDJKJKLF KLJKLFJKL JKLJKLKJKLJFD"
258	2021-03-24 09:47:16	updateTimestamp	{"date":"2021-03-24 09:47:16.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
259	2021-03-24 09:47:16	nomeCompleto	"JOAO TEXXTE"
260	2021-03-24 09:47:16	dataDeNascimento	"1970-01-15"
261	2021-03-24 09:47:16	genero	"Homem Cis"
262	2021-03-24 09:47:16	orientacaoSexual	"Heterossexual"
263	2021-03-24 09:47:16	raca	"Branca"
264	2021-03-24 09:47:16	telefonePublico	"(85) 23456-7890"
265	2021-03-24 09:47:16	telefone1	"(85) 23456-7890"
266	2021-03-24 09:47:16	endereco	"Avenida Washington Soares, 2345 , Edson Queiroz, 60811-341, Fortaleza, CE"
267	2021-03-24 09:47:16	En_CEP	"60811-341"
268	2021-03-24 09:47:16	En_Nome_Logradouro	"Avenida Washington Soares"
269	2021-03-24 09:47:16	En_Num	"2345"
270	2021-03-24 09:47:16	En_Bairro	"Edson Queiroz"
271	2021-03-24 09:47:16	En_Municipio	"Fortaleza"
272	2021-03-24 09:47:16	En_Estado	"CE"
273	2021-03-24 09:47:16	_terms	{"":["Outros"]}
274	2021-03-24 09:49:50	telefone1	"(85) 234567890"
275	2021-03-24 09:50:03	telefone2	"(85) 234566789"
276	2021-03-24 09:57:53	_type	1
277	2021-03-24 09:57:53	name	"MARIA TEXXTE"
278	2021-03-24 09:57:53	publicLocation	false
279	2021-03-24 09:57:53	location	{"latitude":"0","longitude":"0"}
280	2021-03-24 09:57:53	shortDescription	null
281	2021-03-24 09:57:53	longDescription	null
282	2021-03-24 09:57:53	createTimestamp	{"date":"2021-03-24 09:57:53.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
283	2021-03-24 09:57:53	status	1
284	2021-03-24 09:57:53	updateTimestamp	null
285	2021-03-24 09:57:53	_subsiteId	null
286	2021-03-24 09:57:53	documento	"345.678.901-75"
287	2021-03-24 09:57:53	emailPrivado	"maria.texxte@gmail.com"
288	2021-03-24 09:57:53	emailPublico	"maria.texxte@gmail.com"
289	2021-03-24 10:00:56	location	{"latitude":"-3.7919684","longitude":"-38.4803519"}
290	2021-03-24 10:00:56	shortDescription	"maria texxte texxte"
291	2021-03-24 10:00:56	longDescription	""
292	2021-03-24 10:00:56	updateTimestamp	{"date":"2021-03-24 10:00:56.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
293	2021-03-24 10:00:56	genero	"Mulher Cis"
294	2021-03-24 10:00:56	nomeCompleto	"MARIA TEXXTE"
295	2021-03-24 10:00:56	dataDeNascimento	"1980-01-15"
296	2021-03-24 10:00:56	orientacaoSexual	"Heterossexual"
297	2021-03-24 10:00:56	telefonePublico	"(85) 4567-8900"
298	2021-03-24 10:00:56	telefone1	"(85) 4678-9000"
299	2021-03-24 10:00:56	endereco	"Avenida Washington Soares, 3456 , Edson Queiroz, 60811-341, Fortaleza, CE"
300	2021-03-24 10:00:56	En_CEP	"60811-341"
301	2021-03-24 10:00:56	En_Nome_Logradouro	"Avenida Washington Soares"
302	2021-03-24 10:00:56	En_Num	"3456"
303	2021-03-24 10:00:56	En_Bairro	"Edson Queiroz"
304	2021-03-24 10:00:56	En_Municipio	"Fortaleza"
305	2021-03-24 10:00:56	En_Estado	"CE"
306	2021-03-24 10:00:56	_terms	{"":["Gastronomia"]}
307	2021-03-24 10:01:06	longDescription	"TEXXTE TEXXTE"
308	2021-03-24 10:01:06	updateTimestamp	{"date":"2021-03-24 10:01:06.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
309	2021-03-24 10:02:15	telefone1	"(85) 46789000"
310	2021-03-24 10:02:26	telefone2	"(85) 456789000"
311	2021-03-24 10:02:51	raca	"Parda"
312	2021-03-24 18:22:39	dataDeNascimento	"1970-03-28"
313	2021-03-24 19:32:10	_type	1
314	2021-03-24 19:32:10	name	"JOSE TEXXTE"
315	2021-03-24 19:32:10	publicLocation	false
316	2021-03-24 19:32:10	location	{"latitude":"0","longitude":"0"}
317	2021-03-24 19:32:10	shortDescription	null
318	2021-03-24 19:32:10	longDescription	null
319	2021-03-24 19:32:10	createTimestamp	{"date":"2021-03-24 19:32:10.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
320	2021-03-24 19:32:10	status	1
321	2021-03-24 19:32:10	updateTimestamp	null
322	2021-03-24 19:32:10	_subsiteId	null
323	2021-03-24 19:32:10	documento	"012.345.678-90"
324	2021-03-24 19:32:10	emailPrivado	"jose.texxte@gmail.com"
325	2021-03-24 19:32:10	emailPublico	"jose.texxte@gmail.com"
326	2021-03-24 19:51:17	_type	1
327	2021-03-24 19:51:17	name	"MARIA TEXXXTE"
328	2021-03-24 19:51:17	publicLocation	false
329	2021-03-24 19:51:17	location	{"latitude":"0","longitude":"0"}
330	2021-03-24 19:51:17	shortDescription	null
331	2021-03-24 19:51:17	longDescription	null
332	2021-03-24 19:51:17	createTimestamp	{"date":"2021-03-24 19:51:17.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
333	2021-03-24 19:51:17	status	1
334	2021-03-24 19:51:17	updateTimestamp	null
335	2021-03-24 19:51:17	_subsiteId	null
336	2021-03-24 19:51:17	documento	"901.234.567-70"
337	2021-03-24 19:51:17	emailPrivado	"maria.texxxte@gmail.com"
338	2021-03-24 19:51:17	emailPublico	"maria.texxxte@gmail.com"
339	2021-03-24 19:53:58	location	{"latitude":"-3.7384381","longitude":"-38.4915457"}
340	2021-03-24 19:53:58	shortDescription	"kljkkjjfkj jkjkfjkj kkjklfjklj jkljkljkl jk"
341	2021-03-24 19:53:58	longDescription	""
342	2021-03-24 19:53:58	updateTimestamp	{"date":"2021-03-24 19:53:58.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
343	2021-03-24 19:53:58	nomeCompleto	"MARIA TEXXXTE"
344	2021-03-24 19:53:58	dataDeNascimento	"1981-02-15"
345	2021-03-24 19:53:58	genero	"Mulher Cis"
346	2021-03-24 19:53:58	telefonePublico	"(85) 3145-2300"
347	2021-03-24 19:53:58	telefone1	"(85) 93145-2300"
348	2021-03-24 19:53:58	endereco	"Avenida Santos Dumont, 1517, Apt 1720, Aldeota, 60150-161, Fortaleza, CE"
349	2021-03-24 19:53:58	En_CEP	"60150-161"
350	2021-03-24 19:53:58	En_Nome_Logradouro	"Avenida Santos Dumont"
351	2021-03-24 19:53:58	En_Num	"1517"
352	2021-03-24 19:53:58	En_Complemento	"Apt 1720"
353	2021-03-24 19:53:58	En_Bairro	"Aldeota"
354	2021-03-24 19:53:58	En_Municipio	"Fortaleza"
355	2021-03-24 19:53:58	En_Estado	"CE"
356	2021-03-24 19:53:58	_terms	{"":["Gastronomia"]}
357	2021-03-24 19:56:25	telefone1	"(85) 931452300"
358	2021-03-24 19:57:13	raca	"N\\u00e3o Informar"
359	2021-03-25 09:52:57	location	{"latitude":"-5.85923348715112","longitude":"-39.4892520457506"}
360	2021-03-25 09:52:57	shortDescription	"Yesye"
361	2021-03-25 09:52:57	longDescription	""
362	2021-03-25 09:52:57	updateTimestamp	{"date":"2021-03-25 09:52:57.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
363	2021-03-25 09:52:57	documento	"05749987302"
364	2021-03-25 09:52:57	telefonePublico	"(88) 88888-8888"
365	2021-03-25 09:52:57	telefone1	"(88) 88888-8888"
366	2021-03-25 09:52:57	_terms	{"":["Arte Digital"]}
367	2021-03-25 09:59:26	_type	1
368	2021-03-25 09:59:26	name	"maria Florencia fidalgo"
369	2021-03-25 09:59:26	publicLocation	false
370	2021-03-25 09:59:26	location	{"latitude":"0","longitude":"0"}
371	2021-03-25 09:59:26	shortDescription	null
372	2021-03-25 09:59:26	longDescription	null
373	2021-03-25 09:59:26	createTimestamp	{"date":"2021-03-25 09:59:26.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
374	2021-03-25 09:59:26	status	1
375	2021-03-25 09:59:26	updateTimestamp	null
376	2021-03-25 09:59:26	_subsiteId	null
377	2021-03-25 09:59:26	documento	"758.359.753-68"
378	2021-03-25 09:59:26	emailPrivado	"fabricio.fidalgo@hotmail.com"
379	2021-03-25 09:59:26	emailPublico	"fabricio.fidalgo@hotmail.com"
380	2021-03-25 10:06:25	_type	1
381	2021-03-25 10:06:25	name	"MARIO TEXXTE"
382	2021-03-25 10:06:25	publicLocation	false
383	2021-03-25 10:06:25	location	{"latitude":"0","longitude":"0"}
384	2021-03-25 10:06:25	shortDescription	null
385	2021-03-25 10:06:25	longDescription	null
386	2021-03-25 10:06:25	createTimestamp	{"date":"2021-03-25 10:06:25.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
387	2021-03-25 10:06:25	status	1
388	2021-03-25 10:06:25	updateTimestamp	null
389	2021-03-25 10:06:25	_subsiteId	null
390	2021-03-25 10:06:25	documento	"546.225.326-54"
391	2021-03-25 10:06:25	emailPrivado	"mario.texxte@gmail.com"
392	2021-03-25 10:06:25	emailPublico	"mario.texxte@gmail.com"
393	2021-03-25 10:08:26	location	{"latitude":"-3.7384381","longitude":"-38.4915457"}
394	2021-03-25 10:08:26	shortDescription	"fkljkjkj kjkjkj kjkfj kjkfjk jdf"
395	2021-03-25 10:08:26	longDescription	""
396	2021-03-25 10:08:26	updateTimestamp	{"date":"2021-03-25 10:08:26.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
397	2021-03-25 10:08:26	nomeCompleto	"MARIO TEXXTE"
398	2021-03-25 10:08:26	dataDeNascimento	"1979-01-25"
399	2021-03-25 10:08:26	genero	"Homem Cis"
400	2021-03-25 10:08:26	raca	"Amarela"
401	2021-03-25 10:08:26	telefonePublico	"(85) 3245-5654"
402	2021-03-25 10:08:26	telefone1	"(85) 3245-5654"
403	2021-03-25 10:08:26	endereco	"Avenida Santos Dumont, 322 , Aldeota, 60150-161, Fortaleza, CE"
404	2021-03-25 10:08:26	En_CEP	"60150-161"
405	2021-03-25 10:08:26	En_Nome_Logradouro	"Avenida Santos Dumont"
406	2021-03-25 10:08:26	En_Num	"322"
407	2021-03-25 10:08:26	En_Bairro	"Aldeota"
408	2021-03-25 10:08:26	En_Municipio	"Fortaleza"
409	2021-03-25 10:08:26	En_Estado	"CE"
410	2021-03-25 10:08:26	_terms	{"":["Gastronomia"]}
411	2021-03-25 10:08:31	location	{"latitude":"-3.8450321","longitude":"-38.4805564"}
412	2021-03-25 10:08:31	shortDescription	"teste teste teste"
413	2021-03-25 10:08:31	longDescription	""
414	2021-03-25 10:08:31	updateTimestamp	{"date":"2021-03-25 10:08:31.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
415	2021-03-25 10:08:31	nomeCompleto	"MARIA FLOrENCIA FIDALGO"
416	2021-03-25 10:08:31	dataDeNascimento	"1967-10-23"
417	2021-03-25 10:08:31	genero	"Mulher Cis"
418	2021-03-25 10:08:31	orientacaoSexual	"Heterossexual"
419	2021-03-25 10:08:31	raca	"Branca"
420	2021-03-25 10:08:31	telefonePublico	"(85) 3459-0352"
421	2021-03-25 10:08:31	telefone1	"(85) 3459-0352"
422	2021-03-25 10:08:31	endereco	"Estrada Bar\\u00e3o de Aquiraz, 980 , Messejana, 60871-165, Fortaleza, CE"
423	2021-03-25 10:08:31	En_CEP	"60871-165"
424	2021-03-25 10:08:31	En_Nome_Logradouro	"Estrada Bar\\u00e3o de Aquiraz"
425	2021-03-25 10:08:31	En_Num	"980"
426	2021-03-25 10:08:31	En_Bairro	"Messejana"
427	2021-03-25 10:08:31	En_Municipio	"Fortaleza"
428	2021-03-25 10:08:31	En_Estado	"CE"
429	2021-03-25 10:08:31	_terms	{"":["Arquivo"]}
430	2021-03-25 10:08:43	longDescription	"KJKLJKL KJKJFK JK KFJ KJK JKJF"
431	2021-03-25 10:08:43	updateTimestamp	{"date":"2021-03-25 10:08:43.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
432	2021-03-25 10:08:56	updateTimestamp	{"date":"2021-03-25 10:08:56.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
433	2021-03-25 10:09:04	_type	1
434	2021-03-25 10:09:04	name	"Antonia Rodrigues Mesquita"
435	2021-03-25 10:09:04	publicLocation	false
436	2021-03-25 10:09:04	location	{"latitude":"0","longitude":"0"}
437	2021-03-25 10:09:04	shortDescription	null
438	2021-03-25 10:09:04	longDescription	null
439	2021-03-25 10:09:04	createTimestamp	{"date":"2021-03-25 10:09:04.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
440	2021-03-25 10:09:04	status	1
441	2021-03-25 10:09:04	updateTimestamp	null
442	2021-03-25 10:09:04	_subsiteId	null
443	2021-03-25 10:09:04	documento	"555.195.473-00"
444	2021-03-25 10:09:04	emailPrivado	"antoniarodrigues160646@gmail.com"
445	2021-03-25 10:09:04	emailPublico	"antoniarodrigues160646@gmail.com"
446	2021-03-25 10:09:58	telefone1	"(85) 32455654"
447	2021-03-25 10:10:14	telefone2	"(85) 993245564"
448	2021-03-25 10:12:30	telefone1	"(85) 34590352"
449	2021-03-25 10:18:27	_type	1
450	2021-03-25 10:18:27	name	"Ana Clara Beco da Silva"
451	2021-03-25 10:18:27	publicLocation	false
452	2021-03-25 10:18:27	location	{"latitude":"0","longitude":"0"}
453	2021-03-25 10:18:27	shortDescription	null
454	2021-03-25 10:18:27	longDescription	null
455	2021-03-25 10:18:27	createTimestamp	{"date":"2021-03-25 10:18:26.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
456	2021-03-25 10:18:27	status	1
457	2021-03-25 10:18:27	updateTimestamp	null
458	2021-03-25 10:18:27	_subsiteId	null
459	2021-03-25 10:18:27	documento	"142.188.283-34"
460	2021-03-25 10:18:27	emailPrivado	"anaclarabecco@hotmail.com"
461	2021-03-25 10:18:27	emailPublico	"anaclarabecco@hotmail.com"
462	2021-03-25 10:27:39	_type	1
463	2021-03-25 10:27:39	name	"Francisco Borges"
464	2021-03-25 10:27:39	publicLocation	false
465	2021-03-25 10:27:39	location	{"latitude":"0","longitude":"0"}
466	2021-03-25 10:27:39	shortDescription	null
467	2021-03-25 10:27:39	longDescription	null
468	2021-03-25 10:27:39	createTimestamp	{"date":"2021-03-25 10:27:39.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
469	2021-03-25 10:27:39	status	1
470	2021-03-25 10:27:39	updateTimestamp	null
471	2021-03-25 10:27:39	_subsiteId	null
472	2021-03-25 10:27:39	documento	"300.749.913-53"
473	2021-03-25 10:27:39	emailPrivado	"borges.mesquita@gmail.com"
474	2021-03-25 10:27:39	emailPublico	"borges.mesquita@gmail.com"
475	2021-03-25 10:29:02	publicLocation	true
476	2021-03-25 10:29:02	location	{"latitude":"-3.7397175","longitude":"-38.5009719"}
477	2021-03-25 10:29:02	shortDescription	"Gerente de restaurante e bar"
478	2021-03-25 10:29:02	longDescription	""
479	2021-03-25 10:29:02	updateTimestamp	{"date":"2021-03-25 10:29:02.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
480	2021-03-25 10:29:02	nomeCompleto	"Ana Clara Beco da Silva"
481	2021-03-25 10:29:02	dataDeNascimento	"1950-06-12"
482	2021-03-25 10:29:02	genero	"Mulher Cis"
483	2021-03-25 10:29:02	orientacaoSexual	"Heterossexual"
484	2021-03-25 10:29:02	raca	"Parda"
485	2021-03-25 10:29:02	telefonePublico	"(85) 99989-7118"
486	2021-03-25 10:29:02	endereco	"Avenida Padre Ant\\u00f4nio Tom\\u00e1s, 3433, AP 900, Coc\\u00f3, 60192-125, Fortaleza, CE"
487	2021-03-25 10:29:02	En_CEP	"60192-125"
488	2021-03-25 10:29:02	En_Nome_Logradouro	"Avenida Padre Ant\\u00f4nio Tom\\u00e1s"
489	2021-03-25 10:29:02	En_Num	"3433"
490	2021-03-25 10:29:02	En_Complemento	"AP 900"
491	2021-03-25 10:29:02	En_Bairro	"Coc\\u00f3"
492	2021-03-25 10:29:02	En_Municipio	"Fortaleza"
493	2021-03-25 10:29:02	En_Estado	"CE"
494	2021-03-25 10:29:02	_terms	{"":["Artesanato"]}
495	2021-03-25 10:29:19	updateTimestamp	{"date":"2021-03-25 10:29:19.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
496	2021-03-25 10:30:48	nomeCompleto	"FRANCISCO BORGES"
497	2021-03-25 10:31:05	dataDeNascimento	"1968-04-22"
498	2021-03-25 10:31:15	telefone1	"(85) 986122132"
499	2021-03-25 10:31:30	telefone2	"(85) 986122132"
500	2021-03-25 10:32:04	En_CEP	"60830-105"
501	2021-03-25 10:32:04	En_Nome_Logradouro	"Rua Rafael Tobias"
502	2021-03-25 10:32:04	En_Num	"2113"
503	2021-03-25 10:32:04	En_Complemento	"CASA 1"
504	2021-03-25 10:32:04	En_Bairro	"Jos\\u00e9 de Alencar"
505	2021-03-25 10:32:04	En_Municipio	"Fortaleza"
506	2021-03-25 10:32:04	En_Estado	"CE"
507	2021-03-25 10:32:19	genero	"Homem Cis"
508	2021-03-25 10:32:22	raca	"Branca"
509	2021-03-25 10:34:28	telefone1	"(85) 999897118"
510	2021-03-25 10:34:40	telefone2	"(85) 999240967"
511	2021-03-25 10:51:35	_type	1
512	2021-03-25 10:51:35	name	"Alice Becco da Silva Rios"
513	2021-03-25 10:51:35	publicLocation	false
514	2021-03-25 10:51:35	location	{"latitude":"0","longitude":"0"}
515	2021-03-25 10:51:35	shortDescription	null
516	2021-03-25 10:51:35	longDescription	null
517	2021-03-25 10:51:35	createTimestamp	{"date":"2021-03-25 10:51:35.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
518	2021-03-25 10:51:35	status	1
519	2021-03-25 10:51:35	updateTimestamp	null
520	2021-03-25 10:51:35	_subsiteId	null
521	2021-03-25 10:51:35	documento	"902.909.333-15"
522	2021-03-25 10:51:35	emailPrivado	"alicebecco@hotmail.com"
523	2021-03-25 10:51:35	emailPublico	"alicebecco@hotmail.com"
524	2021-03-25 10:54:46	location	{"latitude":"-3.7397175","longitude":"-38.5009719"}
525	2021-03-25 10:54:46	shortDescription	"Arquiteta e urbanista"
526	2021-03-25 10:54:46	longDescription	""
527	2021-03-25 10:54:46	updateTimestamp	{"date":"2021-03-25 10:54:46.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
528	2021-03-25 10:54:46	nomeCompleto	"Alice Becco da Silva Rios"
529	2021-03-25 10:54:46	dataDeNascimento	"1981-07-13"
530	2021-03-25 10:54:46	genero	"Mulher Cis"
531	2021-03-25 10:54:46	orientacaoSexual	"Heterossexual"
532	2021-03-25 10:54:46	raca	"Parda"
533	2021-03-25 10:54:46	telefonePublico	"(85) 99924-0967"
534	2021-03-25 10:54:46	endereco	"Avenida Padre Ant\\u00f4nio Tom\\u00e1s, 3433, AP 900, Coc\\u00f3, 60192-125, Fortaleza, CE"
535	2021-03-25 10:54:46	En_CEP	"60192-125"
536	2021-03-25 10:54:46	En_Nome_Logradouro	"Avenida Padre Ant\\u00f4nio Tom\\u00e1s"
537	2021-03-25 10:54:46	En_Num	"3433"
538	2021-03-25 10:54:46	En_Complemento	"AP 900"
539	2021-03-25 10:54:46	En_Bairro	"Coc\\u00f3"
540	2021-03-25 10:54:46	En_Municipio	"Fortaleza"
541	2021-03-25 10:54:46	En_Estado	"CE"
542	2021-03-25 10:54:46	_terms	{"":["Arquitetura-Urbanismo"]}
543	2021-03-25 11:41:53	_type	1
544	2021-03-25 11:41:53	name	"NAIRTON OLIVEIRA"
545	2021-03-25 11:41:53	publicLocation	false
546	2021-03-25 11:41:53	location	{"latitude":"0","longitude":"0"}
547	2021-03-25 11:41:53	shortDescription	null
548	2021-03-25 11:41:53	longDescription	null
549	2021-03-25 11:41:53	createTimestamp	{"date":"2021-03-25 11:41:53.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
550	2021-03-25 11:41:53	status	1
551	2021-03-25 11:41:53	updateTimestamp	null
552	2021-03-25 11:41:53	_subsiteId	null
553	2021-03-25 11:41:53	documento	"926.782.703-00"
554	2021-03-25 11:41:53	emailPrivado	"nairton@gmail.com"
555	2021-03-25 11:41:53	emailPublico	"nairton@gmail.com"
556	2021-03-25 11:45:40	shortDescription	"Nairton"
557	2021-03-25 11:45:40	longDescription	""
558	2021-03-25 11:45:40	updateTimestamp	{"date":"2021-03-25 11:45:40.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
559	2021-03-25 11:45:40	dataDeNascimento	"1981-07-06"
560	2021-03-25 11:45:40	genero	"Homem Cis"
561	2021-03-25 11:45:40	orientacaoSexual	"Heterossexual"
562	2021-03-25 11:45:40	raca	"Branca"
563	2021-03-25 11:45:40	telefonePublico	"(85) 98668-8091"
564	2021-03-25 11:45:40	telefone1	"(85) 98668-8091"
565	2021-03-25 11:45:40	_terms	{"":["Gastronomia"]}
566	2021-03-25 14:55:52	shortDescription	"Validador"
567	2021-03-25 14:55:52	longDescription	""
568	2021-03-25 14:55:52	updateTimestamp	{"date":"2021-03-25 14:55:52.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
569	2021-03-25 14:55:52	_terms	{"":["Turismo"]}
570	2021-03-25 16:59:59	nomeCompleto	"skgdsavjdgs"
571	2021-03-25 17:00:05	dataDeNascimento	"2021-03-24"
572	2021-03-25 17:00:12	telefone1	"(88) 888888888"
573	2021-03-25 17:00:28	En_CEP	"63050-645"
574	2021-03-25 17:00:28	En_Nome_Logradouro	"Rua Doutor Jos\\u00e9 Paracampos"
575	2021-03-25 17:00:28	En_Num	"222"
576	2021-03-25 17:00:28	En_Bairro	"Romeir\\u00e3o"
577	2021-03-25 17:00:28	En_Municipio	"Juazeiro do Norte"
578	2021-03-25 17:00:28	En_Estado	"CE"
579	2021-03-25 17:00:46	genero	"Mulher Cis"
580	2021-03-25 17:00:48	raca	"Branca"
581	2021-03-26 09:09:42	_type	1
582	2021-03-26 09:09:42	name	"carlos texxte"
583	2021-03-26 09:09:42	publicLocation	false
584	2021-03-26 09:09:42	location	{"latitude":"0","longitude":"0"}
585	2021-03-26 09:09:42	shortDescription	null
586	2021-03-26 09:09:42	longDescription	null
587	2021-03-26 09:09:42	createTimestamp	{"date":"2021-03-26 09:09:42.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
588	2021-03-26 09:09:42	status	1
589	2021-03-26 09:09:42	updateTimestamp	null
590	2021-03-26 09:09:42	_subsiteId	null
591	2021-03-26 09:09:42	documento	"456.235.122-59"
592	2021-03-26 09:09:42	emailPrivado	"carlos.texxte@gmail.com"
593	2021-03-26 09:09:42	emailPublico	"carlos.texxte@gmail.com"
594	2021-03-26 09:14:45	shortDescription	"kjkjkl kjkjkjk kjkkjj kjkjkj gkjklgfjkj kjkjfkjk kjdkjkfjkj "
595	2021-03-26 09:14:45	longDescription	""
596	2021-03-26 09:14:45	updateTimestamp	{"date":"2021-03-26 09:14:45.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
597	2021-03-26 09:14:45	nomeCompleto	"carlos texxte"
598	2021-03-26 09:14:45	dataDeNascimento	"1981-02-22"
599	2021-03-26 09:14:45	genero	"Homem Cis"
600	2021-03-26 09:14:45	orientacaoSexual	"Heterossexual"
601	2021-03-26 09:14:45	raca	"Preta"
602	2021-03-26 09:14:45	telefonePublico	"(85) 99688-2133"
603	2021-03-26 09:14:45	endereco	"Pra\\u00e7a das Graviolas, 855 , Centro, 60110-215, Fortaleza, CE"
604	2021-03-26 09:14:45	En_CEP	"60110-215"
605	2021-03-26 09:14:45	En_Nome_Logradouro	"Pra\\u00e7a das Graviolas"
606	2021-03-26 09:14:45	En_Bairro	"Centro"
607	2021-03-26 09:14:45	En_Municipio	"Fortaleza"
608	2021-03-26 09:14:45	En_Estado	"CE"
609	2021-03-26 09:14:45	_terms	{"":["Gastronomia"]}
610	2021-03-26 09:51:04	telefone1	"(85) 996548556"
611	2021-03-26 09:51:55	endereco	""
612	2021-03-26 09:51:55	En_CEP	"60110-160"
613	2021-03-26 09:51:55	En_Num	"894"
614	2021-03-26 09:51:55	En_Complemento	"Fundos"
615	2021-03-26 10:07:10	_type	1
616	2021-03-26 10:07:10	name	"silvio texxte"
617	2021-03-26 10:07:10	publicLocation	false
618	2021-03-26 10:07:10	location	{"latitude":"0","longitude":"0"}
619	2021-03-26 10:07:10	shortDescription	null
620	2021-03-26 10:07:10	longDescription	null
621	2021-03-26 10:07:10	createTimestamp	{"date":"2021-03-26 10:07:10.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
622	2021-03-26 10:07:10	status	1
623	2021-03-26 10:07:10	updateTimestamp	null
624	2021-03-26 10:07:10	_subsiteId	null
625	2021-03-26 10:07:10	documento	"548.221.356-08"
626	2021-03-26 10:07:10	emailPrivado	"silvio.texxte@gmail.com"
627	2021-03-26 10:07:10	emailPublico	"silvio.texxte@gmail.com"
628	2021-03-26 10:14:16	location	{"latitude":"-3.7919684","longitude":"-38.4803519"}
629	2021-03-26 10:14:16	shortDescription	"kjkjkf kjjfj kjfjkjkljdfkjfkjdf jhjj jhjhjhjh  jhjhjh"
630	2021-03-26 10:14:16	longDescription	""
631	2021-03-26 10:14:16	updateTimestamp	{"date":"2021-03-26 10:14:16.000000","timezone_type":3,"timezone":"America\\/Fortaleza"}
632	2021-03-26 10:14:16	nomeCompleto	"empresa texxte"
633	2021-03-26 10:14:16	dataDeNascimento	"1980-03-02"
634	2021-03-26 10:14:16	genero	"Homem Cis"
635	2021-03-26 10:14:16	telefonePublico	"(85) 99888-2512"
636	2021-03-26 10:14:16	endereco	"Avenida Washington Soares, 546 , Edson Queiroz, 60811-341, Fortaleza, CE"
637	2021-03-26 10:14:16	En_CEP	"60811-341"
638	2021-03-26 10:14:16	En_Nome_Logradouro	"Avenida Washington Soares"
639	2021-03-26 10:14:16	En_Num	"546"
640	2021-03-26 10:14:16	En_Bairro	"Edson Queiroz"
641	2021-03-26 10:14:16	En_Municipio	"Fortaleza"
642	2021-03-26 10:14:16	En_Estado	"CE"
643	2021-03-26 10:14:16	_terms	{"":["Gastronomia"]}
644	2021-03-26 10:28:26	raca	"Branca"
645	2021-03-26 10:36:39	telefone1	"(85) 996522145"
\.


--
-- Name: entity_revision_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.entity_revision_id_seq', 106, true);


--
-- Data for Name: entity_revision_revision_data; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.entity_revision_revision_data (revision_id, revision_data_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	10
1	11
2	1
2	2
2	12
2	13
2	14
2	15
2	7
2	8
2	16
2	10
2	11
2	17
3	1
3	2
3	12
3	13
3	14
3	15
3	7
3	8
3	18
3	10
3	11
3	17
4	19
4	20
4	21
4	22
4	23
4	24
4	25
4	26
4	27
4	28
4	29
4	30
4	31
5	19
5	20
5	21
5	22
5	32
5	33
5	25
5	26
5	34
5	28
5	29
5	30
5	31
5	35
6	36
6	37
6	38
6	39
6	40
6	41
6	42
6	43
6	44
6	45
6	46
7	36
7	37
7	47
7	39
7	40
7	48
7	42
7	43
7	49
7	45
7	50
7	51
7	52
7	53
7	54
7	55
7	46
8	56
8	57
8	58
8	59
8	60
8	61
8	62
8	63
8	64
8	65
8	66
8	67
8	68
9	19
9	69
9	21
9	22
9	32
9	33
9	25
9	26
9	70
9	28
9	29
9	30
9	31
9	71
9	35
10	19
10	69
10	21
10	22
10	32
10	33
10	25
10	26
10	72
10	28
10	29
10	30
10	31
10	71
10	35
11	73
11	74
11	75
11	76
11	77
11	78
11	79
11	80
11	81
11	82
11	83
11	84
11	85
12	86
12	87
12	88
12	89
12	90
12	91
12	92
12	93
12	94
12	95
12	96
12	97
12	98
13	99
13	100
13	101
13	102
13	103
13	104
13	105
13	106
13	107
13	108
13	109
13	110
13	111
14	86
14	87
14	88
14	112
14	113
14	114
14	92
14	93
14	115
14	95
14	96
14	97
14	98
14	116
14	117
14	118
14	119
14	120
14	121
14	122
14	123
14	124
14	125
14	126
14	127
14	128
14	129
14	130
15	86
15	87
15	88
15	112
15	113
15	114
15	92
15	93
15	131
15	95
15	96
15	97
15	98
15	116
15	117
15	118
15	119
15	120
15	121
15	122
15	123
15	124
15	125
15	126
15	127
15	128
15	129
15	130
16	86
16	87
16	88
16	112
16	113
16	114
16	92
16	93
16	132
16	95
16	96
16	97
16	98
16	116
16	117
16	118
16	119
16	120
16	121
16	122
16	123
16	124
16	125
16	126
16	127
16	128
16	129
16	133
17	134
17	135
17	136
17	137
17	138
17	139
17	140
17	141
17	142
17	143
17	144
17	145
17	146
18	147
18	148
18	149
18	150
18	151
18	152
18	153
18	154
18	155
18	156
18	157
18	158
18	159
19	147
19	148
19	160
19	150
19	161
19	162
19	153
19	154
19	163
19	156
19	157
19	158
19	159
19	164
20	147
20	148
20	160
20	150
20	161
20	162
20	153
20	154
20	163
20	156
20	157
20	158
20	159
20	165
20	164
21	147
21	148
21	160
21	150
21	161
21	162
21	153
21	154
21	163
21	156
21	157
21	158
21	159
21	165
21	166
21	164
22	147
22	148
22	160
22	150
22	161
22	162
22	153
22	154
22	163
22	156
22	157
22	158
22	159
22	165
22	166
22	167
22	164
23	147
23	148
23	168
23	150
23	161
23	162
23	153
23	154
23	169
23	156
23	157
23	158
23	159
23	165
23	166
23	167
23	170
23	171
23	172
23	173
23	174
23	175
23	164
24	147
24	148
24	168
24	150
24	161
24	162
24	153
24	154
24	169
24	156
24	157
24	158
24	159
24	165
24	166
24	167
24	170
24	171
24	172
24	173
24	174
24	175
24	176
24	164
25	147
25	148
25	168
25	150
25	161
25	162
25	153
25	154
25	169
25	156
25	157
25	158
25	159
25	165
25	166
25	167
25	170
25	171
25	172
25	173
25	174
25	175
25	176
25	177
25	164
26	134
26	135
26	136
26	137
26	178
26	179
26	140
26	141
26	180
26	143
26	144
26	145
26	146
26	181
26	182
27	86
27	87
27	88
27	112
27	113
27	114
27	92
27	93
27	132
27	95
27	96
27	97
27	98
27	116
27	117
27	118
27	119
27	120
27	121
27	123
27	124
27	125
27	126
27	127
27	128
27	129
27	183
27	133
28	86
28	87
28	88
28	112
28	113
28	114
28	92
28	93
28	132
28	95
28	96
28	97
28	98
28	116
28	117
28	118
28	119
28	120
28	121
28	123
28	124
28	125
28	126
28	127
28	128
28	129
28	184
28	133
29	86
29	87
29	88
29	112
29	113
29	114
29	92
29	93
29	132
29	95
29	96
29	97
29	98
29	116
29	117
29	118
29	119
29	120
29	121
29	123
29	124
29	125
29	126
29	127
29	128
29	129
29	184
29	185
29	133
30	99
30	100
30	101
30	102
30	103
30	104
30	105
30	106
30	107
30	108
30	109
30	110
30	111
30	186
31	99
31	100
31	101
31	102
31	103
31	104
31	105
31	106
31	107
31	108
31	109
31	110
31	111
31	186
31	187
32	99
32	100
32	101
32	102
32	103
32	104
32	105
32	106
32	107
32	108
32	109
32	110
32	111
32	186
32	187
32	188
33	99
33	100
33	101
33	102
33	103
33	104
33	105
33	106
33	107
33	108
33	109
33	110
33	111
33	186
33	187
33	188
33	189
34	99
34	100
34	101
34	102
34	103
34	104
34	105
34	106
34	107
34	108
34	109
34	110
34	111
34	186
34	187
34	188
34	189
34	190
34	191
34	192
34	193
34	194
34	195
35	99
35	100
35	101
35	102
35	103
35	104
35	105
35	106
35	107
35	108
35	109
35	110
35	111
35	186
35	187
35	188
35	189
35	190
35	191
35	192
35	193
35	194
35	195
35	196
36	99
36	100
36	101
36	102
36	103
36	104
36	105
36	106
36	107
36	108
36	109
36	110
36	111
36	186
36	187
36	188
36	189
36	190
36	191
36	192
36	193
36	194
36	195
36	196
36	197
37	198
37	199
37	200
37	201
37	202
37	203
37	204
37	205
37	206
37	207
37	208
37	209
37	210
38	198
38	199
38	200
38	201
38	211
38	212
38	204
38	205
38	213
38	207
38	208
38	209
38	210
38	214
39	73
39	74
39	75
39	76
39	77
39	78
39	79
39	80
39	81
39	82
39	84
39	85
39	215
40	73
40	74
40	75
40	76
40	77
40	78
40	79
40	80
40	81
40	82
40	84
40	85
40	215
40	216
41	73
41	74
41	75
41	76
41	77
41	78
41	79
41	80
41	81
41	82
41	84
41	85
41	215
41	216
41	217
42	73
42	74
42	75
42	76
42	77
42	78
42	79
42	80
42	81
42	82
42	84
42	85
42	215
42	216
42	217
42	218
43	73
43	74
43	75
43	76
43	77
43	78
43	79
43	80
43	81
43	82
43	84
43	85
43	215
43	216
43	217
43	218
43	219
44	73
44	74
44	75
44	76
44	77
44	78
44	79
44	80
44	81
44	82
44	84
44	85
44	215
44	216
44	217
44	218
44	219
44	220
44	221
44	222
44	223
44	224
44	225
44	226
45	73
45	74
45	75
45	76
45	77
45	78
45	79
45	80
45	81
45	82
45	84
45	85
45	215
45	216
45	217
45	218
45	219
45	220
45	221
45	222
45	223
45	224
45	225
45	226
45	227
46	73
46	74
46	75
46	76
46	77
46	78
46	79
46	80
46	81
46	82
46	84
46	85
46	215
46	216
46	217
46	218
46	219
46	220
46	221
46	222
46	223
46	224
46	225
46	226
46	227
46	228
47	229
47	230
47	231
47	232
47	233
47	234
47	235
47	236
47	237
47	238
47	239
47	240
47	241
48	242
48	243
48	244
48	245
48	246
48	247
48	248
48	249
48	250
48	251
48	252
48	253
48	254
49	242
49	243
49	244
49	255
49	256
49	257
49	248
49	249
49	258
49	251
49	252
49	253
49	254
49	259
49	260
49	261
49	262
49	263
49	264
49	265
49	266
49	267
49	268
49	269
49	270
49	271
49	272
49	273
50	242
50	243
50	244
50	255
50	256
50	257
50	248
50	249
50	258
50	251
50	252
50	253
50	254
50	259
50	260
50	261
50	262
50	263
50	264
50	266
50	267
50	268
50	269
50	270
50	271
50	272
50	274
50	273
51	242
51	243
51	244
51	255
51	256
51	257
51	248
51	249
51	258
51	251
51	252
51	253
51	254
51	259
51	260
51	261
51	262
51	263
51	264
51	266
51	267
51	268
51	269
51	270
51	271
51	272
51	274
51	275
51	273
52	276
52	277
52	278
52	279
52	280
52	281
52	282
52	283
52	284
52	285
52	286
52	287
52	288
53	276
53	277
53	278
53	289
53	290
53	291
53	282
53	283
53	292
53	285
53	293
53	286
53	287
53	288
53	294
53	295
53	296
53	297
53	298
53	299
53	300
53	301
53	302
53	303
53	304
53	305
53	306
54	276
54	277
54	278
54	289
54	290
54	307
54	282
54	283
54	308
54	285
54	293
54	286
54	287
54	288
54	294
54	295
54	296
54	297
54	298
54	299
54	300
54	301
54	302
54	303
54	304
54	305
54	306
55	276
55	277
55	278
55	289
55	290
55	307
55	282
55	283
55	308
55	285
55	293
55	286
55	287
55	288
55	294
55	295
55	296
55	297
55	299
55	300
55	301
55	302
55	303
55	304
55	305
55	309
55	306
56	276
56	277
56	278
56	289
56	290
56	307
56	282
56	283
56	308
56	285
56	293
56	286
56	287
56	288
56	294
56	295
56	296
56	297
56	299
56	300
56	301
56	302
56	303
56	304
56	305
56	309
56	310
56	306
57	276
57	277
57	278
57	289
57	290
57	307
57	282
57	283
57	308
57	285
57	293
57	286
57	287
57	288
57	294
57	295
57	296
57	297
57	299
57	300
57	301
57	302
57	303
57	304
57	305
57	309
57	310
57	311
57	306
58	73
58	74
58	75
58	76
58	77
58	78
58	79
58	80
58	81
58	82
58	84
58	85
58	215
58	216
58	218
58	219
58	220
58	221
58	222
58	223
58	224
58	225
58	226
58	227
58	228
58	312
59	313
59	314
59	315
59	316
59	317
59	318
59	319
59	320
59	321
59	322
59	323
59	324
59	325
60	326
60	327
60	328
60	329
60	330
60	331
60	332
60	333
60	334
60	335
60	336
60	337
60	338
61	326
61	327
61	328
61	339
61	340
61	341
61	332
61	333
61	342
61	335
61	336
61	337
61	338
61	343
61	344
61	345
61	346
61	347
61	348
61	349
61	350
61	351
61	352
61	353
61	354
61	355
61	356
62	326
62	327
62	328
62	339
62	340
62	341
62	332
62	333
62	342
62	335
62	336
62	337
62	338
62	343
62	344
62	345
62	346
62	348
62	349
62	350
62	351
62	352
62	353
62	354
62	355
62	357
62	356
63	326
63	327
63	328
63	339
63	340
63	341
63	332
63	333
63	342
63	335
63	336
63	337
63	338
63	343
63	344
63	345
63	346
63	348
63	349
63	350
63	351
63	352
63	353
63	354
63	355
63	357
63	358
63	356
64	313
64	314
64	315
64	359
64	360
64	361
64	319
64	320
64	362
64	322
64	324
64	325
64	363
64	364
64	365
64	366
65	367
65	368
65	369
65	370
65	371
65	372
65	373
65	374
65	375
65	376
65	377
65	378
65	379
66	380
66	381
66	382
66	383
66	384
66	385
66	386
66	387
66	388
66	389
66	390
66	391
66	392
67	380
67	381
67	382
67	393
67	394
67	395
67	386
67	387
67	396
67	389
67	390
67	391
67	392
67	397
67	398
67	399
67	400
67	401
67	402
67	403
67	404
67	405
67	406
67	407
67	408
67	409
67	410
68	367
68	368
68	369
68	411
68	412
68	413
68	373
68	374
68	414
68	376
68	377
68	378
68	379
68	415
68	416
68	417
68	418
68	419
68	420
68	421
68	422
68	423
68	424
68	425
68	426
68	427
68	428
68	429
69	380
69	381
69	382
69	393
69	394
69	430
69	386
69	387
69	431
69	389
69	390
69	391
69	392
69	397
69	398
69	399
69	400
69	401
69	402
69	403
69	404
69	405
69	406
69	407
69	408
69	409
69	410
70	367
70	368
70	369
70	411
70	412
70	413
70	373
70	374
70	432
70	376
70	377
70	378
70	379
70	415
70	416
70	417
70	418
70	419
70	420
70	421
70	422
70	423
70	424
70	425
70	426
70	427
70	428
70	429
71	433
71	434
71	435
71	436
71	437
71	438
71	439
71	440
71	441
71	442
71	443
71	444
71	445
72	380
72	381
72	382
72	393
72	394
72	430
72	386
72	387
72	431
72	389
72	390
72	391
72	392
72	397
72	398
72	399
72	400
72	401
72	403
72	404
72	405
72	406
72	407
72	408
72	409
72	446
72	410
73	380
73	381
73	382
73	393
73	394
73	430
73	386
73	387
73	431
73	389
73	390
73	391
73	392
73	397
73	398
73	399
73	400
73	401
73	403
73	404
73	405
73	406
73	407
73	408
73	409
73	446
73	447
73	410
74	367
74	368
74	369
74	411
74	412
74	413
74	373
74	374
74	432
74	376
74	377
74	378
74	379
74	415
74	416
74	417
74	418
74	419
74	420
74	422
74	423
74	424
74	425
74	426
74	427
74	428
74	448
74	429
75	449
75	450
75	451
75	452
75	453
75	454
75	455
75	456
75	457
75	458
75	459
75	460
75	461
76	462
76	463
76	464
76	465
76	466
76	467
76	468
76	469
76	470
76	471
76	472
76	473
76	474
77	449
77	450
77	475
77	476
77	477
77	478
77	455
77	456
77	479
77	458
77	459
77	460
77	461
77	480
77	481
77	482
77	483
77	484
77	485
77	486
77	487
77	488
77	489
77	490
77	491
77	492
77	493
77	494
78	449
78	450
78	475
78	476
78	477
78	478
78	455
78	456
78	495
78	458
78	459
78	460
78	461
78	480
78	481
78	482
78	483
78	484
78	485
78	486
78	487
78	488
78	489
78	490
78	491
78	492
78	493
78	494
79	462
79	463
79	464
79	465
79	466
79	467
79	468
79	469
79	470
79	471
79	472
79	473
79	474
79	496
80	462
80	463
80	464
80	465
80	466
80	467
80	468
80	469
80	470
80	471
80	472
80	473
80	474
80	496
80	497
81	462
81	463
81	464
81	465
81	466
81	467
81	468
81	469
81	470
81	471
81	472
81	473
81	474
81	496
81	497
81	498
82	462
82	463
82	464
82	465
82	466
82	467
82	468
82	469
82	470
82	471
82	472
82	473
82	474
82	496
82	497
82	498
82	499
83	462
83	463
83	464
83	465
83	466
83	467
83	468
83	469
83	470
83	471
83	472
83	473
83	474
83	496
83	497
83	498
83	499
83	500
83	501
83	502
83	503
83	504
83	505
83	506
84	462
84	463
84	464
84	465
84	466
84	467
84	468
84	469
84	470
84	471
84	472
84	473
84	474
84	496
84	497
84	498
84	499
84	500
84	501
84	502
84	503
84	504
84	505
84	506
84	507
85	462
85	463
85	464
85	465
85	466
85	467
85	468
85	469
85	470
85	471
85	472
85	473
85	474
85	496
85	497
85	498
85	499
85	500
85	501
85	502
85	503
85	504
85	505
85	506
85	507
85	508
86	449
86	450
86	475
86	476
86	477
86	478
86	455
86	456
86	495
86	458
86	459
86	460
86	461
86	480
86	481
86	482
86	483
86	484
86	485
86	486
86	487
86	488
86	489
86	490
86	491
86	492
86	493
86	509
86	494
87	449
87	450
87	475
87	476
87	477
87	478
87	455
87	456
87	495
87	458
87	459
87	460
87	461
87	480
87	481
87	482
87	483
87	484
87	485
87	486
87	487
87	488
87	489
87	490
87	491
87	492
87	493
87	509
87	510
87	494
88	511
88	512
88	513
88	514
88	515
88	516
88	517
88	518
88	519
88	520
88	521
88	522
88	523
89	511
89	512
89	513
89	524
89	525
89	526
89	517
89	518
89	527
89	520
89	521
89	522
89	523
89	528
89	529
89	530
89	531
89	532
89	533
89	534
89	535
89	536
89	537
89	538
89	539
89	540
89	541
89	542
90	543
90	544
90	545
90	546
90	547
90	548
90	549
90	550
90	551
90	552
90	553
90	554
90	555
91	543
91	544
91	545
91	546
91	556
91	557
91	549
91	550
91	558
91	552
91	553
91	554
91	555
91	559
91	560
91	561
91	562
91	563
91	564
91	565
92	99
92	100
92	101
92	102
92	566
92	567
92	105
92	106
92	568
92	108
92	109
92	110
92	111
92	186
92	187
92	188
92	189
92	190
92	191
92	192
92	193
92	194
92	195
92	196
92	197
92	569
93	19
93	69
93	21
93	22
93	32
93	33
93	25
93	26
93	72
93	28
93	29
93	30
93	31
93	570
93	71
93	35
94	19
94	69
94	21
94	22
94	32
94	33
94	25
94	26
94	72
94	28
94	29
94	30
94	31
94	570
94	571
94	71
94	35
95	19
95	69
95	21
95	22
95	32
95	33
95	25
95	26
95	72
95	28
95	29
95	30
95	31
95	570
95	571
95	572
95	71
95	35
96	19
96	69
96	21
96	22
96	32
96	33
96	25
96	26
96	72
96	28
96	29
96	30
96	31
96	570
96	571
96	572
96	573
96	574
96	575
96	576
96	577
96	578
96	71
96	35
97	19
97	69
97	21
97	22
97	32
97	33
97	25
97	26
97	72
97	28
97	29
97	30
97	31
97	570
97	571
97	572
97	573
97	574
97	575
97	576
97	577
97	578
97	579
97	71
97	35
98	19
98	69
98	21
98	22
98	32
98	33
98	25
98	26
98	72
98	28
98	29
98	30
98	31
98	570
98	571
98	572
98	573
98	574
98	575
98	576
98	577
98	578
98	579
98	580
98	71
98	35
99	581
99	582
99	583
99	584
99	585
99	586
99	587
99	588
99	589
99	590
99	591
99	592
99	593
100	581
100	582
100	583
100	584
100	594
100	595
100	587
100	588
100	596
100	590
100	591
100	592
100	593
100	597
100	598
100	599
100	600
100	601
100	602
100	603
100	604
100	605
100	606
100	607
100	608
100	609
101	581
101	582
101	583
101	584
101	594
101	595
101	587
101	588
101	596
101	590
101	591
101	592
101	593
101	597
101	598
101	599
101	600
101	601
101	602
101	603
101	604
101	605
101	606
101	607
101	608
101	610
101	609
102	581
102	582
102	583
102	584
102	594
102	595
102	587
102	588
102	596
102	590
102	591
102	592
102	593
102	597
102	598
102	599
102	600
102	601
102	602
102	605
102	606
102	607
102	608
102	610
102	611
102	612
102	613
102	614
102	609
103	615
103	616
103	617
103	618
103	619
103	620
103	621
103	622
103	623
103	624
103	625
103	626
103	627
104	615
104	616
104	617
104	628
104	629
104	630
104	621
104	622
104	631
104	624
104	625
104	626
104	627
104	632
104	633
104	634
104	635
104	636
104	637
104	638
104	639
104	640
104	641
104	642
104	643
105	615
105	616
105	617
105	628
105	629
105	630
105	621
105	622
105	631
105	624
105	625
105	626
105	627
105	632
105	633
105	634
105	635
105	636
105	637
105	638
105	639
105	640
105	641
105	642
105	644
105	643
106	615
106	616
106	617
106	628
106	629
106	630
106	621
106	622
106	631
106	624
106	625
106	626
106	627
106	632
106	633
106	634
106	635
106	636
106	637
106	638
106	639
106	640
106	641
106	642
106	644
106	645
106	643
\.


--
-- Data for Name: evaluation_method_configuration; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.evaluation_method_configuration (id, opportunity_id, type) FROM stdin;
1	1	documentary
\.


--
-- Name: evaluation_method_configuration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.evaluation_method_configuration_id_seq', 1, true);


--
-- Data for Name: evaluationmethodconfiguration_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.evaluationmethodconfiguration_meta (id, object_id, key, value) FROM stdin;
2	1	fetchCategories	""
3	1	infos	""
1	1	fetch	{"3":"00-09","5":"82-99","6":"61-81","20":"10-60"}
\.


--
-- Name: evaluationmethodconfiguration_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.evaluationmethodconfiguration_meta_id_seq', 3, true);


--
-- Data for Name: event; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event (id, project_id, name, short_description, long_description, rules, create_timestamp, status, agent_id, is_verified, type, update_timestamp, subsite_id) FROM stdin;
\.


--
-- Data for Name: event_attendance; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event_attendance (id, user_id, event_occurrence_id, event_id, space_id, type, reccurrence_string, start_timestamp, end_timestamp, create_timestamp) FROM stdin;
\.


--
-- Name: event_attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_attendance_id_seq', 1, false);


--
-- Name: event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_id_seq', 1, false);


--
-- Data for Name: event_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event_meta (key, object_id, value, id) FROM stdin;
\.


--
-- Name: event_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_meta_id_seq', 1, false);


--
-- Data for Name: event_occurrence; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event_occurrence (id, space_id, event_id, rule, starts_on, ends_on, starts_at, ends_at, frequency, separation, count, until, timezone_name, status) FROM stdin;
\.


--
-- Data for Name: event_occurrence_cancellation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event_occurrence_cancellation (id, event_occurrence_id, date) FROM stdin;
\.


--
-- Name: event_occurrence_cancellation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_occurrence_cancellation_id_seq', 1, false);


--
-- Name: event_occurrence_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_occurrence_id_seq', 1, false);


--
-- Data for Name: event_occurrence_recurrence; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.event_occurrence_recurrence (id, event_occurrence_id, month, day, week) FROM stdin;
\.


--
-- Name: event_occurrence_recurrence_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.event_occurrence_recurrence_id_seq', 1, false);


--
-- Data for Name: file; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.file (id, md5, mime_type, name, object_type, object_id, create_timestamp, grp, description, parent_id, path, private) FROM stdin;
23	7de5bf1a4f8b5c49769ee19ad51be264	image/png	blob-4d2e19409dabe63f47a8c06859c50153.png	MapasCulturais\\Entities\\Agent	1	2021-03-22 14:20:55	img:avatarBig	\N	20	agent/1/file/20/blob-4d2e19409dabe63f47a8c06859c50153.png	f
20	2408b2b2bd5be288a5c69767156074a5	image/png	blob.png	MapasCulturais\\Entities\\Agent	1	2021-03-22 14:20:52	avatar	\N	\N	agent/1/blob.png	f
99	75cd1196c539834f3763f551804bb55a	application/zip	on-576481439 - 605a40e193307.zip	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:26:25	zipArchive	\N	\N	registration/576481439/on-576481439 - 605a40e193307.zip	t
60	af3394f5453f58b50c062cb07eeec67d	application/pdf	decreto_auxilio_setor_alimentação.pdf	MapasCulturais\\Entities\\Opportunity	1	2021-03-22 18:42:31	rules	\N	\N	opportunity/1/decreto_auxilio_setor_alimentação.pdf	f
54	28535513f67bc062927aa93c632a9619	image/png	blob-5c0a2b02e426972d4fa47e078953bade.png	MapasCulturais\\Entities\\Opportunity	1	2021-03-22 15:53:58	img:avatarMedium	\N	52	opportunity/1/file/52/blob-5c0a2b02e426972d4fa47e078953bade.png	f
52	0ab0a11b4306ec102969d85cd2c39e47	image/png	blob.png	MapasCulturais\\Entities\\Opportunity	1	2021-03-22 15:53:58	avatar	\N	\N	opportunity/1/blob.png	f
55	a61dd85a73a8756fa5f98c976469020e	image/png	blob-b1eb98bd4aa334bc7a411b673fae80cb.png	MapasCulturais\\Entities\\Opportunity	1	2021-03-22 15:53:58	img:avatarBig	\N	52	opportunity/1/file/52/blob-b1eb98bd4aa334bc7a411b673fae80cb.png	f
17	ea3ee360ecd769aab512efe72a1d52b3	image/png	blob-35323d383e58046c11f193f9afee14b9.png	MapasCulturais\\Entities\\Project	1	2021-03-22 14:17:29	img:avatarSmall	\N	16	project/1/file/16/blob-35323d383e58046c11f193f9afee14b9.png	f
18	7c59de94dbe9f140a7ec8f5d35b934bd	image/png	blob-3556a5a0dd003b1ef5f9a2d3e6527ce0.png	MapasCulturais\\Entities\\Project	1	2021-03-22 14:17:29	img:avatarMedium	\N	16	project/1/file/16/blob-3556a5a0dd003b1ef5f9a2d3e6527ce0.png	f
19	31996df989b45edd58780d43ccc8b273	image/png	blob-507cd04a06ccdd97ce2f6aaf55e4011d.png	MapasCulturais\\Entities\\Project	1	2021-03-22 14:17:29	img:avatarBig	\N	16	project/1/file/16/blob-507cd04a06ccdd97ce2f6aaf55e4011d.png	f
16	b93a2b5475e3d47ee1e36595929834b2	image/png	blob.png	MapasCulturais\\Entities\\Project	1	2021-03-22 14:17:29	avatar	\N	\N	project/1/blob.png	f
21	63e065c8c258ae69ed8935509cb1aae5	image/png	blob-e1966b7478ffff194fa0bb6f75437a5e.png	MapasCulturais\\Entities\\Agent	1	2021-03-22 14:20:52	img:avatarSmall	\N	20	agent/1/file/20/blob-e1966b7478ffff194fa0bb6f75437a5e.png	f
22	e35d55ff4f349db3c0ae429f291346d8	image/png	blob-95008c6e27efac753237ee61b7c868e8.png	MapasCulturais\\Entities\\Agent	1	2021-03-22 14:20:52	img:avatarMedium	\N	20	agent/1/file/20/blob-95008c6e27efac753237ee61b7c868e8.png	f
45	040c507cb825732b2303c7dcf20769c4	image/png	blob-e2efa13937e7ae0f886086c619baec70.png	MapasCulturais\\Entities\\Project	2	2021-03-22 15:46:30	img:avatarSmall	\N	44	project/2/file/44/blob-e2efa13937e7ae0f886086c619baec70.png	f
46	d998f63511100da24909867b5f509bc8	image/png	blob-43ec9716868cf46afc106629f95b5369.png	MapasCulturais\\Entities\\Project	2	2021-03-22 15:46:30	img:avatarMedium	\N	44	project/2/file/44/blob-43ec9716868cf46afc106629f95b5369.png	f
47	804253673f8708ae807c7bf1f7e360a7	image/png	blob-790c7a90e9c51ff220f4aca080658711.png	MapasCulturais\\Entities\\Project	2	2021-03-22 15:46:30	img:avatarBig	\N	44	project/2/file/44/blob-790c7a90e9c51ff220f4aca080658711.png	f
44	47a31586693553afdc7e8691e30341ca	image/png	blob.png	MapasCulturais\\Entities\\Project	2	2021-03-22 15:46:30	avatar	\N	\N	project/2/blob.png	f
76	f44354aa22d8b4b38b67f3ab6c6733c9	image/png	blob-f6263ee112c02c89be86c932bc7848cc.png	MapasCulturais\\Entities\\Agent	6	2021-03-23 09:41:23	img:avatarBig	\N	73	agent/6/file/73/blob-f6263ee112c02c89be86c932bc7848cc.png	f
57	6c993fdd5dc2cfb2c495def848ba3002	image/png	blob-48396016242c80780d3dd18891278d90.png	MapasCulturais\\Entities\\Agent	4	2021-03-22 17:25:35	img:avatarSmall	\N	56	agent/4/file/56/blob-48396016242c80780d3dd18891278d90.png	f
58	29638da26715d3132472e53afd13263e	image/png	blob-d0fb334f083cf6b4ae141bfee80d582e.png	MapasCulturais\\Entities\\Agent	4	2021-03-22 17:25:35	img:avatarMedium	\N	56	agent/4/file/56/blob-d0fb334f083cf6b4ae141bfee80d582e.png	f
59	c9acdc5d127d3256ca9a2b19c712b316	image/png	blob-84df76a07645658ef805a1a03f627903.png	MapasCulturais\\Entities\\Agent	4	2021-03-22 17:25:36	img:avatarBig	\N	56	agent/4/file/56/blob-84df76a07645658ef805a1a03f627903.png	f
56	622b4210228e1bb83db7e2e4eb29b6a4	image/png	blob.png	MapasCulturais\\Entities\\Agent	4	2021-03-22 17:25:35	avatar	\N	\N	agent/4/blob.png	f
72	6aa319f82671092aef932610340ad891	image/png	blob-b74fed9e3029109c2c9210c66a19039c.png	MapasCulturais\\Entities\\Agent	3	2021-03-22 18:55:11	img:avatarBig	\N	69	agent/3/file/69/blob-b74fed9e3029109c2c9210c66a19039c.png	f
69	8c5efbf06f5c3ded30397b8394b28b71	image/png	blob.png	MapasCulturais\\Entities\\Agent	3	2021-03-22 18:55:10	avatar	\N	\N	agent/3/blob.png	f
70	c8816c95da845ac8a09d962d11f17ced	image/png	blob-fb2447640091d96d94322a87e69effda.png	MapasCulturais\\Entities\\Agent	3	2021-03-22 18:55:10	img:avatarSmall	\N	69	agent/3/file/69/blob-fb2447640091d96d94322a87e69effda.png	f
71	b9f41d46ae6ebd589386fdeb87016547	image/png	blob-783c5df24b04617e044c16a8d7bf8da4.png	MapasCulturais\\Entities\\Agent	3	2021-03-22 18:55:11	img:avatarMedium	\N	69	agent/3/file/69/blob-783c5df24b04617e044c16a8d7bf8da4.png	f
74	f71bb3b9e645668e4843af59c6410996	image/png	blob-a26bcd9196a311db23775c4cf7615319.png	MapasCulturais\\Entities\\Agent	6	2021-03-23 09:41:21	img:avatarSmall	\N	73	agent/6/file/73/blob-a26bcd9196a311db23775c4cf7615319.png	f
75	6199c48653d13005debfe05441c2e237	image/png	blob-606793a0339baed347fee7a65b82f267.png	MapasCulturais\\Entities\\Agent	6	2021-03-23 09:41:21	img:avatarMedium	\N	73	agent/6/file/73/blob-606793a0339baed347fee7a65b82f267.png	f
73	e4f7fa5982d2b55e652ce51a8d43c75d	image/png	blob.png	MapasCulturais\\Entities\\Agent	6	2021-03-23 09:41:21	avatar	\N	\N	agent/6/blob.png	f
77	97cf95468b69de8b00e0848317fccaeb	image/jpeg	on-561465857 - 605a3d246b740 - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:10:28	rfc_6	\N	\N	registration/561465857/on-561465857 - 605a3d246b740 - COMPROVANTE DE CPF.jpg	t
78	97cf95468b69de8b00e0848317fccaeb	image/jpeg	on-561465857 - 605a3d3679932 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:10:46	rfc_7	\N	\N	registration/561465857/on-561465857 - 605a3d3679932 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
79	97cf95468b69de8b00e0848317fccaeb	image/jpeg	on-561465857 - 605a3da6caf6c - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:12:38	rfc_2	\N	\N	registration/561465857/on-561465857 - 605a3da6caf6c - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
80	97cf95468b69de8b00e0848317fccaeb	image/jpeg	on-561465857 - 605a3df7e9a0b - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:13:59	rfc_5	\N	\N	registration/561465857/on-561465857 - 605a3df7e9a0b - COMPROVANTE DE CNPJ.jpg	t
81	97cf95468b69de8b00e0848317fccaeb	image/jpeg	on-561465857 - 605a3e06aabcf - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:14:14	rfc_1	\N	\N	registration/561465857/on-561465857 - 605a3e06aabcf - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
82	1e5a5a78240b0acf05367e4990272b45	image/png	on-561465857 - 605a3e19b9242 - COMPROVANTE DE DATA DA ADMISSÃO.png	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:14:33	rfc_4	\N	\N	registration/561465857/on-561465857 - 605a3e19b9242 - COMPROVANTE DE DATA DA ADMISSÃO.png	t
83	d6c320b096997ef96ae2c4c72052f316	image/png	on-561465857 - 605a3e281be47 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.png	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:14:48	rfc_3	\N	\N	registration/561465857/on-561465857 - 605a3e281be47 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.png	t
84	1e5a5a78240b0acf05367e4990272b45	image/png	on-561465857 - 605a3e3bb8053 - COMPROVANTE DE CONTA BANCÁRIA.png	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:15:07	rfc_8	\N	\N	registration/561465857/on-561465857 - 605a3e3bb8053 - COMPROVANTE DE CONTA BANCÁRIA.png	t
85	703b558e0129bc6d1bbe3e90d8204868	application/zip	on-561465857 - 605a3ea4620d0.zip	MapasCulturais\\Entities\\Registration	561465857	2021-03-23 16:16:52	zipArchive	\N	\N	registration/561465857/on-561465857 - 605a3ea4620d0.zip	t
86	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a3f9483041 - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:20:52	rfc_6	\N	\N	registration/576481439/on-576481439 - 605a3f9483041 - COMPROVANTE DE CPF.jpg	t
87	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a3fa2d83c3 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:21:06	rfc_7	\N	\N	registration/576481439/on-576481439 - 605a3fa2d83c3 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
88	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a3fe2bda5f - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:22:10	rfc_2	\N	\N	registration/576481439/on-576481439 - 605a3fe2bda5f - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
89	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a40227947d - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:23:14	rfc_5	\N	\N	registration/576481439/on-576481439 - 605a40227947d - COMPROVANTE DE CNPJ.jpg	t
90	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a403ee9280 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:23:42	rfc_1	\N	\N	registration/576481439/on-576481439 - 605a403ee9280 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
91	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a4052a08bb - COMPROVANTE DE CPF.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:24:02	rfc_6	\N	\N	registration/483424269/on-483424269 - 605a4052a08bb - COMPROVANTE DE CPF.pdf	t
92	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a4061d4997 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:24:17	rfc_7	\N	\N	registration/483424269/on-483424269 - 605a4061d4997 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	t
93	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a406228c73 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:24:18	rfc_4	\N	\N	registration/576481439/on-576481439 - 605a406228c73 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
94	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a4071bc394 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:24:33	rfc_3	\N	\N	registration/576481439/on-576481439 - 605a4071bc394 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
95	f8ea39209d69484ab759d872adc99252	image/jpeg	on-576481439 - 605a4080cbb76 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:24:48	rfc_8	\N	\N	registration/576481439/on-576481439 - 605a4080cbb76 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
96	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a40a819821 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:25:28	rfc_2	\N	\N	registration/483424269/on-483424269 - 605a40a819821 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	t
97	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a40d363a4b - COMPROVANTE DE CNPJ.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:26:11	rfc_5	\N	\N	registration/483424269/on-483424269 - 605a40d363a4b - COMPROVANTE DE CNPJ.pdf	t
98	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a40e01fb2f - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:26:24	rfc_1	\N	\N	registration/483424269/on-483424269 - 605a40e01fb2f - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	t
100	0f39410fb8457ea9cdc79a7862ff96e9	application/zip	on-576481439 - 605a40e19796f.zip	MapasCulturais\\Entities\\Registration	576481439	2021-03-23 16:26:25	zipArchive	\N	\N	registration/576481439/on-576481439 - 605a40e19796f.zip	t
101	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a411386b32 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:27:15	rfc_4	\N	\N	registration/483424269/on-483424269 - 605a411386b32 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	t
102	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a41287783c - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:27:36	rfc_3	\N	\N	registration/483424269/on-483424269 - 605a41287783c - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
103	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-483424269 - 605a413721bed - COMPROVANTE DE CONTA BANCÁRIA.pdf	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:27:51	rfc_8	\N	\N	registration/483424269/on-483424269 - 605a413721bed - COMPROVANTE DE CONTA BANCÁRIA.pdf	t
104	b97d2590fcf4d6bf76f33364c77e95f2	application/zip	on-483424269 - 605a416a88ab1.zip	MapasCulturais\\Entities\\Registration	483424269	2021-03-23 16:28:42	zipArchive	\N	\N	registration/483424269/on-483424269 - 605a416a88ab1.zip	t
53	47a91b93edc7cf250360a25ddbed938d	image/png	blob-e9bcb4e657a72c22bc27afcdd7a11cf1.png	MapasCulturais\\Entities\\Opportunity	1	2021-03-22 15:53:58	img:avatarSmall	\N	52	opportunity/1/file/52/blob-e9bcb4e657a72c22bc27afcdd7a11cf1.png	f
105	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2b22afc59 - COMPROVANTE DE CPF.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:05:54	rfc_6	\N	\N	registration/1905133426/on-1905133426 - 605b2b22afc59 - COMPROVANTE DE CPF.pdf	t
106	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2b3cb7583 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:06:20	rfc_7	\N	\N	registration/1905133426/on-1905133426 - 605b2b3cb7583 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	t
107	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2c049d144 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:09:40	rfc_2	\N	\N	registration/1905133426/on-1905133426 - 605b2c049d144 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	t
108	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2e39b92de - COMPROVANTE DE CNPJ.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:19:05	rfc_5	\N	\N	registration/1905133426/on-1905133426 - 605b2e39b92de - COMPROVANTE DE CNPJ.pdf	t
109	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2e563dbe3 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:19:34	rfc_1	\N	\N	registration/1905133426/on-1905133426 - 605b2e563dbe3 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	t
110	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2e7084652 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:20:00	rfc_4	\N	\N	registration/1905133426/on-1905133426 - 605b2e7084652 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	t
111	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2edb71e31 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:21:47	rfc_3	\N	\N	registration/1905133426/on-1905133426 - 605b2edb71e31 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
112	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-1905133426 - 605b2f144c1f9 - COMPROVANTE DE CONTA BANCÁRIA.pdf	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:22:44	rfc_8	\N	\N	registration/1905133426/on-1905133426 - 605b2f144c1f9 - COMPROVANTE DE CONTA BANCÁRIA.pdf	t
113	d4f9bf1a0946a8f66fa790a34adff9ca	application/zip	on-1905133426 - 605b2fc479093.zip	MapasCulturais\\Entities\\Registration	1905133426	2021-03-24 09:25:40	zipArchive	\N	\N	registration/1905133426/on-1905133426 - 605b2fc479093.zip	t
114	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b3541b56de - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:49:05	rfc_6	\N	\N	registration/971249312/on-971249312 - 605b3541b56de - COMPROVANTE DE CPF.jpg	t
115	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b3553abfef - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:49:23	rfc_7	\N	\N	registration/971249312/on-971249312 - 605b3553abfef - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
116	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b3589bb530 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:50:17	rfc_2	\N	\N	registration/971249312/on-971249312 - 605b3589bb530 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
117	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b361a7bff1 - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:52:42	rfc_5	\N	\N	registration/971249312/on-971249312 - 605b361a7bff1 - COMPROVANTE DE CNPJ.jpg	t
118	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b3629c070e - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:52:57	rfc_1	\N	\N	registration/971249312/on-971249312 - 605b3629c070e - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
119	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b3654c0399 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:53:40	rfc_4	\N	\N	registration/971249312/on-971249312 - 605b3654c0399 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
120	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b366620cc5 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:53:58	rfc_3	\N	\N	registration/971249312/on-971249312 - 605b366620cc5 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
121	f8ea39209d69484ab759d872adc99252	image/jpeg	on-971249312 - 605b367aeaba6 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:54:18	rfc_8	\N	\N	registration/971249312/on-971249312 - 605b367aeaba6 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
122	293467e4332df9637c30120add42ed2c	application/zip	on-971249312 - 605b36b84dfc9.zip	MapasCulturais\\Entities\\Registration	971249312	2021-03-24 09:55:20	zipArchive	\N	\N	registration/971249312/on-971249312 - 605b36b84dfc9.zip	t
123	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b38368ab6d - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:01:42	rfc_6	\N	\N	registration/1926833684/on-1926833684 - 605b38368ab6d - COMPROVANTE DE CPF.jpg	t
124	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b384183bd5 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:01:53	rfc_7	\N	\N	registration/1926833684/on-1926833684 - 605b384183bd5 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
125	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b3871b78cf - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:02:41	rfc_2	\N	\N	registration/1926833684/on-1926833684 - 605b3871b78cf - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
126	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b392c17f8a - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:05:48	rfc_5	\N	\N	registration/1926833684/on-1926833684 - 605b392c17f8a - COMPROVANTE DE CNPJ.jpg	t
127	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b393bd7399 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:06:03	rfc_1	\N	\N	registration/1926833684/on-1926833684 - 605b393bd7399 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
128	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b396f153b4 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:06:55	rfc_4	\N	\N	registration/1926833684/on-1926833684 - 605b396f153b4 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
129	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b3977c32f8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:07:03	rfc_3	\N	\N	registration/1926833684/on-1926833684 - 605b3977c32f8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
130	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1926833684 - 605b398842a25 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:07:20	rfc_8	\N	\N	registration/1926833684/on-1926833684 - 605b398842a25 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
131	d2700ac28a272a479cff071b00dab76d	application/zip	on-1926833684 - 605b39b464ed5.zip	MapasCulturais\\Entities\\Registration	1926833684	2021-03-24 10:08:04	zipArchive	\N	\N	registration/1926833684/on-1926833684 - 605b39b464ed5.zip	t
138	1ee6704d5698a7f852fdab1c0163143a	application/pdf	on-735327624 - 605bac237592c - COMPROVANTE DE CPF.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:16:19	rfc_6	\N	\N	registration/735327624/on-735327624 - 605bac237592c - COMPROVANTE DE CPF.pdf	t
135	cc6bb6672508e12d548b3388b66c4c29	image/png	blob-3-a77f5f31a269b908ad99d5cb0bcfac7d.png	MapasCulturais\\Entities\\Project	2	2021-03-24 17:30:37	img:header	\N	134	project/2/file/134/blob-3-a77f5f31a269b908ad99d5cb0bcfac7d.png	f
134	91755ad7a727212b0780367194f0ca62	image/png	blob-3.png	MapasCulturais\\Entities\\Project	2	2021-03-24 17:30:37	header	\N	\N	project/2/blob-3.png	f
139	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bac41e4b02 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:16:49	rfc_7	\N	\N	registration/735327624/on-735327624 - 605bac41e4b02 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	t
140	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605baceb117be - COMPROVANTE DE CNPJ.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:19:39	rfc_5	\N	\N	registration/735327624/on-735327624 - 605baceb117be - COMPROVANTE DE CNPJ.pdf	t
141	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bad0eb83e0 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:20:14	rfc_9	\N	\N	registration/735327624/on-735327624 - 605bad0eb83e0 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	t
142	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bad1fa71ca - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:20:31	rfc_1	\N	\N	registration/735327624/on-735327624 - 605bad1fa71ca - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	t
143	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bad42d91db - COMPROVANTE DE DATA DA ADMISSÃO.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:21:06	rfc_4	\N	\N	registration/735327624/on-735327624 - 605bad42d91db - COMPROVANTE DE DATA DA ADMISSÃO.pdf	t
144	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bad4da18f1 - COMPROVANTE DE CONTA BANCÁRIA.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:21:17	rfc_8	\N	\N	registration/735327624/on-735327624 - 605bad4da18f1 - COMPROVANTE DE CONTA BANCÁRIA.pdf	t
145	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605badafe4c79 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:22:55	rfc_2	\N	\N	registration/735327624/on-735327624 - 605badafe4c79 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	t
146	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605badc204430 - COMPROVANTE DE DEFICIÊNCIA.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:23:14	rfc_10	\N	\N	registration/735327624/on-735327624 - 605badc204430 - COMPROVANTE DE DEFICIÊNCIA.pdf	t
147	864b4ec49417fc0bb032a6b4d6e298e7	application/pdf	on-735327624 - 605bae96de701 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:26:46	rfc_3	\N	\N	registration/735327624/on-735327624 - 605bae96de701 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
148	670e07348937cf90a1b2ab4b8736b0ea	application/zip	on-735327624 - 605baea06ab7f.zip	MapasCulturais\\Entities\\Registration	735327624	2021-03-24 18:26:56	zipArchive	\N	\N	registration/735327624/on-735327624 - 605baea06ab7f.zip	t
149	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc3428b8db - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:54:58	rfc_6	\N	\N	registration/1731020007/on-1731020007 - 605bc3428b8db - COMPROVANTE DE CPF.jpg	t
150	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc34f9ad83 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:55:11	rfc_7	\N	\N	registration/1731020007/on-1731020007 - 605bc34f9ad83 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
151	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc3bd4825f - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:57:01	rfc_2	\N	\N	registration/1731020007/on-1731020007 - 605bc3bd4825f - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
152	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc3d480560 - COMPROVANTE DE DEFICIÊNCIA.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:57:24	rfc_10	\N	\N	registration/1731020007/on-1731020007 - 605bc3d480560 - COMPROVANTE DE DEFICIÊNCIA.jpg	t
153	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc41d02d3b - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:58:37	rfc_5	\N	\N	registration/1731020007/on-1731020007 - 605bc41d02d3b - COMPROVANTE DE CNPJ.jpg	t
154	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc44429095 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:59:16	rfc_9	\N	\N	registration/1731020007/on-1731020007 - 605bc44429095 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpg	t
155	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc452c09ee - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:59:30	rfc_1	\N	\N	registration/1731020007/on-1731020007 - 605bc452c09ee - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
156	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc46a45613 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 19:59:54	rfc_4	\N	\N	registration/1731020007/on-1731020007 - 605bc46a45613 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
157	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc47e55dc5 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 20:00:14	rfc_3	\N	\N	registration/1731020007/on-1731020007 - 605bc47e55dc5 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
158	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1731020007 - 605bc48f78cd1 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 20:00:31	rfc_8	\N	\N	registration/1731020007/on-1731020007 - 605bc48f78cd1 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
159	3bd44698b4dc839bea1619c61a4c6e20	application/zip	on-1731020007 - 605bc4f755306.zip	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 20:02:15	zipArchive	\N	\N	registration/1731020007/on-1731020007 - 605bc4f755306.zip	t
160	9cd980166f5c5a3aeb9b7abf41d58a8a	application/zip	on-1731020007 - 605bc4f773fa8.zip	MapasCulturais\\Entities\\Registration	1731020007	2021-03-24 20:02:15	zipArchive	\N	\N	registration/1731020007/on-1731020007 - 605bc4f773fa8.zip	t
161	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c833056e22 - COMPROVANTE DE CPF.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:33:52	rfc_6	\N	\N	registration/792482838/on-792482838 - 605c833056e22 - COMPROVANTE DE CPF.pdf	t
162	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c8346e56f8 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:34:14	rfc_7	\N	\N	registration/792482838/on-792482838 - 605c8346e56f8 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	t
163	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c838019d8b - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:35:12	rfc_2	\N	\N	registration/792482838/on-792482838 - 605c838019d8b - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	t
164	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c839303cc0 - COMPROVANTE DE DEFICIÊNCIA.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:35:31	rfc_10	\N	\N	registration/792482838/on-792482838 - 605c839303cc0 - COMPROVANTE DE DEFICIÊNCIA.pdf	t
165	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c83c9d6fea - COMPROVANTE DE CNPJ.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:36:25	rfc_5	\N	\N	registration/792482838/on-792482838 - 605c83c9d6fea - COMPROVANTE DE CNPJ.pdf	t
166	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c83e5c4377 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:36:53	rfc_9	\N	\N	registration/792482838/on-792482838 - 605c83e5c4377 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	t
167	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c8400d6ce6 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:37:20	rfc_1	\N	\N	registration/792482838/on-792482838 - 605c8400d6ce6 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	t
168	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c8410946b1 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:37:36	rfc_4	\N	\N	registration/792482838/on-792482838 - 605c8410946b1 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	t
169	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-792482838 - 605c8426a3da3 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:37:58	rfc_3	\N	\N	registration/792482838/on-792482838 - 605c8426a3da3 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
170	f7c2d1cf0481bb92cc12a876756fccf2	application/pdf	on-792482838 - 605c8436dbd65 - COMPROVANTE DE CONTA BANCÁRIA.pdf	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:38:14	rfc_8	\N	\N	registration/792482838/on-792482838 - 605c8436dbd65 - COMPROVANTE DE CONTA BANCÁRIA.pdf	t
171	9100dc180ff2d82516d213eae9e40acc	application/zip	on-792482838 - 605c84a24b539.zip	MapasCulturais\\Entities\\Registration	792482838	2021-03-25 09:40:02	zipArchive	\N	\N	registration/792482838/on-792482838 - 605c84a24b539.zip	t
172	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8b88a6de7 - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:09:28	rfc_6	\N	\N	registration/1689674626/on-1689674626 - 605c8b88a6de7 - COMPROVANTE DE CPF.jpg	t
173	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8b95997ac - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:09:41	rfc_7	\N	\N	registration/1689674626/on-1689674626 - 605c8b95997ac - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
174	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8bc2c1ead - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:10:26	rfc_2	\N	\N	registration/1689674626/on-1689674626 - 605c8bc2c1ead - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
175	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-1593864955 - 605c8c1e4e130 - COMPROVANTE DE CPF.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:11:58	rfc_6	\N	\N	registration/1593864955/on-1593864955 - 605c8c1e4e130 - COMPROVANTE DE CPF.pdf	t
176	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-1593864955 - 605c8c2b80900 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:12:11	rfc_7	\N	\N	registration/1593864955/on-1593864955 - 605c8c2b80900 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.pdf	t
177	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8c3758a7a - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:12:23	rfc_5	\N	\N	registration/1689674626/on-1689674626 - 605c8c3758a7a - COMPROVANTE DE CNPJ.jpg	t
178	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8c4fe5185 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:12:47	rfc_9	\N	\N	registration/1689674626/on-1689674626 - 605c8c4fe5185 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpg	t
179	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-1593864955 - 605c8c50c1d3d - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:12:48	rfc_2	\N	\N	registration/1593864955/on-1593864955 - 605c8c50c1d3d - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.pdf	t
180	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8c6f79d80 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:13:19	rfc_1	\N	\N	registration/1689674626/on-1689674626 - 605c8c6f79d80 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
181	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8c866407b - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:13:42	rfc_4	\N	\N	registration/1689674626/on-1689674626 - 605c8c866407b - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
182	990eca6dc93e273b1a512479dc41f78b	application/pdf	on-1593864955 - 605c8c8a4e0d3 - COMPROVANTE DE CNPJ.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:13:46	rfc_5	\N	\N	registration/1593864955/on-1593864955 - 605c8c8a4e0d3 - COMPROVANTE DE CNPJ.pdf	t
183	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8c956df54 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:13:57	rfc_3	\N	\N	registration/1689674626/on-1689674626 - 605c8c956df54 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
184	990eca6dc93e273b1a512479dc41f78b	application/pdf	on-1593864955 - 605c8c9f968a3 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:14:07	rfc_9	\N	\N	registration/1593864955/on-1593864955 - 605c8c9f968a3 - COMPROVANTE DE ENDEREÇO DA EMPRESA.pdf	t
185	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8ca8019a4 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:14:16	rfc_8	\N	\N	registration/1689674626/on-1689674626 - 605c8ca8019a4 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
186	990eca6dc93e273b1a512479dc41f78b	application/pdf	on-1593864955 - 605c8cb2e8590 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:14:26	rfc_1	\N	\N	registration/1593864955/on-1593864955 - 605c8cb2e8590 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.pdf	t
187	990eca6dc93e273b1a512479dc41f78b	application/pdf	on-1593864955 - 605c8cc8da243 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:14:48	rfc_4	\N	\N	registration/1593864955/on-1593864955 - 605c8cc8da243 - COMPROVANTE DE DATA DA ADMISSÃO.pdf	t
188	990eca6dc93e273b1a512479dc41f78b	application/pdf	on-1593864955 - 605c8cd9a3ba8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:15:05	rfc_3	\N	\N	registration/1593864955/on-1593864955 - 605c8cd9a3ba8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
189	0fae24c3a5437377d1dee82bcf4747d3	application/pdf	on-1593864955 - 605c8ce99737f - COMPROVANTE DE CONTA BANCÁRIA.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:15:21	rfc_8	\N	\N	registration/1593864955/on-1593864955 - 605c8ce99737f - COMPROVANTE DE CONTA BANCÁRIA.pdf	t
190	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1689674626 - 605c8d5186857 - COMPROVANTE DE DEFICIÊNCIA.jpg	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:17:05	rfc_10	\N	\N	registration/1689674626/on-1689674626 - 605c8d5186857 - COMPROVANTE DE DEFICIÊNCIA.jpg	t
191	c6e11a77561a2b1ccad886eea24f14fd	application/zip	on-1689674626 - 605c8d56f348e.zip	MapasCulturais\\Entities\\Registration	1689674626	2021-03-25 10:17:11	zipArchive	\N	\N	registration/1689674626/on-1689674626 - 605c8d56f348e.zip	t
192	f7c2d1cf0481bb92cc12a876756fccf2	application/pdf	on-1593864955 - 605c8da6157c3 - COMPROVANTE DE DEFICIÊNCIA.pdf	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:18:30	rfc_10	\N	\N	registration/1593864955/on-1593864955 - 605c8da6157c3 - COMPROVANTE DE DEFICIÊNCIA.pdf	t
193	1c82bc22e71312db64bc2ece75d9d983	application/zip	on-1593864955 - 605c8dab07be9.zip	MapasCulturais\\Entities\\Registration	1593864955	2021-03-25 10:18:35	zipArchive	\N	\N	registration/1593864955/on-1593864955 - 605c8dab07be9.zip	t
194	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c905f8bcbe - COMPROVANTE DE CPF.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:30:07	rfc_6	\N	\N	registration/1020199467/on-1020199467 - 605c905f8bcbe - COMPROVANTE DE CPF.png	t
195	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c907381a52 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:30:27	rfc_7	\N	\N	registration/1020199467/on-1020199467 - 605c907381a52 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.png	t
196	ed1b0d8fe84bb8405fba737c367a9a0e	image/jpeg	on-1967657373 - 605c90bc4d804 - COMPROVANTE DE CPF.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:31:40	rfc_6	\N	\N	registration/1967657373/on-1967657373 - 605c90bc4d804 - COMPROVANTE DE CPF.jpeg	t
197	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c90da35160 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:32:10	rfc_2	\N	\N	registration/1020199467/on-1020199467 - 605c90da35160 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.png	t
198	ed1b0d8fe84bb8405fba737c367a9a0e	image/jpeg	on-1967657373 - 605c9102e81cf - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:32:50	rfc_7	\N	\N	registration/1967657373/on-1967657373 - 605c9102e81cf - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpeg	t
199	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c91340131e - COMPROVANTE DE CNPJ.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:33:40	rfc_5	\N	\N	registration/1020199467/on-1020199467 - 605c91340131e - COMPROVANTE DE CNPJ.png	t
229	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd91279d0e - COMPROVANTE DE DEFICIÊNCIA.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:52:34	rfc_10	\N	\N	registration/1715162904/on-1715162904 - 605dd91279d0e - COMPROVANTE DE DEFICIÊNCIA.jpg	t
200	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c9176cbe1b - COMPROVANTE DE ENDEREÇO DA EMPRESA.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:34:46	rfc_9	\N	\N	registration/1020199467/on-1020199467 - 605c9176cbe1b - COMPROVANTE DE ENDEREÇO DA EMPRESA.png	t
201	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c9186bfde4 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:35:02	rfc_1	\N	\N	registration/1020199467/on-1020199467 - 605c9186bfde4 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.png	t
202	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c91a22483a - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:35:30	rfc_2	\N	\N	registration/1967657373/on-1967657373 - 605c91a22483a - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpeg	t
203	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c91b8bc028 - COMPROVANTE DE DATA DA ADMISSÃO.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:35:52	rfc_4	\N	\N	registration/1020199467/on-1020199467 - 605c91b8bc028 - COMPROVANTE DE DATA DA ADMISSÃO.png	t
204	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c91cc71e47 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:36:12	rfc_3	\N	\N	registration/1020199467/on-1020199467 - 605c91cc71e47 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.png	t
205	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c9277a952d - COMPROVANTE DE CNPJ.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:39:03	rfc_5	\N	\N	registration/1967657373/on-1967657373 - 605c9277a952d - COMPROVANTE DE CNPJ.jpeg	t
206	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c92a939f71 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:39:53	rfc_9	\N	\N	registration/1967657373/on-1967657373 - 605c92a939f71 - COMPROVANTE DE ENDEREÇO DA EMPRESA.jpeg	t
207	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c92cd6cd47 - COMPROVANTE DE DATA DA ADMISSÃO.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:40:29	rfc_4	\N	\N	registration/1967657373/on-1967657373 - 605c92cd6cd47 - COMPROVANTE DE DATA DA ADMISSÃO.jpeg	t
208	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c92ed16457 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:41:01	rfc_3	\N	\N	registration/1967657373/on-1967657373 - 605c92ed16457 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpeg	t
209	fc019cb294cf31bc7db7ac316a99e646	image/jpeg	on-1967657373 - 605c930c04450 - COMPROVANTE DE CONTA BANCÁRIA.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:41:32	rfc_8	\N	\N	registration/1967657373/on-1967657373 - 605c930c04450 - COMPROVANTE DE CONTA BANCÁRIA.jpeg	t
210	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c936e25796 - COMPROVANTE DE CONTA BANCÁRIA.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:43:10	rfc_8	\N	\N	registration/1020199467/on-1020199467 - 605c936e25796 - COMPROVANTE DE CONTA BANCÁRIA.png	t
211	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c93789173f - COMPROVANTE DE DEFICIÊNCIA.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:43:20	rfc_10	\N	\N	registration/1967657373/on-1967657373 - 605c93789173f - COMPROVANTE DE DEFICIÊNCIA.jpeg	t
212	c7f2b7099bb7c535b562a61fb9bef102	image/jpeg	on-1967657373 - 605c93a5e26ec - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpeg	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:44:05	rfc_1	\N	\N	registration/1967657373/on-1967657373 - 605c93a5e26ec - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpeg	t
213	f6d122fa3f75f85245634f5393812b13	image/png	on-1020199467 - 605c93aed6493 - COMPROVANTE DE DEFICIÊNCIA.png	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:44:14	rfc_10	\N	\N	registration/1020199467/on-1020199467 - 605c93aed6493 - COMPROVANTE DE DEFICIÊNCIA.png	t
214	6dde6d60887e2980af97abfe045d292e	application/zip	on-1020199467 - 605c93b6988a4.zip	MapasCulturais\\Entities\\Registration	1020199467	2021-03-25 10:44:22	zipArchive	\N	\N	registration/1020199467/on-1020199467 - 605c93b6988a4.zip	t
215	2f44953190a26c20a368ed078bf42e02	application/zip	on-1967657373 - 605c93cf767f5.zip	MapasCulturais\\Entities\\Registration	1967657373	2021-03-25 10:44:47	zipArchive	\N	\N	registration/1967657373/on-1967657373 - 605c93cf767f5.zip	t
216	94936f68f551aeaabf1d58756960ce92	image/png	on-902053773 - 605ceba842de5 - COMPROVANTE DE CPF.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 16:59:36	rfc_6	\N	\N	registration/902053773/on-902053773 - 605ceba842de5 - COMPROVANTE DE CPF.png	t
217	94936f68f551aeaabf1d58756960ce92	image/png	on-902053773 - 605cebb430798 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 16:59:48	rfc_7	\N	\N	registration/902053773/on-902053773 - 605cebb430798 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.png	t
218	94936f68f551aeaabf1d58756960ce92	image/png	on-902053773 - 605cebe666556 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:00:38	rfc_2	\N	\N	registration/902053773/on-902053773 - 605cebe666556 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.png	t
219	6073123e64d79cf705eda8c7ac69029d	image/jpeg	on-902053773 - 605cebfbd93e8 - COMPROVANTE DE DEFICIÊNCIA.jpg	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:00:59	rfc_10	\N	\N	registration/902053773/on-902053773 - 605cebfbd93e8 - COMPROVANTE DE DEFICIÊNCIA.jpg	t
220	7b844421d277c27dee20ec9cf90bd834	image/png	on-902053773 - 605cec5350ee1 - COMPROVANTE DE CNPJ.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:02:27	rfc_5	\N	\N	registration/902053773/on-902053773 - 605cec5350ee1 - COMPROVANTE DE CNPJ.png	t
221	6073123e64d79cf705eda8c7ac69029d	image/jpeg	on-902053773 - 605cec6b0f85d - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:02:51	rfc_1	\N	\N	registration/902053773/on-902053773 - 605cec6b0f85d - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
222	6be30dd98aaf4434c671450e80faf609	image/png	on-902053773 - 605cec745aabc - COMPROVANTE DE DATA DA ADMISSÃO.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:03:00	rfc_4	\N	\N	registration/902053773/on-902053773 - 605cec745aabc - COMPROVANTE DE DATA DA ADMISSÃO.png	t
223	ea496aca3eeb398871c78f8093ed8fa8	application/pdf	on-902053773 - 605cec861f4fe - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:03:18	rfc_3	\N	\N	registration/902053773/on-902053773 - 605cec861f4fe - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.pdf	t
224	78d2ed394c1a8a31e2a314770dbe4996	image/png	on-902053773 - 605ceca04453f - COMPROVANTE DE CONTA BANCÁRIA.png	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:03:44	rfc_8	\N	\N	registration/902053773/on-902053773 - 605ceca04453f - COMPROVANTE DE CONTA BANCÁRIA.png	t
225	75cf3ea0e603e97f47e1d28a96753727	application/zip	on-902053773 - 605cecd06a23c.zip	MapasCulturais\\Entities\\Registration	902053773	2021-03-25 17:04:32	zipArchive	\N	\N	registration/902053773/on-902053773 - 605cecd06a23c.zip	t
226	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd11f3aca5 - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:18:39	rfc_6	\N	\N	registration/1715162904/on-1715162904 - 605dd11f3aca5 - COMPROVANTE DE CPF.jpg	t
227	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd894e4a05 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:50:28	rfc_7	\N	\N	registration/1715162904/on-1715162904 - 605dd894e4a05 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
228	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd8f17d03d - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:52:01	rfc_2	\N	\N	registration/1715162904/on-1715162904 - 605dd8f17d03d - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
230	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd99917841 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:54:49	rfc_1	\N	\N	registration/1715162904/on-1715162904 - 605dd99917841 - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
231	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd9b0acef3 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:55:12	rfc_4	\N	\N	registration/1715162904/on-1715162904 - 605dd9b0acef3 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
232	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dd9c2b21d8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:55:30	rfc_3	\N	\N	registration/1715162904/on-1715162904 - 605dd9c2b21d8 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
233	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dda0c96d03 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:56:44	rfc_8	\N	\N	registration/1715162904/on-1715162904 - 605dda0c96d03 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
234	f8ea39209d69484ab759d872adc99252	image/jpeg	on-1715162904 - 605dda61c1a24 - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:58:09	rfc_5	\N	\N	registration/1715162904/on-1715162904 - 605dda61c1a24 - COMPROVANTE DE CNPJ.jpg	t
235	591eab81c88b323ccfe6ab924a7929ba	application/zip	on-1715162904 - 605dda7097173.zip	MapasCulturais\\Entities\\Registration	1715162904	2021-03-26 09:58:24	zipArchive	\N	\N	registration/1715162904/on-1715162904 - 605dda7097173.zip	t
236	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de1357f561 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:27:17	rfc_7	\N	\N	registration/905535019/on-905535019 - 605de1357f561 - COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO.jpg	t
237	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de16d82718 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:28:13	rfc_2	\N	\N	registration/905535019/on-905535019 - 605de16d82718 - COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ.jpg	t
238	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de1867b98e - COMPROVANTE DE DEFICIÊNCIA.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:28:38	rfc_10	\N	\N	registration/905535019/on-905535019 - 605de1867b98e - COMPROVANTE DE DEFICIÊNCIA.jpg	t
239	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de287132fe - COMPROVANTE DE CNPJ.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:32:55	rfc_5	\N	\N	registration/905535019/on-905535019 - 605de287132fe - COMPROVANTE DE CNPJ.jpg	t
241	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de2c04281c - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:33:52	rfc_1	\N	\N	registration/905535019/on-905535019 - 605de2c04281c - COMPROVAÇÕES DE FUNÇÃOOCUPAÇÃO.jpg	t
242	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de2d9b5084 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:34:17	rfc_4	\N	\N	registration/905535019/on-905535019 - 605de2d9b5084 - COMPROVANTE DE DATA DA ADMISSÃO.jpg	t
243	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de2e46b9e2 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:34:28	rfc_3	\N	\N	registration/905535019/on-905535019 - 605de2e46b9e2 - COMPROVANTE DE DATA DESLIGAMENTODEMISSÃO.jpg	t
244	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de2fea4644 - COMPROVANTE DE CONTA BANCÁRIA.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:34:54	rfc_8	\N	\N	registration/905535019/on-905535019 - 605de2fea4644 - COMPROVANTE DE CONTA BANCÁRIA.jpg	t
245	f8ea39209d69484ab759d872adc99252	image/jpeg	on-905535019 - 605de33ab66b1 - COMPROVANTE DE CPF.jpg	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:35:54	rfc_6	\N	\N	registration/905535019/on-905535019 - 605de33ab66b1 - COMPROVANTE DE CPF.jpg	t
246	41b424787b0963c61384ea4db0b12b80	application/zip	on-905535019 - 605de36f1797b.zip	MapasCulturais\\Entities\\Registration	905535019	2021-03-26 10:36:47	zipArchive	\N	\N	registration/905535019/on-905535019 - 605de36f1797b.zip	t
\.


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.file_id_seq', 246, true);


--
-- Data for Name: geo_division; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.geo_division (id, parent_id, type, cod, name, geom) FROM stdin;
\.


--
-- Name: geo_division_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.geo_division_id_seq', 1, false);


--
-- Data for Name: metadata; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.metadata (object_id, object_type, key, value) FROM stdin;
\.


--
-- Data for Name: metalist; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.metalist (id, object_type, object_id, grp, title, description, value, create_timestamp, "order") FROM stdin;
\.


--
-- Name: metalist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.metalist_id_seq', 1, false);


--
-- Data for Name: notification; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.notification (id, user_id, request_id, message, create_timestamp, action_timestamp, status) FROM stdin;
25	6	\N	<a href="https://baresrestauranteseafins.setur.ce.gov.br/agente/3/">Valesca Dantas</a> aceitou o relacionamento do agente <a href="https://baresrestauranteseafins.setur.ce.gov.br/agente/21/">Alice Becco da Silva Rios</a> com o  <a href="https://baresrestauranteseafins.setur.ce.gov.br/oportunidade/1/">AUXÍLIO FINANCEIRO AOS PROFISSIONAIS DESEMPREGADOS DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR)</a>.	2021-03-26 12:51:07	\N	1
27	20	\N	<a href="https://baresrestauranteseafins.setur.ce.gov.br/agente/3/">Valesca Dantas</a> aceitou o relacionamento do agente <a href="https://baresrestauranteseafins.setur.ce.gov.br/agente/21/">Alice Becco da Silva Rios</a> com o  <a href="https://baresrestauranteseafins.setur.ce.gov.br/oportunidade/1/">AUXÍLIO FINANCEIRO AOS PROFISSIONAIS DESEMPREGADOS DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR)</a>.	2021-03-26 12:51:07	\N	1
\.


--
-- Name: notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.notification_id_seq', 27, true);


--
-- Data for Name: notification_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.notification_meta (id, object_id, key, value) FROM stdin;
\.


--
-- Name: notification_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.notification_meta_id_seq', 1, false);


--
-- Name: occurrence_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.occurrence_id_seq', 100000, false);


--
-- Data for Name: opportunity; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.opportunity (id, parent_id, agent_id, type, name, short_description, long_description, registration_from, registration_to, published_registrations, registration_categories, create_timestamp, update_timestamp, status, subsite_id, object_type, object_id) FROM stdin;
1	\N	4	9	AUXÍLIO FINANCEIRO AOS PROFISSIONAIS DESEMPREGADOS DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR)	PÚBLICO-ALVO: Profissionais desempregados de estabelecimentos que se enquadrem nas atividades de CNAEs principais de\nI- Restaurantes e similares;\nII -Bares e outros estabelecimentos especializados em\nservir bebidas;\nIII -Lanchonetes, casas de chá, de sucos e similares;\nIV -Bares e outros estabelecimentos especializados em\nservir bebidas, sem entretenimento;\nV -Bares e outros estabelecimentos especializados em\nservir bebidas, com entretenimento;\nVI -Serviços ambulantes de alimentação;\nVII -Fornecimento de alimentos preparados preponderantemente para empresas;\nVIII -Serviços de alimentação para eventos e recepções–bufê;\nIX -Cantinas - serviços de alimentação privativos;\nX -Fornecimento de alimentos preparados preponderantemente para consumo domiciliar.\n\nPara fazer jus ao benefício, deverão atender as seguintes condições de habilitação:\nI - terem tido o último vínculo de trabalho rescindido por iniciativa\nde estabelecimento que atue no setor para alimentação fora do lar, nos termos do art. 2º, do Decreto Nº33.991 de 18 e março de 2021, nos 12 (doze) meses anteriores à data de publicação da Lei n.º 17.409, de 12 de março de 2021, devendo essa comprovação se dar mediante a disponibilização de cópia da Carteira de Trabalho e Previdência Social – CTPS e outros documentos que se julgue necessário, conforme for exigido por ocasião do cadastramento;\nII - não terem emprego formal ativo, com registro de contrato vigente em Carteira de Trabalho e Previdência Social - CTPS;\nIII - não serem titular de benefício previdenciário ou assistencial ou serem beneficiários do seguro-desemprego ou de programa de transferência de renda federal, ressalvado o Auxílio Emergencial, ou outro benefício que venha substituí-lo, e o Programa Bolsa Família;\nIV - não exercerem, a qualquer título, cargo, emprego ou função\npública em quaisquer das esferas de governo;\nV - não terem recebido o benefício previsto na Lei Estadual n.º\n17.385, de 24 de fevereiro de 2021 (AUXILIO SETOR EVENTOS);\nVI - serem residentes no Estado do Ceará;\nVII - terem idade igual ou maior de 18 (dezoito) anos	\N	2021-03-24 00:00:00	2021-03-26 11:00:00	f	""	2021-03-22 15:47:44	2021-03-27 00:14:58	1	\N	MapasCulturais\\Entities\\Project	2
\.


--
-- Name: opportunity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.opportunity_id_seq', 1, true);


--
-- Data for Name: opportunity_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.opportunity_meta (id, object_id, key, value) FROM stdin;
2	1	registrationLimitPerOwner	1
3	1	registrationCategDescription	Selecione uma categoria
4	1	registrationCategTitle	Categoria
6	1	registrationSeals	null
7	1	registrationLimit	0
8	1	projectName	0
5	1	useAgentRelationInstituicao	dontUse
1	1	useAgentRelationColetivo	dontUse
\.


--
-- Name: opportunity_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.opportunity_meta_id_seq', 8, true);


--
-- Data for Name: pcache; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.pcache (id, user_id, action, create_timestamp, object_type, object_id) FROM stdin;
21835	1	@control	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21836	1	create	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21837	1	remove	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21838	1	destroy	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21839	1	changeOwner	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21840	1	archive	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21366	6	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21367	6	publishRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21368	6	sendUserEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21369	6	evaluateRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21370	6	reopenValuerEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21371	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21372	6	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21373	6	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21374	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21375	6	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21376	6	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21377	6	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21378	6	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21379	6	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21380	5	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21381	5	publishRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21382	5	sendUserEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21383	5	evaluateRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21384	5	reopenValuerEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21385	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21386	5	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21387	5	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21388	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21389	5	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21390	5	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21391	5	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21392	5	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21393	5	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21394	7	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21395	7	publishRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21396	7	reopenValuerEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21397	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21398	7	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21399	7	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21400	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21401	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21402	7	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21403	7	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21404	7	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21405	7	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21406	20	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21407	20	publishRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21408	20	sendUserEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21409	20	evaluateRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21410	20	reopenValuerEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21411	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21412	20	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21413	20	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21414	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21415	20	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21416	20	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21417	20	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21418	20	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21419	20	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21420	4	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21421	4	publishRegistrations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21422	4	reopenValuerEvaluations	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21423	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21424	4	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21425	4	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21426	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21427	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21428	4	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21429	4	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21430	4	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21431	4	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Opportunity	1
21432	18	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21433	18	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21434	18	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21435	18	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
19155	5	viewPrivateFiles	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19157	5	viewPrivateData	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19160	5	createAgentRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19162	5	createAgentRelationWithControl	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19164	5	removeAgentRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19165	5	removeAgentRelationWithControl	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19171	5	createSealRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
21436	18	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21437	18	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21438	18	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21439	18	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21440	18	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21441	18	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21442	18	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21443	18	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21444	18	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21445	18	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21446	18	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21447	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
19173	5	removeSealRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	6
19178	6	@control	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	7
19179	6	create	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	7
19180	6	remove	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	7
19181	6	destroy	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	7
21448	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21449	6	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21450	6	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21451	6	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21452	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21453	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21454	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21455	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21456	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21457	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21458	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21459	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21460	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21461	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21462	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21463	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
19182	6	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19183	6	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19184	6	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19185	6	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19186	6	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19187	6	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19188	6	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19190	6	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19192	6	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19193	6	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19195	6	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
19197	6	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	7
21841	1	view	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21842	1	modify	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21843	1	viewPrivateFiles	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21844	1	viewPrivateData	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21845	1	createAgentRelation	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21846	1	createAgentRelationWithControl	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21847	1	removeAgentRelation	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21848	1	removeAgentRelationWithControl	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21849	1	createSealRelation	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
21850	1	removeSealRelation	2021-03-27 00:27:11	MapasCulturais\\Entities\\Agent	1
19156	23	create	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19158	23	remove	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19159	23	destroy	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19161	23	changeOwner	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19163	23	archive	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19166	23	view	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19167	23	modify	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19168	23	viewPrivateFiles	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19169	23	viewPrivateData	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19170	23	createAgentRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19172	23	createAgentRelationWithControl	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19174	23	removeAgentRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19175	23	removeAgentRelationWithControl	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19176	23	createSealRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
19177	23	removeSealRelation	2021-03-27 03:16:50	MapasCulturais\\Entities\\Agent	24
21464	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21465	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21466	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21467	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21468	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21469	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21470	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21471	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21472	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21473	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21474	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21475	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1967657373
21476	22	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21477	22	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
19189	21	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19191	21	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19194	21	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19196	21	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19198	21	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19199	21	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19200	21	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19201	21	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19203	21	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19206	21	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19208	21	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19211	21	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19214	21	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19217	21	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19222	21	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19225	21	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	22
19245	22	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19248	22	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19252	22	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19256	22	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19260	22	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19265	22	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19271	22	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19277	22	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19283	22	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19289	22	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19294	22	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19299	22	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19305	22	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19310	22	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19314	22	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
19318	22	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	23
21478	22	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21479	22	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21480	22	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21481	22	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21482	22	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21483	22	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21484	22	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21485	22	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21486	22	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21487	22	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21488	22	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21489	22	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21490	22	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21491	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21492	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21493	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21494	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21495	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21496	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21497	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21498	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21499	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21500	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21501	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21502	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
19202	19	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19204	19	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19207	19	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19210	19	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19213	19	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19216	19	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19219	19	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19221	19	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19224	19	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19227	19	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19229	19	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19231	19	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19234	19	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19237	19	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19240	19	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19243	19	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	20
19255	20	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19262	20	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19267	20	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19274	20	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19278	20	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19287	20	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19205	9	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19209	9	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19212	9	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19215	9	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19218	9	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19220	9	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19223	9	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19226	9	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19228	9	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19230	9	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19232	9	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19235	9	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19238	9	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19241	9	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19247	9	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19249	9	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	10
19259	10	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19266	10	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19272	10	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19279	10	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19286	10	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19291	10	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19297	10	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19302	10	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19306	10	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19311	10	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19316	10	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19322	10	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19327	10	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19335	10	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19339	10	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
19345	10	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	11
21503	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21504	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21505	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21506	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21507	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21508	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21509	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21510	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21511	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21512	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21513	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21514	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21515	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21516	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1715162904
21517	15	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21518	15	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21519	15	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21520	15	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21521	15	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21522	15	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21523	15	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21524	15	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21525	15	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21526	15	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21527	15	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21528	15	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21529	15	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21530	15	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21531	15	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21532	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21533	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21534	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21535	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21536	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21537	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21538	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21539	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21540	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21541	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21542	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21543	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21544	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21545	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
19233	8	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19236	8	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19239	8	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19242	8	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19246	8	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19250	8	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19253	8	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19257	8	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19261	8	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19268	8	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19275	8	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19281	8	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19284	8	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19290	8	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19296	8	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19301	8	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	9
19321	7	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19326	7	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19331	7	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19336	7	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19338	7	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19344	7	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19348	7	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19354	7	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19359	7	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19365	7	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19370	7	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19376	7	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19382	7	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19388	7	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19394	7	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
19400	7	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	8
21546	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21547	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21548	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21549	20	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21550	20	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21551	20	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21552	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21553	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21554	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21555	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21556	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21557	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21558	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21559	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21560	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1593864955
21561	16	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21562	16	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21563	16	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21564	16	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21565	16	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21566	16	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21567	16	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21568	16	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21569	16	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21570	16	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21571	16	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21572	16	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21573	16	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21574	16	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21575	16	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21576	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21577	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21578	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21579	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21580	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21581	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21582	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21583	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21584	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21585	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21586	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21587	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21588	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21589	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21590	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21591	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21592	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21593	20	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21594	20	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21595	20	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21596	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21597	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21598	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21599	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21600	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21601	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21602	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21603	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21604	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1689674626
21605	6	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21606	6	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21607	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21608	6	modify	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21609	6	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21610	6	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21611	6	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21612	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21613	6	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21614	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
19244	17	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19251	17	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19254	17	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19258	17	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19263	17	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19270	17	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19273	17	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19280	17	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19285	17	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19304	17	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19309	17	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19315	17	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19317	17	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19323	17	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19329	17	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19333	17	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	18
19350	18	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19355	18	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19362	18	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19369	18	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19375	18	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19381	18	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19387	18	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19392	18	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19396	18	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19401	18	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19406	18	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19411	18	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19416	18	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19421	18	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19426	18	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
19430	18	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	19
21615	6	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21616	6	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21617	6	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21618	6	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21619	6	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21620	6	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21621	6	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21622	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21623	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21624	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21625	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21626	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21627	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21628	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21629	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21630	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21631	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21632	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21633	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21634	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21635	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1970483263
21636	19	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21637	19	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21638	19	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21639	19	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21640	19	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21641	19	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21642	19	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21643	19	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21644	19	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21645	19	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21646	19	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21647	19	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21648	19	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21649	19	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21650	19	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21651	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21652	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21653	6	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21654	6	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21655	6	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21656	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21657	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21658	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21659	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21660	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21661	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21662	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21663	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21664	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21665	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21666	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21667	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21668	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21669	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21670	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21671	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21672	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21673	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21674	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21675	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21676	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21677	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21678	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21679	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1020199467
21680	14	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21681	14	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21682	14	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21683	14	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21684	14	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21685	14	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21686	14	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21687	14	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21688	14	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21689	14	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21690	14	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21691	14	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21692	14	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21693	14	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21694	14	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21695	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21696	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21697	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21698	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21699	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
19264	11	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19269	11	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19276	11	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19282	11	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19288	11	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19293	11	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19298	11	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19303	11	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19308	11	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19313	11	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19319	11	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19324	11	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19330	11	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19332	11	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19337	11	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19341	11	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	12
19356	12	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19361	12	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19368	12	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19372	12	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19378	12	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19386	12	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19393	12	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19398	12	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19404	12	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19410	12	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19415	12	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19420	12	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19427	12	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19431	12	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19432	12	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
19434	12	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	13
21700	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21701	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21702	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21703	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21704	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21705	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21706	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21707	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21708	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21709	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21710	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21711	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21712	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21713	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21714	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21715	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21716	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21717	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21718	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21719	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21720	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	1731020007
21721	23	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21722	23	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21723	23	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21724	23	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21725	23	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21726	23	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21727	23	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21728	23	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21729	23	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21730	23	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21731	23	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21732	23	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21733	23	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21734	23	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21735	23	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21736	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21737	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21738	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21739	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21740	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21741	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21742	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21743	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21744	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21745	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21746	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21747	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21748	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21749	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21750	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21751	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21752	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21753	20	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21754	20	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21755	20	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
19292	20	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19295	20	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19300	20	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19307	20	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19312	20	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19320	20	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19325	20	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19328	20	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19334	20	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
19340	20	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	21
21756	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21757	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21758	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21759	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21760	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21761	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21762	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21763	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21764	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	905535019
21765	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21766	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21767	6	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21768	6	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21769	6	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21770	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21771	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21772	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21773	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21774	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21775	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21776	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21777	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21778	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21779	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21780	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21781	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21782	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21783	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21784	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21785	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21786	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21787	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21788	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21789	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21790	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21791	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21792	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21793	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	902053773
21794	4	@control	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21795	4	create	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21796	4	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21797	4	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21798	4	createSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21799	4	removeSpaceRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21800	4	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21801	4	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21802	4	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21803	4	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21804	4	remove	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21805	4	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21806	4	changeOwner	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21807	4	createAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21808	4	createAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21809	4	removeAgentRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21810	4	removeAgentRelationWithControl	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21811	4	createSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21812	4	removeSealRelation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21813	6	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21814	6	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21815	6	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21816	6	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21817	5	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21818	5	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21819	5	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21820	5	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21821	7	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21822	7	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21823	7	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21824	7	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21825	7	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21826	7	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21827	7	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21828	20	view	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21829	20	changeStatus	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21830	20	evaluate	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21831	20	viewUserEvaluation	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21832	20	viewPrivateData	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21833	20	modifyValuers	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
21834	20	viewPrivateFiles	2021-03-27 03:20:54	MapasCulturais\\Entities\\Registration	735327624
19342	16	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19347	16	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19352	16	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19360	16	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19364	16	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19374	16	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19377	16	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19383	16	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19389	16	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19395	16	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19402	16	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19407	16	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19412	16	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19417	16	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19422	16	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19425	16	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	17
19433	15	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19436	15	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19438	15	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19440	15	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19442	15	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19444	15	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19446	15	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19452	15	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19455	15	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19458	15	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19461	15	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19464	15	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19467	15	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19470	15	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19472	15	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19474	15	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	16
19343	14	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19349	14	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19353	14	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19358	14	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19366	14	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19373	14	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19380	14	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19384	14	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19390	14	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19397	14	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19403	14	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19408	14	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19414	14	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19419	14	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19424	14	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19428	14	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	15
19435	13	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19437	13	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19439	13	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19441	13	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19443	13	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19445	13	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19447	13	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19448	13	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19449	13	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19450	13	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19453	13	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19456	13	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19459	13	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19463	13	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19465	13	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19469	13	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	14
19346	4	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19351	4	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19357	4	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19363	4	destroy	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19367	4	changeOwner	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19371	4	archive	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19379	4	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19385	4	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19391	4	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19399	4	viewPrivateData	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19405	4	createAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19409	4	createAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19413	4	removeAgentRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19418	4	removeAgentRelationWithControl	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19423	4	createSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
19429	4	removeSealRelation	2021-03-27 03:16:51	MapasCulturais\\Entities\\Agent	5
20666	6	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20670	6	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20674	6	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20680	6	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20685	6	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20690	6	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	25
20714	20	@control	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20717	20	create	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20720	20	view	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20723	20	modify	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20727	20	remove	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20728	20	viewPrivateFiles	2021-03-27 03:16:51	MapasCulturais\\Entities\\Notification	27
20842	6	@control	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20843	6	modify	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20844	6	view	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20845	6	create	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20846	6	remove	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20847	6	viewPrivateFiles	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20848	6	viewPrivateData	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20849	6	createAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20850	6	createAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20851	6	removeAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20852	6	removeAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20853	5	@control	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20854	5	modify	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20855	5	view	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20856	5	create	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20857	5	remove	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20858	5	viewPrivateFiles	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20859	5	viewPrivateData	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20860	5	createAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20861	5	createAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20862	5	removeAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20863	5	removeAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20864	7	@control	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20865	7	modify	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20866	7	view	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20867	7	create	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20868	7	remove	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20869	7	viewPrivateFiles	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20870	7	viewPrivateData	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20871	7	createAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20872	7	createAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20873	7	removeAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20874	7	removeAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20875	20	@control	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20876	20	modify	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20877	20	view	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20878	20	create	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20879	20	remove	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20880	20	viewPrivateFiles	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20881	20	viewPrivateData	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20882	20	createAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20883	20	createAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20884	20	removeAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20885	20	removeAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20886	4	@control	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20887	4	modify	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20888	4	view	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20889	4	create	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20890	4	remove	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20891	4	viewPrivateFiles	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20892	4	viewPrivateData	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20893	4	createAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20894	4	createAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20895	4	removeAgentRelation	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
20896	4	removeAgentRelationWithControl	2021-03-27 03:16:52	MapasCulturais\\Entities\\EvaluationMethodConfiguration	1
\.


--
-- Name: pcache_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.pcache_id_seq', 21850, true);


--
-- Data for Name: permission_cache_pending; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.permission_cache_pending (id, object_id, object_type, status) FROM stdin;
\.


--
-- Name: permission_cache_pending_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.permission_cache_pending_seq', 469, true);


--
-- Data for Name: procuration; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.procuration (token, usr_id, attorney_user_id, action, create_timestamp, valid_until_timestamp) FROM stdin;
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.project (id, name, short_description, long_description, create_timestamp, status, agent_id, is_verified, type, parent_id, registration_from, registration_to, update_timestamp, subsite_id) FROM stdin;
1	Projeto teste	Descrição		2021-03-22 14:17:18	1	1	f	9	\N	\N	\N	2021-03-22 14:17:36	\N
2	AUXÍLIO FINANCEIRO AOS PROFISSIONAIS DESEMPREGADOS DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR)	AUXÍLIO FINANCEIRO AOS PROFISSIONAIS DESEMPREGADOS DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR)	Auxilio para trabalhadores do setor de alimentação fora do lar que estão desempregados durante o isolamento social rígido no Ceará. Eles receberão um auxílio de R$ 1 mil, que será pago em duas parcelas de R$ 500,0 reais e pretende apoiar o setor que sofre com desemprego, fechamentos e restrições de horários. O valor é destinado, por exemplo, a garçons, cozinheiros, entre outros que perderam seus postos de trabalho.	2021-03-22 15:22:53	1	3	f	9	\N	\N	\N	2021-03-24 17:30:40	\N
\.


--
-- Data for Name: project_event; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.project_event (id, event_id, project_id, type, status) FROM stdin;
\.


--
-- Name: project_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.project_event_id_seq', 1, false);


--
-- Name: project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.project_id_seq', 2, true);


--
-- Data for Name: project_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.project_meta (object_id, key, value, id) FROM stdin;
\.


--
-- Name: project_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.project_meta_id_seq', 1, false);


--
-- Name: pseudo_random_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.pseudo_random_id_seq', 19, true);


--
-- Data for Name: registration; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.registration (id, opportunity_id, category, agent_id, create_timestamp, sent_timestamp, status, agents_data, subsite_id, consolidated_result, space_data, number, valuers_exceptions_list) FROM stdin;
1967657373	1		19	2021-03-25 10:29:57	2021-03-25 10:44:47	1	{"owner":{"id":19,"name":"Ana Clara Beco da Silva","nomeCompleto":"Ana Clara Beco da Silva","documento":"142.188.283-34","dataDeNascimento":"1950-06-12","genero":"Mulher Cis","raca":"Parda","location":{"latitude":"-3.7397175","longitude":"-38.5009719"},"endereco":"Avenida Padre Ant\\u00f4nio Tom\\u00e1s, 3433, AP 900, Coc\\u00f3, 60192-125, Fortaleza, CE","En_CEP":"60192-125","En_Nome_Logradouro":"Avenida Padre Ant\\u00f4nio Tom\\u00e1s","En_Num":"3433","En_Complemento":"AP 900","En_Bairro":"Coc\\u00f3","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 999897118","telefone2":"(85) 999240967","telefonePublico":"(85) 99989-7118","emailPrivado":"anaclarabecco@hotmail.com","emailPublico":"anaclarabecco@hotmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	1	\N	on-1967657373	{"include": [], "exclude": []}
1715162904	1		23	2021-03-26 09:16:51	2021-03-26 09:58:24	1	{"owner":{"id":23,"name":"carlos texxte","nomeCompleto":"carlos texxte","documento":"456.235.122-59","dataDeNascimento":"1981-02-22","genero":"Homem Cis","raca":"Preta","location":{"latitude":"0","longitude":"0"},"endereco":"","En_CEP":"60110-160","En_Nome_Logradouro":"Pra\\u00e7a das Graviolas","En_Num":"894","En_Complemento":"Fundos","En_Bairro":"Centro","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 996548556","telefone2":null,"telefonePublico":"(85) 99688-2133","emailPrivado":"carlos.texxte@gmail.com","emailPublico":"carlos.texxte@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	0	\N	on-1715162904	{"include": [], "exclude": []}
1593864955	1		16	2021-03-25 10:09:22	2021-03-25 10:18:35	1	{"owner":{"id":16,"name":"maria Florencia fidalgo","nomeCompleto":"MARIA FLOrENCIA FIDALGO","documento":"758.359.753-68","dataDeNascimento":"1967-10-23","genero":"Mulher Cis","raca":"Branca","location":{"latitude":"-3.8450321","longitude":"-38.4805564"},"endereco":"Estrada Bar\\u00e3o de Aquiraz, 980 , Messejana, 60871-165, Fortaleza, CE","En_CEP":"60871-165","En_Nome_Logradouro":"Estrada Bar\\u00e3o de Aquiraz","En_Num":"980","En_Complemento":null,"En_Bairro":"Messejana","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 34590352","telefone2":null,"telefonePublico":"(85) 3459-0352","emailPrivado":"fabricio.fidalgo@hotmail.com","emailPublico":"fabricio.fidalgo@hotmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	-1	\N	on-1593864955	{"include": [], "exclude": []}
1689674626	1		17	2021-03-25 10:09:07	2021-03-25 10:17:11	1	{"owner":{"id":17,"name":"MARIO TEXXTE","nomeCompleto":"MARIO TEXXTE","documento":"546.225.326-54","dataDeNascimento":"1979-01-25","genero":"Homem Cis","raca":"Amarela","location":{"latitude":"-3.7384381","longitude":"-38.4915457"},"endereco":"Avenida Santos Dumont, 322 , Aldeota, 60150-161, Fortaleza, CE","En_CEP":"60150-161","En_Nome_Logradouro":"Avenida Santos Dumont","En_Num":"322","En_Complemento":null,"En_Bairro":"Aldeota","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 32455654","telefone2":"(85) 993245564","telefonePublico":"(85) 3245-5654","emailPrivado":"mario.texxte@gmail.com","emailPublico":"mario.texxte@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	1	\N	on-1689674626	{"include": [], "exclude": []}
1970483263	1		7	2021-03-25 15:55:39	\N	0	[]	\N	0	\N	on-1970483263	{"include": [], "exclude": []}
1020199467	1		20	2021-03-25 10:29:46	2021-03-25 10:44:22	1	{"owner":{"id":20,"name":"Francisco Borges","nomeCompleto":"FRANCISCO BORGES","documento":"300.749.913-53","dataDeNascimento":"1968-04-22","genero":"Homem Cis","raca":"Branca","location":{"latitude":"0","longitude":"0"},"endereco":null,"En_CEP":"60830-105","En_Nome_Logradouro":"Rua Rafael Tobias","En_Num":"2113","En_Complemento":"CASA 1","En_Bairro":"Jos\\u00e9 de Alencar","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 986122132","telefone2":"(85) 986122132","telefonePublico":null,"emailPrivado":"borges.mesquita@gmail.com","emailPublico":"borges.mesquita@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	-1	\N	on-1020199467	{"include": [], "exclude": []}
1731020007	1		15	2021-03-24 19:54:36	2021-03-24 20:02:15	1	{"owner":{"id":15,"name":"MARIA TEXXXTE","nomeCompleto":"MARIA TEXXXTE","documento":"901.234.567-70","dataDeNascimento":"1981-02-15","genero":"Mulher Cis","raca":"N\\u00e3o Informar","location":{"latitude":"-3.7384381","longitude":"-38.4915457"},"endereco":"Avenida Santos Dumont, 1517, Apt 1720, Aldeota, 60150-161, Fortaleza, CE","En_CEP":"60150-161","En_Nome_Logradouro":"Avenida Santos Dumont","En_Num":"1517","En_Complemento":"Apt 1720","En_Bairro":"Aldeota","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 931452300","telefone2":null,"telefonePublico":"(85) 3145-2300","emailPrivado":"maria.texxxte@gmail.com","emailPublico":"maria.texxxte@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	-1	\N	on-1731020007	{"include": [], "exclude": []}
905535019	1		24	2021-03-26 10:26:09	2021-03-26 10:36:47	1	{"owner":{"id":24,"name":"silvio texxte","nomeCompleto":"empresa texxte","documento":"548.221.356-08","dataDeNascimento":"1980-03-02","genero":"Homem Cis","raca":"Branca","location":{"latitude":"-3.7919684","longitude":"-38.4803519"},"endereco":"Avenida Washington Soares, 546 , Edson Queiroz, 60811-341, Fortaleza, CE","En_CEP":"60811-341","En_Nome_Logradouro":"Avenida Washington Soares","En_Num":"546","En_Complemento":null,"En_Bairro":"Edson Queiroz","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 996522145","telefone2":null,"telefonePublico":"(85) 99888-2512","emailPrivado":"silvio.texxte@gmail.com","emailPublico":"silvio.texxte@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	0	\N	on-905535019	{"include": [], "exclude": []}
902053773	1		3	2021-03-25 16:59:24	2021-03-25 17:04:32	1	{"owner":{"id":3,"name":"Valesca Dantas","nomeCompleto":"skgdsavjdgs","documento":"057.499.873-02","dataDeNascimento":"2021-03-24","genero":"Mulher Cis","raca":"Branca","location":{"latitude":"0","longitude":"0"},"endereco":null,"En_CEP":"63050-645","En_Nome_Logradouro":"Rua Doutor Jos\\u00e9 Paracampos","En_Num":"222","En_Complemento":null,"En_Bairro":"Romeir\\u00e3o","En_Municipio":"Juazeiro do Norte","En_Estado":"CE","telefone1":"(88) 888888888","telefone2":null,"telefonePublico":null,"emailPrivado":"valescadant@gmail.com","emailPublico":"valescadant@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	0	\N	on-902053773	{"include": [], "exclude": []}
735327624	1		5	2021-03-24 18:14:35	2021-03-24 18:26:56	1	{"owner":{"id":5,"name":"Valdo Mesquita","nomeCompleto":"JOS\\u00c9 VALDO MESQUITA","documento":"323.019.363-68","dataDeNascimento":"1970-03-28","genero":"Homem Cis","raca":"Branca","location":{"latitude":"0","longitude":"0"},"endereco":null,"En_CEP":"60810-786","En_Nome_Logradouro":"Avenida Rogaciano Leite","En_Num":"800","En_Complemento":"aPT 203 a","En_Bairro":"Salinas","En_Municipio":"Fortaleza","En_Estado":"CE","telefone1":"(85) 986122132","telefone2":"(85) 986122132","telefonePublico":null,"emailPrivado":"valdo.mesquita@gmail.com","emailPublico":"valdo.mesquita@gmail.com","site":null,"googleplus":null,"facebook":null,"twitter":null}}	\N	-1	\N	on-735327624	{"include": [], "exclude": []}
\.


--
-- Data for Name: registration_evaluation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.registration_evaluation (id, registration_id, user_id, result, evaluation_data, status) FROM stdin;
6	1689674626	6	1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"7":{"evaluation":"valid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"6":{"evaluation":"valid","label":"COMPROVANTE DE CPF","obs_items":"","obs":""},"2":{"evaluation":"valid","label":"COMPROVANTE DE RESID\\u00caNCIA NO ESTADO DO CEAR\\u00c1","obs_items":"","obs":""},"10":{"evaluation":"valid","label":"COMPROVANTE DE DEFICI\\u00caNCIA","obs_items":"","obs":""},"5":{"evaluation":"valid","label":"COMPROVANTE DE CNPJ","obs_items":"","obs":""},"1":{"evaluation":"valid","label":"COMPROVA\\u00c7\\u00d5ES DE FUN\\u00c7\\u00c3O\\/OCUPA\\u00c7\\u00c3O","obs_items":"","obs":""},"4":{"evaluation":"valid","label":"COMPROVANTE DE DATA DA ADMISS\\u00c3O","obs_items":"","obs":""},"3":{"evaluation":"valid","label":"COMPROVANTE DE DATA DESLIGAMENTO\\/DEMISS\\u00c3O","obs_items":"","obs":""},"8":{"evaluation":"valid","label":"COMPROVANTE DE CONTA BANC\\u00c1RIA","obs_items":"","obs":""}}	1
3	1593864955	6	-1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"6":{"evaluation":"valid","label":"COMPROVANTE DE CPF","obs_items":"","obs":""},"67":{"evaluation":"","label":"N\\u00daMERO DO DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"40":{"evaluation":"","label":"N\\u00daMERO DO CPF","obs_items":"","obs":""},"7":{"evaluation":"invalid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":"Os crit\\u00e9rios do item 3 n\\u00e3o foram atendidos."}}	1
4	735327624	6	1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"6":{"evaluation":"valid","label":"COMPROVANTE DE CPF","obs_items":"","obs":""},"7":{"evaluation":"valid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"2":{"evaluation":"valid","label":"COMPROVANTE DE RESID\\u00caNCIA NO ESTADO DO CEAR\\u00c1","obs_items":"","obs":""},"5":{"evaluation":"valid","label":"COMPROVANTE DE CNPJ","obs_items":"","obs":""},"1":{"evaluation":"valid","label":"COMPROVA\\u00c7\\u00d5ES DE FUN\\u00c7\\u00c3O\\/OCUPA\\u00c7\\u00c3O","obs_items":"","obs":""},"4":{"evaluation":"valid","label":"COMPROVANTE DE DATA DA ADMISS\\u00c3O","obs_items":"","obs":""},"3":{"evaluation":"valid","label":"COMPROVANTE DE DATA DESLIGAMENTO\\/DEMISS\\u00c3O","obs_items":"","obs":""},"8":{"evaluation":"valid","label":"COMPROVANTE DE CONTA BANC\\u00c1RIA","obs_items":"","obs":""}}	1
8	1967657373	6	1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"2":{"evaluation":"valid","label":"COMPROVANTE DE RESID\\u00caNCIA NO ESTADO DO CEAR\\u00c1","obs_items":"","obs":""}}	1
5	1020199467	6	-1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"7":{"evaluation":"valid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"6":{"evaluation":"valid","label":"COMPROVANTE DE CPF","obs_items":"","obs":""},"2":{"evaluation":"valid","label":"COMPROVANTE DE RESID\\u00caNCIA NO ESTADO DO CEAR\\u00c1","obs_items":"","obs":""},"10":{"evaluation":"valid","label":"COMPROVANTE DE DEFICI\\u00caNCIA","obs_items":"","obs":""},"5":{"evaluation":"valid","label":"COMPROVANTE DE CNPJ","obs_items":"","obs":""},"1":{"evaluation":"valid","label":"COMPROVA\\u00c7\\u00d5ES DE FUN\\u00c7\\u00c3O\\/OCUPA\\u00c7\\u00c3O","obs_items":"","obs":""},"4":{"evaluation":"invalid","label":"COMPROVANTE DE DATA DA ADMISS\\u00c3O","obs_items":"","obs":"No campo comprovante de data da admiss\\u00e3o o solicitante inseriu uma foto dele"}}	1
11	1689674626	20	1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"7":{"evaluation":"valid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""}}	1
7	1731020007	6	-1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"6":{"evaluation":"valid","label":"COMPROVANTE DE CPF","obs_items":"","obs":""},"7":{"evaluation":"valid","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"2":{"evaluation":"invalid","label":"COMPROVANTE DE RESID\\u00caNCIA NO ESTADO DO CEAR\\u00c1","obs_items":"3","obs":"nao inseriu comprovante"},"10":{"evaluation":"valid","label":"COMPROVANTE DE DEFICI\\u00caNCIA","obs_items":"","obs":"n\\u00e3o inseriu arquivo de comprovante de defici\\u00eancia"}}	1
9	735327624	20	-1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"invalid","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""}}	1
10	1593864955	20	-1	{"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o":{"evaluation":"","label":"Agente respons\\u00e1vel pela inscri\\u00e7\\u00e3o","obs_items":"","obs":""},"7":{"evaluation":"","label":"COMPROVANTE DE DOCUMENTO DE IDENTIFICA\\u00c7\\u00c3O","obs_items":"","obs":""},"30":{"evaluation":"invalid","label":"TELEFONE 1 - CELULAR OU FIXO","obs_items":"","obs":""}}	1
\.


--
-- Name: registration_evaluation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.registration_evaluation_id_seq', 11, true);


--
-- Data for Name: registration_field_configuration; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.registration_field_configuration (id, opportunity_id, title, description, categories, required, field_type, field_options, max_size, display_order, config, mask, mask_options) FROM stdin;
17	1	DECLARO QUE NÃO SOU TITULAR DE BENEFÍCIO PREVIDENCIÁRIO OU ASSISTENCIAL DO GOVERNO FEDERAL, EXCETO DO PROGRAMA BOLSA FAMÍLIA, OU DO GOVERNO ESTADUAL, CONFORME INCISO III DO ARTIGO 3º DO DECRETO Nº 33.991, DE 18 DE MARÇO DE 2021.		a:0:{}	t	checkbox	a:0:{}	0	53	a:0:{}		
4	1	PROVEDOR DE FAMÍLIA MONOPARENTAL ?	Assinale “sim”, se for homem ou mulher solo e chefe de família com, no mínimo, 01 (um/uma) dependente menor de 18 (dezoito) anos. Família monoparental trata-se de um grupo familiar chefiado por um adulto sem cônjuge ou companheiro(a), com pelo menos uma pessoa menor de dezoito anos de idade.	a:0:{}	t	select	a:2:{i:0;s:3:"SIM";i:1;s:4:"NÃO";}	0	22	a:0:{}	\N	\N
16	1	DECLARO QUE NÃO SOU AGENTE PÚBLICO, INDEPENDENTEMENTE DA RELAÇÃO JURÍDICA, INCLUSIVE OCUPANTE DE CARGO OU FUNÇÃO TEMPORÁRIO OU DE CARGO EM COMISSÃO DE LIVRE NOMEAÇÃO E EXONERAÇÃO.	CONFORME INCISO IV DO ART. 3º DO DECRETO Nº 33.991, DE 18 DE MARÇO DE 2021	a:0:{}	t	checkbox	a:0:{}	0	54	a:0:{}		
2	1	FILHO(S) MENOR(ES) DE IDADE EM IDADE ESCOLAR DEVIDAMENTE MATRICULADO EM INSTITUIÇÃO ESCOLAR	Assinale “sim”, se for chefe de família com, no mínimo, 01 (um/uma) dependente menor de 18 (dezoito) anos, devidamente matriculado em Instituição de Ensino.	a:0:{}	t	select	a:2:{i:0;s:3:"SIM";i:1;s:4:"NÃO";}	0	23	a:4:{s:3:"cpf";s:4:"true";s:4:"name";s:4:"true";s:12:"relationship";s:4:"true";s:7:"require";a:4:{s:9:"condition";s:1:"1";s:5:"field";s:7:"field_4";s:5:"value";s:3:"SIM";s:4:"hide";s:1:"1";}}		
11	1	DADOS SOBRE A ATUAÇÃO  NO SETOR DE ALIMENTAÇÃO FORA DO LAR		a:0:{}	f	section	a:0:{}	0	25	a:1:{s:11:"entityField";s:11:"@terms:area";}		
15	1	DECLARO QUE A PRESENTE INSCRIÇÃO PARA ACESSO AO AUXÍLIO FINANCEIRO, DE QUE TRATA A LEI ESTADUAL Nº 17.409 DE 12 DE MARÇO DE 2021, É AUTODECLARADA E ÚNICA EM TODO O TERRITÓRIO BRASILEIRO		a:0:{}	t	checkbox	a:0:{}	0	55	a:0:{}		
1	1	RAÇA/COR	Assinale como se autodeclara em raça/cor.	a:0:{}	t	agent-owner-field	a:6:{s:0:"";s:13:"Não Informar";s:6:"Branca";s:6:"Branca";s:5:"Preta";s:5:"Preta";s:7:"Amarela";s:7:"Amarela";s:5:"Parda";s:5:"Parda";s:9:"Indígena";s:9:"Indígena";}	0	17	a:1:{s:11:"entityField";s:4:"raca";}		
14	1	DECLARO QUE ESTOU CIENTE EM CASO DE UTILIZAÇÃO DE QUALQUER MEIO ILÍCITO, IMORAL OU DECLARAÇÃO FALSA PARA A PARTICIPAÇÃO NESTE CREDENCIAMENTO INCORRO NAS PENALIDADES PREVISTAS NOS ARTIGOS 171 E 299 DO DECRETO LEI Nº 2.848 DE 07/12/1940 DO CODIGO PENAL		a:0:{}	t	checkbox	a:0:{}	0	56	a:0:{}	\N	\N
13	1	DECLARO QUE ESTOU CIENTE DA CONCESSÃO DAS INFORMAÇÕES POR MIM DECLARADAS NESTE FORMULÁRIO PARA VALIDAÇÃO EM OUTRAS BASES DE DADOS OFICIAIS		a:0:{}	t	checkbox	a:0:{}	0	57	a:0:{}	\N	\N
12	1	DECLARO QUE CONCORDO COM A INCLUSÃO DAS INFORMAÇÕES POR MIM DECLARADAS NESTE FORMULÁRIO NA BASE DE DADOS DA PLATAFORMA DE AUXILIO AO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR) DA SETUR - SISTUR.		a:0:{}	t	checkbox	a:0:{}	0	58	a:0:{}		
5	1	CIÊNCIA SOBRE O REPASSE DO BENEFÍCIO		a:0:{}	f	section	a:0:{}	0	59	a:0:{}	\N	\N
9	1	BREVE HISTÓRICO DE ATUAÇÃO:	Escreva de forma resumida, seu histórico na área de alimentação fora do lar e as funções que desempenhou no último emprego, além de suas principais experiências.	a:0:{}	t	text	a:0:{}	2000	39	a:1:{s:11:"entityField";s:15:"longDescription";}		
7	1	BANCO	Selecione o nome do seu Banco.	a:0:{}	t	select	a:253:{i:0;s:21:"001 - BANCO DO BRASIL";i:1;s:29:"104 - CAIXA ECONOMICA FEDERAL";i:2;s:20:"237 - BANCO BRADESCO";i:3;s:20:"341 - ITAÚ UNIBANCO";i:4;s:30:"033 - BANCO SANTANDER (BRASIL)";i:5;s:19:"260 - NU PAGAMENTOS";i:6;s:18:"323 - MERCADO PAGO";i:7;s:15:"290 - PAGSEGURO";i:8;s:23:"003 - BANCO DA AMAZONIA";i:9;s:33:"004 - BANCO DO NORDESTE DO BRASIL";i:10;s:11:"007 - BNDES";i:11;s:16:"010 - CREDICOAMO";i:12;s:36:"011 - C.SUISSE HEDGING-GRIFFO CV S/A";i:13;s:19:"012 - BANCO INBURSA";i:14;s:37:"014 - STATE STREET BR BANCO COMERCIAL";i:15;s:22:"015 - UBS BRASIL CCTVM";i:16;s:22:"016 - SICOOB CREDITRAN";i:17;s:22:"017 - BNY MELLON BANCO";i:18;s:19:"018 - BANCO TRICURY";i:19;s:20:"021 - BANCO BANESTES";i:20;s:19:"024 - BANCO BANDEPE";i:21;s:16:"025 - BANCO ALFA";i:22;s:28:"029 - BANCO ITAÚ CONSIGNADO";i:23;s:15:"036 - BANCO BBI";i:24;s:25:"037 - BANCO DO EST. DO PA";i:25;s:19:"040 - BANCO CARGILL";i:26;s:27:"041 - BANCO DO ESTADO DO RS";i:27;s:25:"047 - BANCO DO EST. DE SE";i:28;s:19:"060 - CONFIDENCE CC";i:29;s:18:"062 - HIPERCARD BM";i:30;s:22:"063 - BANCO BRADESCARD";i:31;s:36:"064 - GOLDMAN SACHS DO BRASIL BM S.A";i:32;s:19:"065 - BANCO ANDBANK";i:33;s:26:"066 - BANCO MORGAN STANLEY";i:34;s:19:"069 - BANCO CREFISA";i:35;s:29:"070 - BRB - BANCO DE BRASILIA";i:36;s:18:"074 - BCO. J.SAFRA";i:37;s:20:"075 - BANCO ABN AMRO";i:38;s:22:"076 - BANCO KDB BRASIL";i:39;s:17:"077 - BANCO INTER";i:40;s:26:"078 - HAITONG BI DO BRASIL";i:41;s:32:"079 - BANCO ORIGINAL DO AGRO S/A";i:42;s:18:"080 - B&T CC LTDA.";i:43;s:17:"081 - BANCOSEGURO";i:44;s:20:"082 - BANCO TOPÁZIO";i:45;s:27:"083 - BANCO DA CHINA BRASIL";i:46;s:36:"084 - UNIPRIME NORTE DO PARANÁ - CC";i:47;s:24:"085 - COOP CENTRAL AILOS";i:48;s:18:"088 - BANCO RANDON";i:49;s:17:"089 - CREDISAN CC";i:50;s:29:"091 - CCCM UNICRED CENTRAL RS";i:51;s:13:"092 - BRK CFI";i:52;s:27:"093 - POLOCRED SCMEPP LTDA.";i:53;s:19:"094 - BANCO FINAXIS";i:54;s:31:"095 - TRAVELEX BANCO DE CÂMBIO";i:55;s:14:"096 - BANCO B3";i:56;s:56:"097 - CREDISIS CENTRAL DE COOPERATIVAS DE CRÉDITO LTDA.";i:57;s:23:"098 - CREDIALIANÇA CCR";i:58;s:32:"099 - UNIPRIME CENTRAL CCC LTDA.";i:59;s:16:"100 - PLANNER CV";i:60;s:26:"101 - RENASCENCA DTVM LTDA";i:61;s:32:"102 - XP INVESTIMENTOS CCTVM S/A";i:62;s:15:"105 - LECCA CFI";i:63;s:21:"107 - BANCO BOCOM BBM";i:64;s:21:"108 - PORTOCRED - CFI";i:65;s:25:"111 - OLIVEIRA TRUST DTVM";i:66;s:19:"113 - MAGLIANO CCVM";i:67;s:66:"114 - CENTRAL COOPERATIVA DE CRÉDITO NO ESTADO DO ESPÍRITO SANTO";i:68;s:22:"117 - ADVANCED CC LTDA";i:69;s:25:"119 - BANCO WESTERN UNION";i:70;s:20:"120 - BANCO RODOBENS";i:71;s:19:"121 - BANCO AGIBANK";i:72;s:25:"122 - BANCO BRADESCO BERJ";i:73;s:32:"124 - BANCO WOORI BANK DO BRASIL";i:74;s:21:"125 - PLURAL BANCO BM";i:75;s:20:"126 - BR PARTNERS BI";i:76;s:16:"127 - CODEPE CVC";i:77;s:30:"128 - MS BANK BANCO DE CÂMBIO";i:78;s:19:"129 - UBS BRASIL BI";i:79;s:18:"130 - CARUANA SCFI";i:80;s:36:"131 - TULLETT PREBON BRASIL CVC LTDA";i:81;s:23:"132 - ICBC DO BRASIL BM";i:82;s:27:"133 - CRESOL CONFEDERAÇÃO";i:83;s:28:"134 - BGC LIQUIDEZ DTVM LTDA";i:84;s:13:"136 - UNICRED";i:85;s:23:"138 - GET MONEY CC LTDA";i:86;s:31:"139 - INTESA SANPAOLO BRASIL BM";i:87;s:31:"140 - EASYNVEST - TÍTULO CV SA";i:88;s:28:"142 - BROKER BRASIL CC LTDA.";i:89;s:16:"143 - TREVISO CC";i:90;s:26:"144 - BEXS BANCO DE CAMBIO";i:91;s:22:"145 - LEVYCAM CCV LTDA";i:92;s:20:"146 - GUITTA CC LTDA";i:93;s:15:"149 - FACTA CFI";i:94;s:31:"157 - ICAP DO BRASIL CTVM LTDA.";i:95;s:22:"159 - CASA CREDITO SCM";i:96;s:42:"163 - COMMERZBANK BRASIL - BANCO MÚLTIPLO";i:97;s:27:"169 - BANCO OLÉ CONSIGNADO";i:98;s:23:"173 - BRL TRUST DTVM SA";i:99;s:30:"174 - PERNAMBUCANAS FINANC CFI";i:100;s:11:"177 - GUIDE";i:101;s:35:"180 - CM CAPITAL MARKETS CCTVM LTDA";i:102;s:24:"183 - SOCRED SA - SCMEPP";i:103;s:21:"184 - BANCO ITAÚ BBA";i:104;s:31:"188 - ATIVA INVESTIMENTOS CCTVM";i:105;s:19:"189 - HS FINANCEIRA";i:106;s:15:"190 - SERVICOOP";i:107;s:28:"191 - NOVA FUTURA CTVM LTDA.";i:108;s:24:"194 - PARMETAL DTVM LTDA";i:109;s:13:"196 - FAIR CC";i:110;s:22:"197 - STONE PAGAMENTOS";i:111;s:23:"208 - BANCO BTG PACTUAL";i:112;s:20:"212 - BANCO ORIGINAL";i:113;s:16:"213 - BANCO ARBI";i:114;s:22:"217 - BANCO JOHN DEERE";i:115;s:15:"218 - BANCO BS2";i:116;s:31:"222 - BANCO CRÉDIT AGRICOLE BR";i:117;s:17:"224 - BANCO FIBRA";i:118;s:17:"233 - BANCO CIFRA";i:119;s:20:"241 - BANCO CLASSICO";i:120;s:19:"243 - BANCO MÁXIMA";i:121;s:22:"246 - BANCO ABC BRASIL";i:122;s:31:"249 - BANCO INVESTCRED UNIBANCO";i:123;s:9:"250 - BCV";i:124;s:13:"253 - BEXS CC";i:125;s:18:"254 - PARANA BANCO";i:126;s:32:"259 - MONEYCORP BANCO DE CÂMBIO";i:127;s:17:"265 - BANCO FATOR";i:128;s:18:"266 - BANCO CEDULA";i:129;s:27:"268 - BARI CIA HIPOTECÁRIA";i:130;s:16:"269 - BANCO HSBC";i:131;s:21:"270 - SAGITUR CC LTDA";i:132;s:14:"271 - IB CCTVM";i:133;s:12:"272 - AGK CC";i:134;s:33:"273 - CCR DE SÃO MIGUEL DO OESTE";i:135;s:28:"274 - MONEY PLUS SCMEPP LTDA";i:136;s:17:"276 - SENFF - CFI";i:137;s:30:"278 - GENIAL INVESTIMENTOS CVM";i:138;s:31:"279 - CCR DE PRIMAVERA DO LESTE";i:139;s:16:"280 - AVISTA CFI";i:140;s:18:"281 - CCR COOPAVEL";i:141;s:41:"283 - RB CAPITAL INVESTIMENTOS DTVM LTDA.";i:142;s:21:"285 - FRENTE CC LTDA.";i:143;s:17:"286 - CCR DE OURO";i:144;s:22:"288 - CAROL DTVM LTDA.";i:145;s:22:"289 - DECYSEO CC LTDA.";i:146;s:14:"292 - BS2 DTVM";i:147;s:26:"293 - LASTRO RDV DTVM LTDA";i:148;s:15:"296 - VISION CC";i:149;s:19:"298 - VIPS CC LTDA.";i:150;s:18:"299 - SOROCRED CFI";i:151;s:31:"300 - BANCO LA NACION ARGENTINA";i:152;s:12:"301 - BPP IP";i:153;s:24:"306 - PORTOPAR DTVM LTDA";i:154;s:30:"307 - TERRA INVESTIMENTOS DTVM";i:155;s:23:"309 - CAMBIONET CC LTDA";i:156;s:22:"310 - VORTX DTVM LTDA.";i:157;s:24:"313 - AMAZÔNIA CC LTDA.";i:158;s:13:"315 - PI DTVM";i:159;s:15:"318 - BANCO BMG";i:160;s:18:"319 - OM DTVM LTDA";i:161;s:22:"320 - BANCO CCB BRASIL";i:162;s:24:"321 - CREFAZ SCMEPP LTDA";i:163;s:25:"322 - CCR DE ABELARDO LUZ";i:164;s:17:"325 - ÓRAMA DTVM";i:165;s:18:"326 - PARATI - CFI";i:166;s:12:"329 - QI SCD";i:167;s:16:"330 - BANCO BARI";i:168;s:23:"331 - FRAM CAPITAL DTVM";i:169;s:34:"332 - ACESSO SOLUCOES PAGAMENTO SA";i:170;s:17:"335 - BANCO DIGIO";i:171;s:14:"336 - BANCO C6";i:172;s:59:"340 - SUPER PAGAMENTOS E ADMINISTRACAO DE MEIOS ELETRONICOS";i:173;s:18:"342 - CREDITAS SCD";i:174;s:22:"343 - FFA SCMEPP LTDA.";i:175;s:14:"348 - BANCO XP";i:176;s:16:"349 - AMAGGI CFI";i:177;s:25:"350 - CREHNOR LARANJEIRAS";i:178;s:20:"352 - TORO CTVM LTDA";i:179;s:34:"354 - NECTON INVESTIMENTOS S.A CVM";i:180;s:16:"355 - ÓTIMO SCD";i:181;s:18:"359 - ZEMA CFI S/A";i:182;s:25:"360 - TRINUS CAPITAL DTVM";i:183;s:11:"362 - CIELO";i:184;s:24:"363 - SOCOPA SC PAULISTA";i:185;s:36:"364 - GERENCIANET PAGTOS BRASIL LTDA";i:186;s:18:"365 - SOLIDUS CCVM";i:187;s:35:"366 - BANCO SOCIETE GENERALE BRASIL";i:188;s:17:"367 - VITREO DTVM";i:189;s:15:"368 - BANCO CSF";i:190;s:18:"370 - BANCO MIZUHO";i:191;s:22:"371 - WARREN CVMC LTDA";i:192;s:14:"373 - UP.P SEP";i:193;s:23:"376 - BANCO J.P. MORGAN";i:194;s:17:"378 - BBC LEASING";i:195;s:22:"379 - CECM COOPERFORTE";i:196;s:25:"381 - BANCO MERCEDES-BENZ";i:197;s:25:"382 - FIDUCIA SCMEPP LTDA";i:198;s:10:"383 - JUNO";i:199;s:28:"387 - BANCO TOYOTA DO BRASIL";i:200;s:31:"389 - BANCO MERCANTIL DO BRASIL";i:201;s:14:"390 - BANCO GM";i:202;s:18:"391 - CCR DE IBIAM";i:203;s:26:"393 - BANCO VOLKSWAGEN S.A";i:204;s:28:"394 - BANCO BRADESCO FINANC.";i:205;s:20:"396 - HUB PAGAMENTOS";i:206;s:17:"399 - KIRTON BANK";i:207;s:19:"412 - BANCO CAPITAL";i:208;s:17:"422 - BANCO SAFRA";i:209;s:23:"456 - BANCO MUFG BRASIL";i:210;s:34:"464 - BANCO SUMITOMO MITSUI BRASIL";i:211;s:30:"473 - BANCO CAIXA GERAL BRASIL";i:212;s:19:"477 - CITIBANK N.A.";i:213;s:20:"479 - BANCO ITAUBANK";i:214;s:31:"487 - DEUTSCHE BANKBANCO ALEMAO";i:215;s:25:"488 - JPMORGAN CHASE BANK";i:216;s:19:"492 - ING BANK N.V.";i:217;s:36:"495 - BANCO LA PROVINCIA B AIRES BCE";i:218;s:25:"505 - BANCO CREDIT SUISSE";i:219;s:16:"545 - SENSO CCVM";i:220;s:27:"600 - BANCO LUSO BRASILEIRO";i:221;s:32:"604 - BANCO INDUSTRIAL DO BRASIL";i:222;s:14:"610 - BANCO VR";i:223;s:20:"611 - BANCO PAULISTA";i:224;s:21:"612 - BANCO GUANABARA";i:225;s:16:"613 - OMNI BANCO";i:226;s:15:"623 - BANCO PAN";i:227;s:21:"626 - BANCO C6 CONSIG";i:228;s:15:"630 - SMARTBANK";i:229;s:22:"633 - BANCO RENDIMENTO";i:230;s:21:"634 - BANCO TRIANGULO";i:231;s:18:"637 - BANCO SOFISA";i:232;s:16:"643 - BANCO PINE";i:233;s:28:"652 - ITAÚ UNIBANCO HOLDING";i:234;s:20:"653 - BANCO INDUSVAL";i:235;s:20:"654 - BANCO DIGIMAIS";i:236;s:22:"655 - BANCO VOTORANTIM";i:237;s:24:"707 - BANCO DAYCOVAL S.A";i:238;s:21:"712 - BANCO OURINVEST";i:239;s:19:"739 - BANCO CETELEM";i:240;s:26:"741 - BANCO RIBEIRAO PRETO";i:241;s:18:"743 - BANCO SEMEAR";i:242;s:20:"745 - BANCO CITIBANK";i:243;s:17:"746 - BANCO MODAL";i:244;s:32:"747 - BANCO RABOBANK INTL BRASIL";i:245;s:31:"748 - BANCO COOPERATIVO SICREDI";i:246;s:23:"751 - SCOTIABANK BRASIL";i:247;s:34:"752 - BANCO BNP PARIBAS BRASIL S A";i:248;s:33:"753 - NOVO BANCO CONTINENTAL - BM";i:249;s:19:"754 - BANCO SISTEMA";i:250;s:27:"755 - BOFA MERRILL LYNCH BM";i:251;s:13:"756 - BANCOOB";i:252;s:30:"757 - BANCO KEB HANA DO BRASIL";}	0	43	a:0:{}	\N	\N
6	1	INFORMAÇÕES COMPLEMENTARES:	Descreva mais informações, caso julgue necessário.	a:0:{}	f	textarea	a:0:{}	1000	47	a:0:{}	\N	\N
21	1	DECLARO QUE TENHO IDADE IGUAL OU MAIOR DE 18 ANOS E ESTOU RESIDINDO NO ESTADO DO CEARÁ		a:0:{}	t	checkbox	a:0:{}	0	49	a:0:{}	\N	\N
22	1	COMUNIDADE TRADICIONAL	Assinale se pertence a alguma comunidade tradicional ou não.	a:0:{}	t	select	a:10:{i:0;s:10:"Indígenas";i:1;s:11:"Quilombolas";i:2;s:13:"Povos Ciganos";i:3;s:25:"Comunidades Extrativistas";i:4;s:23:"Comunidades Ribeirinhas";i:5;s:18:"Comunidades Rurais";i:6;s:25:"Pescadores(as) Artesanais";i:7;s:17:"Povos de Terreiro";i:8;s:28:"Outra comunidade tradicional";i:9;s:39:"Não pertenço a comunidade tradicional";}	0	20	a:0:{}	\N	\N
19	1	DECLARO QUE ATUEI PROFISSIONALMENTE NO SETOR DE ALIMENTAÇÃO FORA DO LAR,NOS 06 (SEIS) MESES IMEDIATAMENTE ANTERIORES À PUBLICAÇÃO DA LEI 17.409 DE 12 DE MARÇO DE 2021,CONFORME INCISO I DO ARTIGO 3º DO DECRETO Nº 33.991 DE 18 DE MARÇO DE 2021		a:0:{}	t	checkbox	a:0:{}	0	51	a:0:{}		
18	1	DECLARO QUE NÃO POSSUO EMPREGO FORMAL ATIVO COM CONTRATO DE TRABALHO FORMALIZADO NOS TERMOS DA CONSOLIDAÇÃO DAS LEIS DO TRABALHO, CONFORME INCISO II DO ARTIGO 3º DO DECRETO Nº 33.991, DE 18 DE MARÇO DE 2021.		a:0:{}	t	checkbox	a:0:{}	0	52	a:0:{}		
40	1	NÚMERO DO CPF	Preencha apenas os números, sem o uso de ponto ou hífen.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	2	a:1:{s:11:"entityField";s:9:"documento";}	\N	\N
45	1	DADOS CADASTRAIS		a:0:{}	f	section	a:0:{}	0	1	a:0:{}	\N	\N
28	1	E-MAIL	Preencha o seu endereço eletrônico.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	12	a:1:{s:11:"entityField";s:12:"emailPrivado";}	\N	\N
26	1	ENDEREÇO RESIDENCIAL	Preencha seu endereço completo.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	14	a:1:{s:11:"entityField";s:9:"@location";}		
35	1	NÚMERO DA CONTA COM O DÍGITO (XXXXXXX-XX)	Informe o número da conta com  o dígito	a:0:{}	t	text	a:0:{}	0	45	a:0:{}	\N	\N
24	1	DADOS SOCIAIS		a:0:{}	f	section	a:0:{}	0	21	a:0:{}	\N	\N
25	1	NOME, IDADE E ESCOLA DAS CRIANÇA(S)	Preencha o campo com nome da criança, idade e instituição escolar. Exemplo: Maria Ferreira, 12 anos,  EEPP Presidente. Rosivelt	a:0:{}	t	textarea	a:0:{}	2000	24	a:1:{s:7:"require";a:4:{s:9:"condition";s:1:"1";s:5:"field";s:7:"field_4";s:5:"value";s:3:"SIM";s:4:"hide";s:1:"1";}}		
39	1	ACEITE DE AUTO-DECLARAÇÕES		a:0:{}	f	section	a:0:{}	0	48	a:0:{}	\N	\N
31	1	ESTOU CIENTE DE QUE SE A CONTA BANCÁRIA INFORMADA NÃO TIVER COMO TITULAR O MEU CPF OU OS DADOS NÃO FOREM CORRETOS, O PAGAMENTO DO AUXÍLIO NÃO PODERÁ SER EFETUADO.		a:0:{}	t	checkbox	a:0:{}	0	60	a:0:{}	\N	\N
23	1	PESSOA COM DEFICIÊNCIA	Assinale conforme sua deficiência ou se não é deficiente.	a:0:{}	t	select	a:6:{i:0;s:7:"Física";i:1;s:8:"Auditiva";i:2;s:6:"Visual";i:3;s:11:"Intelectual";i:4;s:9:"Múltipla";i:5;s:19:"Não sou deficiente";}	0	18	a:1:{s:7:"require";a:4:{s:9:"condition";s:0:"";s:5:"field";s:8:"field_10";s:5:"value";s:3:"SIM";s:4:"hide";s:1:"1";}}		
38	1	DADOS DA CONTA BANCÁRIA		a:0:{}	f	section	a:0:{}	0	40	a:0:{}	\N	\N
37	1	TIPO DE CONTA BANCÁRIA	Assinale o tipo de conta bancária.	a:0:{}	t	checkboxes	a:2:{i:0;s:14:"Conta corrente";i:1;s:15:"Conta poupança";}	0	42	a:0:{}	\N	\N
36	1	NÚMERO DA AGÊNCIA COM O DÍGITO ( XXXX-XX)	Informe o número da agência bancária com o digito	a:0:{}	t	text	a:0:{}	0	44	a:0:{}	\N	\N
34	1	ESTOU CIENTE DOS PRAZOS DE COMPENSAÇÃO DAS TRANSAÇÕES DO MEU BANCO, QUE PODEM DURAR ATÉ 05 (TRÊS) DIAS ÚTEIS		a:0:{}	t	checkbox	a:0:{}	0	61	a:0:{}		
33	1	ESTOU CIENTE QUE, NO CASO DE OPTAR POR CONTA CORRENTE, HAVENDO DÉBITO NA MESMA, O MEU BANCO PODERÁ FAZER A RETENÇÃO AUTOMÁTICA DO VALOR DO BENEFÍCIO		a:0:{}	t	checkbox	a:0:{}	0	62	a:0:{}	\N	\N
32	1	ESTOU CIENTE SOBRE AS INFORMAÇÕES DO REPASSE DO BENEFÍCIO	Os repasses mensais do benefício serão efetuados via conta bancária, incluindo as contas digitais, e não haverá cobrança de taxas ou qualquer custo relacionado. Orienta-se aos que não possuem conta bancária que realizem a abertura de forma virtual, há muitos bancos que oferecem esse serviço sem custos. Fique atento aos prazos e exigências do banco escolhido. Sendo assim, você pode salvar este formulário de solicitação e retornar ao preenchimento dos respectivos campos a qualquer momento. Diante do exposto abaixo, recomendamos também que optem preferencialmente por conta poupança	a:0:{}	t	checkbox	a:0:{}	0	63	a:0:{}	\N	\N
44	1	NOME COMPLETO	Coloque seu nome conforme consta no CPF ou em outro documento oficial de identificação.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	6	a:1:{s:11:"entityField";s:12:"nomeCompleto";}	\N	\N
42	1	NOME DE IDENTIFICAÇÃO OU NOME SOCIAL	Insira um nome o qual queira ser identificado(a). Nome social é o nome pelo qual pessoas, de qualquer gênero, preferem ser chamadas cotidianamente – podendo ser em contraste com o nome oficialmente registrado.	a:0:{}	f	agent-owner-field	a:1:{i:0;s:0:"";}	0	7	a:1:{s:11:"entityField";s:4:"name";}	\N	\N
41	1	NOME DA MÃE	Preencha o nome da sua mãe conforme consta no RG ou em outro documento oficial de identificação. Ou informar como “não consta no documento de identificação”.	a:0:{}	t	text	a:0:{}	0	8	a:0:{}	\N	\N
43	1	DATA DE NASCIMENTO	Dia/Mês/Ano. Preencha o dia com dois dígitos, o mês com dois dígitos, e o ano com quatro dígitos.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	9	a:1:{s:11:"entityField";s:16:"dataDeNascimento";}	\N	\N
30	1	TELEFONE 1 - CELULAR OU FIXO	Preencha os números do seu telefone para contato e DDD, sem o uso de ponto ou hífen.	a:0:{}	t	agent-owner-field	a:1:{i:0;s:0:"";}	0	10	a:1:{s:11:"entityField";s:9:"telefone1";}	\N	\N
29	1	TELEFONE 2 - CELULAR OU FIXO	Preencha os números do seu telefone para contato e DDD, sem o uso de ponto ou hífen.	a:0:{}	f	agent-owner-field	a:1:{i:0;s:0:"";}	0	11	a:1:{s:11:"entityField";s:9:"telefone2";}	\N	\N
27	1	ORIGEM	Selecione o Estado brasileiro que você nasceu e que consta no RG ou em outro documento oficial de identificação, ou ainda se é estrangeiro(a) não naturalizado(a) brasileiro(a).	a:0:{}	t	select	a:28:{i:0;s:9:"Acre (AC)";i:1;s:12:"Alagoas (AL)";i:2;s:11:"Amapá (AP)";i:3;s:13:"Amazonas (AM)";i:4;s:10:"Bahia (BA)";i:5;s:11:"Ceará (CE)";i:6;s:21:"Distrito Federal (DF)";i:7;s:20:"Espírito Santo (ES)";i:8;s:11:"Goiás (GO)";i:9;s:14:"Maranhão (MA)";i:10;s:16:"Mato Grosso (MT)";i:11;s:23:"Mato Grosso do Sul (MS)";i:12;s:17:"Minas Gerais (MG)";i:13;s:10:"Pará (PA)";i:14;s:13:"Paraíba (PB)";i:15;s:12:"Paraná (PR)";i:16;s:15:"Pernambuco (PE)";i:17;s:11:"Piauí (PI)";i:18;s:19:"Rio de Janeiro (RJ)";i:19;s:24:"Rio Grande do Norte (RN)";i:20;s:22:"Rio Grande do Sul (RS)";i:21;s:14:"Rondônia (RO)";i:22;s:12:"Roraima (RR)";i:23;s:19:"Santa Catarina (SC)";i:24;s:15:"São Paulo (SP)";i:25;s:12:"Sergipe (SE)";i:26;s:14:"Tocantins (TO)";i:27;s:49:"Estrangeiro(a) não naturalizado(a) brasileiro(a)";}	0	13	a:0:{}		
60	1	NOME DA EMPRESA QUE TRABALHAVA	Descreva aqui o nome da sua empresa conforme descrita na Carteira de Trabalho	a:0:{}	t	text	a:0:{}	2000	26	a:0:{}		
61	1	ENDEREÇO DA EMPRESA QUE TRABALHAVA		a:0:{}	t	text	a:0:{}	2000	29	a:1:{s:11:"entityField";s:9:"@location";}		
65	1	CNPJ DA EMPRESA	Digite apenas os números, sem pontos ou hífen	a:0:{}	t	cnpj	a:0:{}	0	27	a:1:{s:11:"entityField";s:9:"documento";}		
62	1	FUNÇÃO/OCUPAÇÃO	Descreva qual função ocupada na sua empresa.	a:0:{}	t	text	a:0:{}	2000	33	a:0:{}		
67	1	NÚMERO DO DOCUMENTO DE IDENTIFICAÇÃO	Preencha os números do seu RG	a:0:{}	t	text	a:0:{}	2000	4	a:0:{}		
63	1	DATA DA ADMISSÃO		a:0:{}	t	date	a:0:{}		35	a:0:{}		
64	1	DATA DESLIGAMENTO/DEMISSÃO		a:0:{}	t	date	a:0:{}		37	a:0:{}		
66	1	OPERAÇÃO/VARIAÇÃO	Digite aqui se sua conta bancária tiver operação/variação	a:0:{}	f	text	a:0:{}	100	46	a:0:{}		
59	1	DECLARO SER TRABALHADOR (A) DESEMPREGADO DO SETOR DE BARES, RESTAURANTES E AFINS (ALIMENTAÇÃO FORA DO LAR) COM ATIVIDADES INTERROMPIDAS, CONFORME DECRETO Nº 33.991, DE 18 DE MARÇO DE 2021		a:0:{}	t	checkbox	a:0:{}	0	50	a:0:{}		
3	1	GÊNERO	Mulher Cis: Identidade de gênero coincide com sexo atribuído no nascimento.\nHomem Cis:  Identidade de gênero coincide com sexo atribuído no nascimento.\nMulher Trans: Identidade de gênero difere em diversos graus do sexo atribuído no nascimento.\nHomem Trans: Identidade de gênero difere em diversos graus do sexo atribuído no nascimento.\nNão-Binárie/Outra variabilidade: Espectro de identidade contrário ao masculino ou feminino fundamentado no sexo atribuído no nascimento. Incluem-se nesse item outras variabilidades de gênero, a exemplo de queer/questionando, intersexo, agênero, andrógine, fluido, e mais.\nNão declarada.	a:0:{}	t	agent-owner-field	a:7:{s:0:"";s:13:"Não Informar";s:10:"Mulher Cis";s:10:"Mulher Cis";s:9:"Homem Cis";s:9:"Homem Cis";s:21:"Mulher Trans/travesti";s:21:"Mulher Trans/travesti";s:11:"Homem Trans";s:11:"Homem Trans";s:33:"Não Binárie/outra variabilidade";s:33:"Não Binárie/outra variabilidade";s:14:"Não declarada";s:14:"Não declarada";}	0	16	a:1:{s:11:"entityField";s:6:"genero";}		
69	1	NÚMERO		a:0:{}	t	text	a:0:{}		30	a:0:{}		
70	1	BAIRRO		a:0:{}	t	text	a:0:{}		31	a:0:{}		
71	1	COMPLEMENTO		a:0:{}	f	text	a:0:{}		32	a:0:{}		
\.


--
-- Name: registration_field_configuration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.registration_field_configuration_id_seq', 71, true);


--
-- Data for Name: registration_file_configuration; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.registration_file_configuration (id, opportunity_id, title, description, required, categories, display_order) FROM stdin;
4	1	COMPROVANTE DE DATA DA ADMISSÃO	Faça upload da foto da Carteira de trabalho que contenha a data da sua admissão. Tamanho máximo: 10mb	t	a:0:{}	36
3	1	COMPROVANTE DE DATA DESLIGAMENTO/DEMISSÃO	Faça upload de foto da Carteira de trabalho que contenha a data do seu desligamento/demissão	t	a:0:{}	38
8	1	COMPROVANTE DE CONTA BANCÁRIA	Faça upload da foto do cartão do banco ou de um documento que mostre seus dados bancários corretamente.	t	a:0:{}	41
5	1	COMPROVANTE DE CNPJ	Faça upload de imagem que comprove o CNPJ da empresa.\nPara baixar comprovante, acesse o site: https://servicos.receita.fazenda.gov.br/servicos/cnpjreva/cnpjreva_solicitacao.asp	t	a:0:{}	28
6	1	COMPROVANTE DE CPF	Faça upload de imagem do cpf	t	a:0:{}	3
7	1	COMPROVANTE DE DOCUMENTO DE IDENTIFICAÇÃO	Faça upload de imagem do seu RG	t	a:0:{}	5
2	1	COMPROVANTE DE RESIDÊNCIA NO ESTADO DO CEARÁ	Faça o upload em PDF ou Imagem do seu comprovante de endereço ( Conta de água, luz ou telefone). O PDF ou Imagem deve ser legíveis e sem rasura. Caso não seja em seu nome, poderá enviar declaração de residência.	t	a:0:{}	15
10	1	COMPROVANTE DE DEFICIÊNCIA	Faça upload do documento que comprove sua deficiência	f	a:0:{}	19
1	1	COMPROVAÇÕES DE FUNÇÃO/OCUPAÇÃO	Faça upload de imagem da Carteira de Trabalho	t	a:0:{}	34
\.


--
-- Name: registration_file_configuration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.registration_file_configuration_id_seq', 10, true);


--
-- Name: registration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.registration_id_seq', 1, false);


--
-- Data for Name: registration_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.registration_meta (object_id, key, value, id) FROM stdin;
735327624	field_67	92008012098 SSP/CE	224
735327624	field_41	MARIA DO SOCORRO GOMES AIRES	225
735327624	field_23	Não sou deficiente	227
735327624	field_22	Não pertenço a comunidade tradicional	228
735327624	field_4	SIM	229
735327624	field_2	SIM	230
735327624	field_25	PEDRO ANTONIO\n17 ANOS\nESCOLA JESUS MARIA JOSÉ	231
735327624	field_60	SECRETARIA ESTADUAL DE TURISMO	232
735327624	field_61	RUA RAFAEL TOBIAS 2113	233
735327624	field_69	2113	234
735327624	field_70	JOSÉ DE ALENCAR	235
735327624	field_71	CASA 1	236
735327624	field_62	GARÇON	237
735327624	field_63	2020-02-02	238
735327624	field_64	2020-12-12	239
735327624	field_37	["Conta corrente"]	240
735327624	field_7	033 - BANCO SANTANDER (BRASIL)	241
735327624	field_36	1245-3	242
735327624	field_35	12490-8	243
735327624	field_21	true	244
735327624	field_59	true	245
735327624	field_18	true	246
735327624	field_17	true	247
735327624	field_16	true	248
735327624	field_15	true	249
735327624	field_14	true	250
735327624	field_12	true	251
735327624	field_13	true	252
735327624	field_31	true	253
735327624	field_34	true	254
735327624	field_33	true	255
735327624	field_32	true	256
735327624	field_27	Ceará (CE)	257
735327624	field_43	"1970-03-28"	226
1689674626	field_4	NÃO	340
735327624	field_9	TRABALHEI DE GARÇON	259
735327624	field_19	true	260
735327624	field_65	00671077000193	258
1731020007	field_67	54565789	261
1731020007	field_41	MARIA JOSE	262
1731020007	field_30	"(85) 931452300"	263
1731020007	field_29	""	264
1731020007	field_27	Bahia (BA)	265
1731020007	field_1	"N\\u00e3o Informar"	266
1731020007	field_23	Não sou deficiente	267
1731020007	field_22	Não pertenço a comunidade tradicional	268
1731020007	field_4	SIM	269
1731020007	field_2	SIM	270
1731020007	field_25	ESCOLA TEXXTE	271
1731020007	field_60	EMPRESA TEXXXTE	272
1731020007	field_61	RUA SAO JOSE	274
1731020007	field_69	128	275
1731020007	field_70	CENTRO	276
1731020007	field_62	CAIXA	277
1731020007	field_63	2020-01-05	278
1731020007	field_64	2021-01-12	279
1731020007	field_9	KLJKJJ KJKJKJK KJKJKJK KJKJKJKJ KJKJKJ	280
1731020007	field_37	["Conta corrente"]	281
1731020007	field_7	237 - BANCO BRADESCO	282
1731020007	field_36	2558-X	283
1731020007	field_35	41565-2	284
1731020007	field_21	true	285
1731020007	field_59	true	286
1731020007	field_19	true	287
1731020007	field_18	true	288
1731020007	field_17	true	289
1731020007	field_16	true	290
1731020007	field_15	true	291
1731020007	field_14	true	292
1731020007	field_13	true	293
1731020007	field_12	true	294
1731020007	field_31	true	295
1731020007	field_34	true	296
1731020007	field_33	true	297
1731020007	field_32	true	298
1689674626	field_60	RESTAURANTE MARIO TEXXTE	341
1731020007	field_65	23456789000195	273
1689674626	field_67	94565478	333
1689674626	field_41	MARIA TEXXTE	334
1689674626	field_30	"(85) 32455654"	335
1689674626	field_29	"(85) 993245564"	336
1689674626	field_27	Paraíba (PB)	337
1689674626	field_22	Não pertenço a comunidade tradicional	339
1593864955	field_67	20000000029	342
1593864955	field_41	DIANA MARIA	344
1593864955	field_30	"(85) 34590352"	345
1689674626	field_61	RUA MARIA TEXXTE	346
1593864955	field_27	Ceará (CE)	347
1689674626	field_69	588	348
1689674626	field_70	PAVUNA	349
1593864955	field_23	Não sou deficiente	350
1689674626	field_62	COZINHEIRO	351
1593864955	field_22	Não pertenço a comunidade tradicional	352
1593864955	field_4	NÃO	353
1593864955	field_60	la casita	354
1689674626	field_63	1999-03-25	356
1689674626	field_64	2020-10-15	357
1593864955	field_61	la casita	358
1689674626	field_65	08433225000143	343
1593864955	field_65	07255614000163	355
1593864955	field_69	192	359
1593864955	field_70	messejana	360
1689674626	field_9	FAÇO COMIDA	361
1689674626	field_37	["Conta corrente"]	362
1593864955	field_62	garçonete	363
1689674626	field_7	001 - BANCO DO BRASIL	364
1689674626	field_36	2555-X	365
1593864955	field_63	2019-12-01	366
1689674626	field_35	12544-3	367
1689674626	field_21	true	368
1689674626	field_59	true	369
1689674626	field_19	true	370
1689674626	field_18	true	371
1689674626	field_17	true	372
1689674626	field_16	true	373
1689674626	field_15	true	374
1689674626	field_14	true	375
1689674626	field_13	true	376
1689674626	field_12	true	377
1689674626	field_31	true	378
1689674626	field_34	true	379
1689674626	field_33	true	380
1689674626	field_32	true	381
1593864955	field_64	2021-01-06	382
1593864955	field_9	dasfahoifahionclkawhdoiahshas	383
1593864955	field_37	["Conta corrente"]	384
1593864955	field_7	001 - BANCO DO BRASIL	385
1593864955	field_36	7097097	386
1593864955	field_35	8978965	387
1593864955	field_66	660	388
1689674626	field_23	Física	338
1593864955	field_6	daksodkasodks	389
1593864955	field_21	true	390
1593864955	field_59	true	391
1593864955	field_19	true	392
1593864955	field_18	true	393
1593864955	field_17	true	394
1593864955	field_16	true	395
1593864955	field_15	true	396
1593864955	field_14	true	397
1593864955	field_13	true	398
1593864955	field_12	true	399
1593864955	field_31	true	400
1593864955	field_34	true	401
1593864955	field_33	true	402
1593864955	field_32	true	403
1020199467	field_67	9200145389 SSP/CE	404
1020199467	field_44	"FRANCISCO BORGES"	405
1020199467	field_41	MARIA DE FÁTIMA	406
1020199467	field_43	"1968-04-22"	407
1020199467	field_30	"(85) 986122132"	408
1020199467	field_29	"(85) 986122132"	409
1020199467	field_27	Ceará (CE)	410
1020199467	field_26	{"En_CEP":"60830-105","En_Nome_Logradouro":"Rua Rafael Tobias","En_Bairro":"Jos\\u00e9 de Alencar","En_Estado":"CE","En_Municipio":"Fortaleza","En_Num":"2113","En_Complemento":"CASA 1"}	411
1967657373	field_67	511881	412
1020199467	field_3	"Homem Cis"	413
1020199467	field_1	"Branca"	414
1020199467	field_23	Não sou deficiente	415
1020199467	field_22	Não pertenço a comunidade tradicional	416
1020199467	field_4	SIM	417
1020199467	field_2	SIM	418
1020199467	field_25	FRANCISBO BORGES FILHO\n14\nESCOLA JESUS MARIA JOSÉ	419
1020199467	field_60	RESTAURANTE CHICO CARANGUEIJO	421
1020199467	field_61	RUA RAFAEL TOBIAS 2113	423
1020199467	field_69	2113	424
1020199467	field_70	JOSÉ DE ALENCAR	425
1020199467	field_71	CASA 1	426
1967657373	field_41	Maria Cinira Beco	420
1967657373	field_30	"(85) 999897118"	427
1967657373	field_29	"(85) 999240967"	428
1967657373	field_27	Ceará (CE)	429
1020199467	field_62	GARÇON	430
1020199467	field_63	2020-02-02	431
1967657373	field_23	Não sou deficiente	432
1967657373	field_22	Não pertenço a comunidade tradicional	433
1967657373	field_4	SIM	434
1967657373	field_2	SIM	435
1020199467	field_64	2020-12-12	436
1967657373	field_25	Gilson Luiz Juca Rios Neto, 13 anos, Antares	437
1967657373	field_60	Coco Bambu	438
1967657373	field_61	Rua das dores	440
1967657373	field_69	333	441
1967657373	field_70	Norte	442
1020199467	field_18	true	471
1020199467	field_17	true	472
1020199467	field_16	true	473
1967657373	field_63	2016-03-01	443
1020199467	field_15	true	474
1967657373	field_64	2020-06-25	444
1967657373	field_9	Muito trabalho	445
1967657373	field_7	237 - BANCO BRADESCO	446
1967657373	field_36	1234	447
1020199467	field_9	FUI GARCON POR 11 MESES NO RESTAURANTE CHICO CARANQUEIJO	449
1020199467	field_37	["Conta corrente"]	450
1967657373	field_35	564249	448
1020199467	field_7	341 - ITAÚ UNIBANCO	451
1967657373	field_21	true	452
1967657373	field_59	true	453
1020199467	field_36	621-2	454
1967657373	field_19	true	455
1967657373	field_18	true	456
1967657373	field_17	true	457
1967657373	field_16	true	458
1967657373	field_15	true	459
1967657373	field_14	true	461
1967657373	field_13	true	462
1967657373	field_12	true	463
1967657373	field_31	true	464
1967657373	field_34	true	465
1020199467	field_35	12.485-9	460
1967657373	field_33	true	466
1020199467	field_21	true	467
1967657373	field_32	true	468
1020199467	field_59	true	469
1020199467	field_19	true	470
1020199467	field_14	true	475
1020199467	field_13	true	476
1020199467	field_12	true	477
1020199467	field_31	true	478
1020199467	field_34	true	479
1020199467	field_33	true	480
1020199467	field_32	true	481
1020199467	field_65	08836602000195	422
1967657373	field_62	Gerente	482
1967657373	field_37	["Conta corrente"]	483
1967657373	field_65	08967872000135	439
902053773	field_67	n 5474311	484
902053773	field_44	"skgdsavjdgs"	485
902053773	field_41	Maria do Bairro	486
902053773	field_43	"2021-03-24"	487
902053773	field_30	"(88) 888888888"	488
902053773	field_27	Rio Grande do Norte (RN)	489
902053773	field_26	{"En_CEP":"63050-645","En_Nome_Logradouro":"Rua Doutor Jos\\u00e9 Paracampos","En_Bairro":"Romeir\\u00e3o","En_Estado":"CE","En_Municipio":"Juazeiro do Norte","En_Num":"222"}	490
902053773	field_3	"Mulher Cis"	491
902053773	field_1	"Branca"	492
902053773	field_23	Física	493
902053773	field_22	Povos Ciganos	494
902053773	field_4	NÃO	495
902053773	field_60	srfrgcgf	496
902053773	field_70	4]]2	498
902053773	field_69	22	499
902053773	field_62	jzbjxnbg c	500
902053773	field_61	dfdghshudgvsgahjshdgvb	501
902053773	field_63	2021-03-01	502
902053773	field_64	2021-03-25	503
902053773	field_9	opouiyutrytyuuil	504
902053773	field_37	["Conta poupan\\u00e7a"]	505
902053773	field_7	015 - UBS BRASIL CCTVM	506
902053773	field_36	221455888	507
902053773	field_35	1114455227	508
902053773	field_21	true	509
902053773	field_59	true	510
902053773	field_19	true	511
902053773	field_18	true	512
902053773	field_17	true	513
902053773	field_16	true	514
902053773	field_15	true	515
902053773	field_14	true	516
902053773	field_13	true	517
902053773	field_12	true	518
902053773	field_31	true	519
902053773	field_34	true	520
902053773	field_33	true	521
902053773	field_32	true	522
902053773	field_65	16851322000184	497
1715162904	field_67	258	523
1715162904	field_41	joana texxte	524
1715162904	field_30	"(85) 996548556"	525
1715162904	field_27	Distrito Federal (DF)	526
1715162904	field_26	{"En_CEP":"60110-160","En_Nome_Logradouro":"Pra\\u00e7a das Graviolas","En_Bairro":"Centro","En_Estado":"CE","En_Municipio":"Fortaleza","En_Num":"894","En_Complemento":"Fundos"}	527
1715162904	field_23	Visual	528
1715162904	field_22	Comunidades Rurais	529
1715162904	field_4	SIM	530
1715162904	field_2	SIM	531
1715162904	field_25	francisco texxte; 4 anos; escola texxte	532
1715162904	field_60	empresa texxte	533
1715162904	field_61	rua texxte	535
1715162904	field_69	572	536
1715162904	field_70	texxte	537
1715162904	field_62	maitre	538
1715162904	field_63	2019-11-10	539
1715162904	field_64	2020-07-15	540
1715162904	field_9	coordenação de garçons	541
1715162904	field_37	["Conta poupan\\u00e7a"]	542
1715162904	field_7	104 - CAIXA ECONOMICA FEDERAL	543
1715162904	field_36	2553-2	544
1715162904	field_35	32623-1	545
1715162904	field_66	013	546
1715162904	field_21	true	547
1715162904	field_59	true	548
1715162904	field_19	true	549
1715162904	field_18	true	550
1715162904	field_17	true	551
1715162904	field_16	true	552
1715162904	field_15	true	553
1715162904	field_14	true	554
1715162904	field_13	true	555
1715162904	field_12	true	556
1715162904	field_31	true	557
1715162904	field_34	true	558
1715162904	field_33	true	559
1715162904	field_32	true	560
1715162904	field_65	08433225000143	534
905535019	field_67	89456625109	561
905535019	field_41	JOANA TEXXTE	562
905535019	field_27	Paraná (PR)	563
905535019	field_1	"Branca"	564
905535019	field_23	Múltipla	565
905535019	field_22	Povos Ciganos	566
905535019	field_4	NÃO	567
905535019	field_60	restaurante TEXXTE	568
905535019	field_61	avenida texxte	570
905535019	field_69	879	571
905535019	field_70	bairro do texxte	572
905535019	field_62	cumim	573
905535019	field_63	2019-11-10	574
905535019	field_64	2020-07-15	575
905535019	field_9	auxiliar garçons	576
905535019	field_37	["Conta corrente"]	577
905535019	field_7	104 - CAIXA ECONOMICA FEDERAL	578
905535019	field_36	3253-1	579
905535019	field_35	101255-2	580
905535019	field_66	013	581
905535019	field_21	true	582
905535019	field_59	true	583
905535019	field_19	true	584
905535019	field_18	true	585
905535019	field_17	true	586
905535019	field_16	true	587
905535019	field_15	true	588
905535019	field_14	true	589
905535019	field_13	true	590
905535019	field_12	true	591
905535019	field_31	true	592
905535019	field_34	true	593
905535019	field_33	true	594
905535019	field_32	true	595
905535019	field_30	"(85) 996522145"	596
905535019	field_65	08433225000143	569
\.


--
-- Name: registration_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.registration_meta_id_seq', 596, true);


--
-- Data for Name: request; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.request (id, request_uid, requester_user_id, origin_type, origin_id, destination_type, destination_id, metadata, type, create_timestamp, action_timestamp, status) FROM stdin;
\.


--
-- Name: request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.request_id_seq', 7, true);


--
-- Name: revision_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.revision_data_id_seq', 645, true);


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.role (id, usr_id, name, subsite_id) FROM stdin;
1	1	admin	\N
2	1	superAdmin	\N
3	1	saasAdmin	\N
4	1	superSaasAdmin	\N
5	3	admin	\N
6	3	superAdmin	\N
7	3	saasAdmin	\N
8	3	superSaasAdmin	\N
\.


--
-- Name: role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.role_id_seq', 10, true);


--
-- Data for Name: seal; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.seal (id, agent_id, name, short_description, long_description, valid_period, create_timestamp, status, certificate_text, update_timestamp, subsite_id) FROM stdin;
1	1	Selo Mapas	Descrição curta Selo Mapas	Descrição longa Selo Mapas	0	2021-03-20 21:49:19	1	\N	2021-03-20 00:00:00	\N
\.


--
-- Name: seal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.seal_id_seq', 1, false);


--
-- Data for Name: seal_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.seal_meta (id, object_id, key, value) FROM stdin;
\.


--
-- Name: seal_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.seal_meta_id_seq', 1, false);


--
-- Data for Name: seal_relation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.seal_relation (id, seal_id, object_id, create_timestamp, status, object_type, agent_id, owner_id, validate_date, renovation_request) FROM stdin;
\.


--
-- Name: seal_relation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.seal_relation_id_seq', 1, false);


--
-- Data for Name: space; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.space (id, parent_id, location, _geo_location, name, short_description, long_description, create_timestamp, status, type, agent_id, is_verified, public, update_timestamp, subsite_id) FROM stdin;
1	\N	(0,0)	\N	b,jv	bfuct	\N	2021-03-22 18:03:07	1	10	3	f	f	\N	\N
\.


--
-- Name: space_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.space_id_seq', 1, true);


--
-- Data for Name: space_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.space_meta (object_id, key, value, id) FROM stdin;
\.


--
-- Name: space_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.space_meta_id_seq', 1, false);


--
-- Data for Name: space_relation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.space_relation (id, space_id, object_id, create_timestamp, status, object_type) FROM stdin;
\.


--
-- Name: space_relation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.space_relation_id_seq', 1, false);


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: subsite; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.subsite (id, name, create_timestamp, status, agent_id, url, namespace, alias_url, verified_seals) FROM stdin;
\.


--
-- Name: subsite_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.subsite_id_seq', 1, false);


--
-- Data for Name: subsite_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.subsite_meta (object_id, key, value, id) FROM stdin;
\.


--
-- Name: subsite_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.subsite_meta_id_seq', 1, false);


--
-- Data for Name: term; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.term (id, taxonomy, term, description) FROM stdin;
1	area	Produção Cultural	
2	area	Arquitetura-Urbanismo	
3	municipio	Fortaleza	
4	area	Livro	
5	area	Leitura	
6	area	Literatura	
7	area	Gastronomia	
8	area	Turismo	
9	area	Antropologia	
10	area	Outros	
11	area	Cultura Estrangeira (imigrantes)	
12	area	Arte Digital	
13	area	Arquivo	
14	area	Artesanato	
\.


--
-- Name: term_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.term_id_seq', 14, true);


--
-- Data for Name: term_relation; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.term_relation (term_id, object_type, object_id, id) FROM stdin;
1	MapasCulturais\\Entities\\Agent	1	1
2	MapasCulturais\\Entities\\Project	1	2
3	MapasCulturais\\Entities\\Project	1	3
4	MapasCulturais\\Entities\\Agent	3	4
5	MapasCulturais\\Entities\\Agent	3	5
6	MapasCulturais\\Entities\\Agent	3	6
7	MapasCulturais\\Entities\\Project	2	7
8	MapasCulturais\\Entities\\Agent	4	8
9	MapasCulturais\\Entities\\Space	1	9
10	MapasCulturais\\Entities\\Agent	6	11
7	MapasCulturais\\Entities\\Agent	9	12
11	MapasCulturais\\Entities\\Agent	9	13
10	MapasCulturais\\Entities\\Agent	8	14
1	MapasCulturais\\Entities\\Agent	10	15
10	MapasCulturais\\Entities\\Agent	12	16
7	MapasCulturais\\Entities\\Agent	13	17
7	MapasCulturais\\Entities\\Agent	15	18
12	MapasCulturais\\Entities\\Agent	14	19
7	MapasCulturais\\Entities\\Agent	17	20
13	MapasCulturais\\Entities\\Agent	16	21
14	MapasCulturais\\Entities\\Agent	19	22
2	MapasCulturais\\Entities\\Agent	21	23
7	MapasCulturais\\Entities\\Agent	22	24
8	MapasCulturais\\Entities\\Agent	7	25
7	MapasCulturais\\Entities\\Agent	23	26
7	MapasCulturais\\Entities\\Agent	24	27
\.


--
-- Name: term_relation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.term_relation_id_seq', 27, true);


--
-- Data for Name: user_app; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.user_app (public_key, private_key, user_id, name, status, create_timestamp, subsite_id) FROM stdin;
\.


--
-- Data for Name: user_meta; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.user_meta (object_id, key, value, id) FROM stdin;
1	localAuthenticationPassword	$2y$10$0gJh.rfdpDQSXOkyo2XaeuLCk4OTN5vAe6cDbrtOKgHVXK4PTzYJe	2
17	deleteAccountToken	c6a23d4e68a37cdcffc11b6a2eae3bcc0a3d21dc	73
18	localAuthenticationPassword	$2y$10$/qoY1Oo05faI/ZgF0HAj.uyfeNFjF/w0E56QDaNIZWeNyXz4m7uCq	74
9	loginAttemp	0	39
9	deleteAccountToken	78b4d30c3129e4b9cd041f60b4ea454c0fdbc812	40
20	localAuthenticationPassword	$2y$10$xLVviRKu4gMkSzywyy5c7e81EuKg73K.1ttSJ9fju61Rq9iUhtB5O	83
20	tokenVerifyAccount	DuC.0GsGDXXZIi4.0hP3	84
1	recover_token	3DH5ESkO5Pg/HhwgqYKd	5
1	recover_token_time	1616582957	6
18	tokenVerifyAccount	fbRZGodGS.jNmyeGAzK6	75
18	accountIsActive	0	76
18	loginAttemp	0	77
18	deleteAccountToken	5da18e27fb4b28bb384540a69155557c34027228	78
3	localAuthenticationPassword	$2y$10$BBYRe8tg/V2.vj2m.6U.6Oz2aKyvvvOIQKKNECzqHdCVIGVZds42O	7
3	tokenVerifyAccount	q.oDSXuZl6Z/vXlJO7Wl	8
3	accountIsActive	0	9
7	loginAttemp	0	29
4	loginAttemp	0	15
4	localAuthenticationPassword	$2y$10$qN8N5eZ0uQSMvZ0EZYt/pe9K61NX1F61Rag9ujgz7A8DJLGzkzeR6	12
4	tokenVerifyAccount	1bCPjLVlNVk9AQu4MbJs	13
4	accountIsActive	0	14
13	localAuthenticationPassword	$2y$10$ZoGklzfGLlxuSbpNwoP9duokAvZhvMmrlH745cl4/mruNm2ndxsXi	52
13	tokenVerifyAccount	1nYlMubBCzB/Q0qDmd8b	53
13	accountIsActive	0	54
13	deleteAccountToken	de2eedf13113da2297860e3ac67821b77de5a15c	55
14	localAuthenticationPassword	$2y$10$ufyMqftb9ErtVJMncVKuquV6zDdaPgtsL00RGI58SVb73xt6GrdOu	56
14	tokenVerifyAccount	ajAVE7HWv.W6kUVEdGIm	57
14	accountIsActive	0	58
10	localAuthenticationPassword	$2y$10$kyrpXXrlgBt8gp.zMeGRsus7tU1j5zz.ipUUC.W03ZYf6ZeBsThfu	41
10	tokenVerifyAccount	TU36u9maCmCcTtpnbNVg	42
10	accountIsActive	0	43
11	localAuthenticationPassword	$2y$10$2sEGDOtfQoDVcIzE7fAWyeZVsW9UD3wKsWE8Fpzp2PS2V6ZOWN3tK	44
11	tokenVerifyAccount	vnqBTJNW1zO.M//iuO9J	45
11	accountIsActive	0	46
5	localAuthenticationPassword	$2y$10$ArirBpUpfDaMz/rEPg9fbuNEsk1nYy6aOdu29qzBU0oEFc7DFc3BS	17
5	tokenVerifyAccount	878CePiHuOzGPC1jYexB	18
5	accountIsActive	0	19
6	localAuthenticationPassword	$2y$10$.dIOCCEIPtLnCW4LRYdGbuzj4cd1HhTKnRa2aa./GHhVQAYK4r8I.	21
6	tokenVerifyAccount	pZoysj.O4dcS5QvLreLw	22
11	deleteAccountToken	6fc2ff9e1ab46f64abea8ceb951ae9b40b479ca6	47
12	localAuthenticationPassword	$2y$10$AGOFh44xNwhYtbxnQC4HJ.Wq62Z3EnWGtjdcxpwy7n8CP5Ir9AyAu	48
12	tokenVerifyAccount	xq76VLu4PKYG6HLt.Mk3	49
12	accountIsActive	0	50
12	deleteAccountToken	0df152e6f00e9ddeab887a9c773784fcb0d52aef	51
14	deleteAccountToken	2bc1d1a0c677db46fb10bb64d70c2202c134c90a	59
4	deleteAccountToken	32ff7fb906d9d235adecaf1476f66f1f427cda5d	16
1	loginAttemp	0	3
19	accountIsActive	0	81
6	accountIsActive	1	23
19	deleteAccountToken	9d3818feaccb067a0bf185985bde66ba7768daaa	82
7	localAuthenticationPassword	$2y$10$3uVfQj436cNx0NmwUg6fiuGfB29xPwRNv1nN1Kt70QIl3Ukdqe.la	26
7	tokenVerifyAccount	mF/Ck9UCyECq./rRu4Ee	27
7	accountIsActive	0	28
20	deleteAccountToken	b7534d5f1e22b69489d4ecb1d78d6ba9456639bc	87
15	loginAttemp	0	63
8	localAuthenticationPassword	$2y$10$AVHfxnjehX4LBxywNDMX2.5Wj5..3mVvbyZU/K4vWs92Ce8ZOgLjm	31
8	tokenVerifyAccount	DayzGie5PKUcOM7hC75m	32
8	accountIsActive	0	33
22	localAuthenticationPassword	$2y$10$ozUO9wjqrVt28GsbQxLkzujhRU1isnuuJM7FCw7OF5UpmiZgc7p1S	93
15	localAuthenticationPassword	$2y$10$3Mv90eDEcWpIv3uR3m9MqetmvfOHNS6Q.pQPAlGy4wUrzkQsC/5UC	60
15	tokenVerifyAccount	75sfIBnO3.ivXhkiy/g3	61
8	loginAttemp	0	34
8	deleteAccountToken	737e045b227567444b36b20d3dc7e354d05b4679	35
15	accountIsActive	0	62
16	localAuthenticationPassword	$2y$10$7WEuuyyhL9xPt0.KEgVwEOMnzmROhC3GvNOmxJO3tG3OV9qq7GOqC	65
16	tokenVerifyAccount	Oh.VIepbHitiiR6MFde/	66
16	accountIsActive	0	67
9	localAuthenticationPassword	$2y$10$UH/QC2h36gy2YFpU551ezuMD.DQfk2vQpgTdX02H4YmBrfQ5PQ1W6	36
9	tokenVerifyAccount	6lyOr1ypOqHh1eua.VI0	37
9	accountIsActive	0	38
16	deleteAccountToken	19219335fedf4460b695a9e5affc46bf0540506e	68
17	localAuthenticationPassword	$2y$10$OQ07pw8tIsqkokKFteD7SeexWhiH3zgAIl9QLfTjOwtOWhKC.BrzC	69
17	tokenVerifyAccount	n2uMUkJmmPICNdgQnqRQ	70
20	accountIsActive	0	85
15	deleteAccountToken	54ffd21c13df8e8cd6ae49ca11195960ea44ff8c	64
19	localAuthenticationPassword	$2y$10$PEvdzi7D90vxSUURGfncUevHVC4wDacHw5/hmhqVINXNT2mP1ribO	79
19	tokenVerifyAccount	AKxNyu35rhM7raaKdED1	80
20	loginAttemp	0	86
17	accountIsActive	0	71
17	loginAttemp	0	72
6	deleteAccountToken	11cb85b7d2e2403aa0c1ae29c38620e6b6f4b3d1	25
21	localAuthenticationPassword	$2y$10$tRqWwnHPT4O8MEo7m5TpBeLJqz4opDSQYemrGt5UBWEUcoCxL9Y3m	88
6	loginAttemp	0	24
21	tokenVerifyAccount	O2X8oMiHeHlGELzql5bS	89
21	accountIsActive	0	90
21	loginAttemp	0	91
21	deleteAccountToken	5a78d62613f20c11211b38b1da94ba83d11cb89b	92
3	loginAttemp	0	10
3	deleteAccountToken	2915b801fdc86531225aed033ff52acb52edec2c	11
7	deleteAccountToken	ef0f65dbfebfdd81c314f0e9d570bc66b637f9dd	30
1	deleteAccountToken	088dbf282e906b19a4a6a60750fef74d918a985f	4
22	tokenVerifyAccount	zyJ.BDjPX84Hw26RuDKw	94
22	accountIsActive	0	95
22	loginAttemp	0	96
23	localAuthenticationPassword	$2y$10$CyAtNsKFAf9GBSqPuIXCxuU3gShMukMmAzlSES4178kLvofHCgrkm	98
23	tokenVerifyAccount	tP47FpgLC7t4QbCwMQ.k	99
23	accountIsActive	0	100
23	loginAttemp	0	101
5	deleteAccountToken	0a3bbad8a236207200ecdcbacb73dd9d98c98d1b	20
22	deleteAccountToken	9907b0916dcc8e794b9ce5babebd6842f5055202	97
23	deleteAccountToken	7df9c93c98ce009f12614f3efe234582d665227c	102
\.


--
-- Name: user_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.user_meta_id_seq', 102, true);


--
-- Data for Name: usr; Type: TABLE DATA; Schema: public; Owner: mapas
--

COPY public.usr (id, auth_provider, auth_uid, email, last_login_timestamp, create_timestamp, status, profile_id) FROM stdin;
4	0	valdo.mesquita@gmail.com	valdo.mesquita@gmail.com	2021-03-27 00:24:08	2021-03-22 19:15:39	1	5
1	0	benrainir@gmai.com	benrainir@gmail.com	2021-03-27 00:27:11	2021-03-20 00:00:00	1	1
10	0	jose.texte@gmail.com	jose.texte@gmail.com	2021-03-24 09:32:31	2021-03-24 09:32:31	1	11
11	0	joao.texxte@gmail.com	joao.texxte@gmail.com	2021-03-24 09:40:51	2021-03-24 09:40:09	1	12
12	0	maria.texxte@gmail.com	maria.texxte@gmail.com	2021-03-24 09:58:23	2021-03-24 09:57:53	1	13
21	0	nairton@gmail.com	nairton@gmail.com	2021-03-25 11:47:41	2021-03-25 11:41:53	1	22
13	0	jose.texxte@gmail.com	jose.texxte@gmail.com	2021-03-24 19:43:44	2021-03-24 19:32:10	1	14
14	0	maria.texxxte@gmail.com	maria.texxxte@gmail.com	2021-03-24 19:51:32	2021-03-24 19:51:17	1	15
8	0	valescad192@gmail.com	valescad192@gmail.com	2021-03-23 16:29:03	2021-03-23 16:08:02	1	9
16	0	mario.texxte@gmail.com	mario.texxte@gmail.com	2021-03-25 10:06:36	2021-03-25 10:06:25	1	17
9	0	bruno@gmail.com	bruno@gmail.com	2021-03-24 01:47:31	2021-03-24 01:46:12	1	10
17	0	antoniarodrigues160646@gmail.com	antoniarodrigues160646@gmail.com	2021-03-25 10:09:22	2021-03-25 10:09:04	1	18
18	0	anaclarabecco@hotmail.com	anaclarabecco@hotmail.com	2021-03-25 10:18:42	2021-03-25 10:18:26	1	19
15	0	fabricio.fidalgo@hotmail.com	fabricio.fidalgo@hotmail.com	2021-03-25 10:21:36	2021-03-25 09:59:26	1	16
19	0	borges.mesquita@gmail.com	borges.mesquita@gmail.com	2021-03-25 10:29:23	2021-03-25 10:27:39	1	20
5	0	luiz.carlos@setur.ce.gov.br	luiz.carlos@setur.ce.gov.br	2021-03-26 10:37:14	2021-03-23 09:10:26	1	6
6	0	fabricio.fidalgo@setur.ce.gov.br	fabricio.fidalgo@setur.ce.gov.br	2021-03-26 10:45:43	2021-03-23 09:27:18	1	7
22	0	carlos.texxte@gmail.com	carlos.texxte@gmail.com	2021-03-26 10:59:14	2021-03-26 09:09:42	1	23
20	0	alicebecco@hotmail.com	alicebecco@hotmail.com	2021-03-26 11:03:09	2021-03-25 10:51:35	1	21
23	0	silvio.texxte@gmail.com	silvio.texxte@gmail.com	2021-03-26 11:30:07	2021-03-26 10:07:10	1	24
3	0	valescadant@gmail.com	valescadant@gmail.com	2021-03-26 16:37:18	2021-03-22 14:32:57	1	3
7	0	marques.junior@setur.ce.gov.br	marques.junior@setur.ce.gov.br	2021-03-26 19:50:11	2021-03-23 14:41:48	1	8
\.


--
-- Name: usr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mapas
--

SELECT pg_catalog.setval('public.usr_id_seq', 23, true);


--
-- Name: _mesoregiao _mesoregiao_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._mesoregiao
    ADD CONSTRAINT _mesoregiao_pkey PRIMARY KEY (gid);


--
-- Name: _microregiao _microregiao_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._microregiao
    ADD CONSTRAINT _microregiao_pkey PRIMARY KEY (gid);


--
-- Name: _municipios _municipios_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public._municipios
    ADD CONSTRAINT _municipios_pkey PRIMARY KEY (gid);


--
-- Name: agent_meta agent_meta_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent_meta
    ADD CONSTRAINT agent_meta_pk PRIMARY KEY (id);


--
-- Name: agent agent_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent
    ADD CONSTRAINT agent_pk PRIMARY KEY (id);


--
-- Name: agent_relation agent_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent_relation
    ADD CONSTRAINT agent_relation_pkey PRIMARY KEY (id);


--
-- Name: db_update db_update_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.db_update
    ADD CONSTRAINT db_update_pk PRIMARY KEY (name);


--
-- Name: entity_revision_data entity_revision_data_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision_data
    ADD CONSTRAINT entity_revision_data_pkey PRIMARY KEY (id);


--
-- Name: entity_revision entity_revision_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision
    ADD CONSTRAINT entity_revision_pkey PRIMARY KEY (id);


--
-- Name: entity_revision_revision_data entity_revision_revision_data_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision_revision_data
    ADD CONSTRAINT entity_revision_revision_data_pkey PRIMARY KEY (revision_id, revision_data_id);


--
-- Name: evaluation_method_configuration evaluation_method_configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.evaluation_method_configuration
    ADD CONSTRAINT evaluation_method_configuration_pkey PRIMARY KEY (id);


--
-- Name: evaluationmethodconfiguration_meta evaluationmethodconfiguration_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.evaluationmethodconfiguration_meta
    ADD CONSTRAINT evaluationmethodconfiguration_meta_pkey PRIMARY KEY (id);


--
-- Name: event_attendance event_attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_attendance
    ADD CONSTRAINT event_attendance_pkey PRIMARY KEY (id);


--
-- Name: event_meta event_meta_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_meta
    ADD CONSTRAINT event_meta_pk PRIMARY KEY (id);


--
-- Name: event_occurrence_cancellation event_occurrence_cancellation_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_cancellation
    ADD CONSTRAINT event_occurrence_cancellation_pkey PRIMARY KEY (id);


--
-- Name: event_occurrence event_occurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence
    ADD CONSTRAINT event_occurrence_pkey PRIMARY KEY (id);


--
-- Name: event_occurrence_recurrence event_occurrence_recurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_recurrence
    ADD CONSTRAINT event_occurrence_recurrence_pkey PRIMARY KEY (id);


--
-- Name: event event_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_pk PRIMARY KEY (id);


--
-- Name: file file_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.file
    ADD CONSTRAINT file_pk PRIMARY KEY (id);


--
-- Name: geo_division geo_divisions_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.geo_division
    ADD CONSTRAINT geo_divisions_pkey PRIMARY KEY (id);


--
-- Name: metadata metadata_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.metadata
    ADD CONSTRAINT metadata_pk PRIMARY KEY (object_id, object_type, key);


--
-- Name: metalist metalist_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.metalist
    ADD CONSTRAINT metalist_pk PRIMARY KEY (id);


--
-- Name: notification_meta notification_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.notification_meta
    ADD CONSTRAINT notification_meta_pkey PRIMARY KEY (id);


--
-- Name: notification notification_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_pk PRIMARY KEY (id);


--
-- Name: opportunity_meta opportunity_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.opportunity_meta
    ADD CONSTRAINT opportunity_meta_pkey PRIMARY KEY (id);


--
-- Name: opportunity opportunity_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.opportunity
    ADD CONSTRAINT opportunity_pkey PRIMARY KEY (id);


--
-- Name: pcache pcache_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.pcache
    ADD CONSTRAINT pcache_pkey PRIMARY KEY (id);


--
-- Name: permission_cache_pending permission_cache_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.permission_cache_pending
    ADD CONSTRAINT permission_cache_pending_pkey PRIMARY KEY (id);


--
-- Name: procuration procuration_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.procuration
    ADD CONSTRAINT procuration_pkey PRIMARY KEY (token);


--
-- Name: project_event project_event_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project_event
    ADD CONSTRAINT project_event_pk PRIMARY KEY (id);


--
-- Name: project_meta project_meta_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project_meta
    ADD CONSTRAINT project_meta_pk PRIMARY KEY (id);


--
-- Name: project project_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_pk PRIMARY KEY (id);


--
-- Name: registration_evaluation registration_evaluation_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_evaluation
    ADD CONSTRAINT registration_evaluation_pkey PRIMARY KEY (id);


--
-- Name: registration_field_configuration registration_field_configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_field_configuration
    ADD CONSTRAINT registration_field_configuration_pkey PRIMARY KEY (id);


--
-- Name: registration_file_configuration registration_file_configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_file_configuration
    ADD CONSTRAINT registration_file_configuration_pkey PRIMARY KEY (id);


--
-- Name: registration_meta registration_meta_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_meta
    ADD CONSTRAINT registration_meta_pk PRIMARY KEY (id);


--
-- Name: registration registration_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration
    ADD CONSTRAINT registration_pkey PRIMARY KEY (id);


--
-- Name: request request_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.request
    ADD CONSTRAINT request_pk PRIMARY KEY (id);


--
-- Name: role role_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pk PRIMARY KEY (id);


--
-- Name: subsite saas_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.subsite
    ADD CONSTRAINT saas_pkey PRIMARY KEY (id);


--
-- Name: seal_meta seal_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_meta
    ADD CONSTRAINT seal_meta_pkey PRIMARY KEY (id);


--
-- Name: seal seal_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal
    ADD CONSTRAINT seal_pkey PRIMARY KEY (id);


--
-- Name: seal_relation seal_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_relation
    ADD CONSTRAINT seal_relation_pkey PRIMARY KEY (id);


--
-- Name: space_meta space_meta_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space_meta
    ADD CONSTRAINT space_meta_pk PRIMARY KEY (id);


--
-- Name: space space_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space
    ADD CONSTRAINT space_pk PRIMARY KEY (id);


--
-- Name: space_relation space_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space_relation
    ADD CONSTRAINT space_relation_pkey PRIMARY KEY (id);


--
-- Name: subsite_meta subsite_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.subsite_meta
    ADD CONSTRAINT subsite_meta_pkey PRIMARY KEY (id);


--
-- Name: term term_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.term
    ADD CONSTRAINT term_pk PRIMARY KEY (id);


--
-- Name: term_relation term_relation_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.term_relation
    ADD CONSTRAINT term_relation_pk PRIMARY KEY (id);


--
-- Name: user_app user_app_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.user_app
    ADD CONSTRAINT user_app_pk PRIMARY KEY (public_key);


--
-- Name: user_meta user_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.user_meta
    ADD CONSTRAINT user_meta_pkey PRIMARY KEY (id);


--
-- Name: usr usr_pk; Type: CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.usr
    ADD CONSTRAINT usr_pk PRIMARY KEY (id);


--
-- Name: agent_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX agent_meta_key_idx ON public.agent_meta USING btree (key);


--
-- Name: agent_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX agent_meta_owner_idx ON public.agent_meta USING btree (object_id);


--
-- Name: agent_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX agent_meta_owner_key_idx ON public.agent_meta USING btree (object_id, key);


--
-- Name: agent_relation_all; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX agent_relation_all ON public.agent_relation USING btree (agent_id, object_type, object_id);


--
-- Name: alias_url_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX alias_url_index ON public.subsite USING btree (alias_url);


--
-- Name: evaluationmethodconfiguration_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX evaluationmethodconfiguration_meta_owner_idx ON public.evaluationmethodconfiguration_meta USING btree (object_id);


--
-- Name: evaluationmethodconfiguration_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX evaluationmethodconfiguration_meta_owner_key_idx ON public.evaluationmethodconfiguration_meta USING btree (object_id, key);


--
-- Name: event_attendance_type_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX event_attendance_type_idx ON public.event_attendance USING btree (type);


--
-- Name: event_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX event_meta_key_idx ON public.event_meta USING btree (key);


--
-- Name: event_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX event_meta_owner_idx ON public.event_meta USING btree (object_id);


--
-- Name: event_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX event_meta_owner_key_idx ON public.event_meta USING btree (object_id, key);


--
-- Name: event_occurrence_status_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX event_occurrence_status_index ON public.event_occurrence USING btree (status);


--
-- Name: file_group_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX file_group_index ON public.file USING btree (grp);


--
-- Name: file_owner_grp_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX file_owner_grp_index ON public.file USING btree (object_type, object_id, grp);


--
-- Name: file_owner_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX file_owner_index ON public.file USING btree (object_type, object_id);


--
-- Name: geo_divisions_geom_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX geo_divisions_geom_idx ON public.geo_division USING gist (geom);


--
-- Name: idx_1a0e9a30232d562b; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_1a0e9a30232d562b ON public.space_relation USING btree (object_id);


--
-- Name: idx_1a0e9a3023575340; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_1a0e9a3023575340 ON public.space_relation USING btree (space_id);


--
-- Name: idx_209c792e9a34590f; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_209c792e9a34590f ON public.registration_file_configuration USING btree (opportunity_id);


--
-- Name: idx_22781144c79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_22781144c79c849a ON public.user_app USING btree (subsite_id);


--
-- Name: idx_268b9c9dc79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_268b9c9dc79c849a ON public.agent USING btree (subsite_id);


--
-- Name: idx_2972c13ac79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_2972c13ac79c849a ON public.space USING btree (subsite_id);


--
-- Name: idx_2e186c5c833d8f43; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_2e186c5c833d8f43 ON public.registration_evaluation USING btree (registration_id);


--
-- Name: idx_2e186c5ca76ed395; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_2e186c5ca76ed395 ON public.registration_evaluation USING btree (user_id);


--
-- Name: idx_2e30ae30c79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_2e30ae30c79c849a ON public.seal USING btree (subsite_id);


--
-- Name: idx_2fb3d0eec79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_2fb3d0eec79c849a ON public.project USING btree (subsite_id);


--
-- Name: idx_350dd4be140e9f00; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_350dd4be140e9f00 ON public.event_attendance USING btree (event_occurrence_id);


--
-- Name: idx_350dd4be23575340; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_350dd4be23575340 ON public.event_attendance USING btree (space_id);


--
-- Name: idx_350dd4be71f7e88b; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_350dd4be71f7e88b ON public.event_attendance USING btree (event_id);


--
-- Name: idx_350dd4bea76ed395; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_350dd4bea76ed395 ON public.event_attendance USING btree (user_id);


--
-- Name: idx_3bae0aa7c79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_3bae0aa7c79c849a ON public.event USING btree (subsite_id);


--
-- Name: idx_3d853098232d562b; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_3d853098232d562b ON public.pcache USING btree (object_id);


--
-- Name: idx_3d853098a76ed395; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_3d853098a76ed395 ON public.pcache USING btree (user_id);


--
-- Name: idx_57698a6ac79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_57698a6ac79c849a ON public.role USING btree (subsite_id);


--
-- Name: idx_60c85cb1166d1f9c; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_60c85cb1166d1f9c ON public.registration_field_configuration USING btree (opportunity_id);


--
-- Name: idx_60c85cb19a34590f; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_60c85cb19a34590f ON public.registration_field_configuration USING btree (opportunity_id);


--
-- Name: idx_62a8a7a73414710b; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_62a8a7a73414710b ON public.registration USING btree (agent_id);


--
-- Name: idx_62a8a7a79a34590f; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_62a8a7a79a34590f ON public.registration USING btree (opportunity_id);


--
-- Name: idx_62a8a7a7c79c849a; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX idx_62a8a7a7c79c849a ON public.registration USING btree (subsite_id);


--
-- Name: notification_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX notification_meta_key_idx ON public.notification_meta USING btree (key);


--
-- Name: notification_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX notification_meta_owner_idx ON public.notification_meta USING btree (object_id);


--
-- Name: notification_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX notification_meta_owner_key_idx ON public.notification_meta USING btree (object_id, key);


--
-- Name: opportunity_entity_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX opportunity_entity_idx ON public.opportunity USING btree (object_type, object_id);


--
-- Name: opportunity_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX opportunity_meta_owner_idx ON public.opportunity_meta USING btree (object_id);


--
-- Name: opportunity_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX opportunity_meta_owner_key_idx ON public.opportunity_meta USING btree (object_id, key);


--
-- Name: opportunity_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX opportunity_owner_idx ON public.opportunity USING btree (agent_id);


--
-- Name: opportunity_parent_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX opportunity_parent_idx ON public.opportunity USING btree (parent_id);


--
-- Name: owner_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX owner_index ON public.term_relation USING btree (object_type, object_id);


--
-- Name: pcache_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX pcache_owner_idx ON public.pcache USING btree (object_type, object_id);


--
-- Name: pcache_permission_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX pcache_permission_idx ON public.pcache USING btree (object_type, object_id, action);


--
-- Name: pcache_permission_user_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX pcache_permission_user_idx ON public.pcache USING btree (object_type, object_id, action, user_id);


--
-- Name: procuration_attorney_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX procuration_attorney_idx ON public.procuration USING btree (attorney_user_id);


--
-- Name: procuration_usr_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX procuration_usr_idx ON public.procuration USING btree (usr_id);


--
-- Name: project_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX project_meta_key_idx ON public.project_meta USING btree (key);


--
-- Name: project_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX project_meta_owner_idx ON public.project_meta USING btree (object_id);


--
-- Name: project_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX project_meta_owner_key_idx ON public.project_meta USING btree (object_id, key);


--
-- Name: registration_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX registration_meta_owner_idx ON public.registration_meta USING btree (object_id);


--
-- Name: registration_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX registration_meta_owner_key_idx ON public.registration_meta USING btree (object_id, key);


--
-- Name: request_uid; Type: INDEX; Schema: public; Owner: mapas
--

CREATE UNIQUE INDEX request_uid ON public.request USING btree (request_uid);


--
-- Name: requester_user_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX requester_user_index ON public.request USING btree (requester_user_id, origin_type, origin_id);


--
-- Name: seal_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX seal_meta_key_idx ON public.seal_meta USING btree (key);


--
-- Name: seal_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX seal_meta_owner_idx ON public.seal_meta USING btree (object_id);


--
-- Name: seal_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX seal_meta_owner_key_idx ON public.seal_meta USING btree (object_id, key);


--
-- Name: space_location; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX space_location ON public.space USING gist (_geo_location);


--
-- Name: space_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX space_meta_key_idx ON public.space_meta USING btree (key);


--
-- Name: space_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX space_meta_owner_idx ON public.space_meta USING btree (object_id);


--
-- Name: space_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX space_meta_owner_key_idx ON public.space_meta USING btree (object_id, key);


--
-- Name: space_type; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX space_type ON public.space USING btree (type);


--
-- Name: subsite_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX subsite_meta_key_idx ON public.subsite_meta USING btree (key);


--
-- Name: subsite_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX subsite_meta_owner_idx ON public.subsite_meta USING btree (object_id);


--
-- Name: subsite_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX subsite_meta_owner_key_idx ON public.subsite_meta USING btree (object_id, key);


--
-- Name: taxonomy_term_unique; Type: INDEX; Schema: public; Owner: mapas
--

CREATE UNIQUE INDEX taxonomy_term_unique ON public.term USING btree (taxonomy, term);


--
-- Name: uniq_330cb54c9a34590f; Type: INDEX; Schema: public; Owner: mapas
--

CREATE UNIQUE INDEX uniq_330cb54c9a34590f ON public.evaluation_method_configuration USING btree (opportunity_id);


--
-- Name: url_index; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX url_index ON public.subsite USING btree (url);


--
-- Name: user_meta_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX user_meta_key_idx ON public.user_meta USING btree (key);


--
-- Name: user_meta_owner_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX user_meta_owner_idx ON public.user_meta USING btree (object_id);


--
-- Name: user_meta_owner_key_idx; Type: INDEX; Schema: public; Owner: mapas
--

CREATE INDEX user_meta_owner_key_idx ON public.user_meta USING btree (object_id, key);


--
-- Name: usr fk_1762498cccfa12b8; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.usr
    ADD CONSTRAINT fk_1762498cccfa12b8 FOREIGN KEY (profile_id) REFERENCES public.agent(id) ON DELETE SET NULL;


--
-- Name: registration_meta fk_18cc03e9232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_meta
    ADD CONSTRAINT fk_18cc03e9232d562b FOREIGN KEY (object_id) REFERENCES public.registration(id) ON DELETE CASCADE;


--
-- Name: space_relation fk_1a0e9a30232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space_relation
    ADD CONSTRAINT fk_1a0e9a30232d562b FOREIGN KEY (object_id) REFERENCES public.registration(id) ON DELETE CASCADE;


--
-- Name: space_relation fk_1a0e9a3023575340; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space_relation
    ADD CONSTRAINT fk_1a0e9a3023575340 FOREIGN KEY (space_id) REFERENCES public.space(id) ON DELETE CASCADE;


--
-- Name: registration_file_configuration fk_209c792e9a34590f; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_file_configuration
    ADD CONSTRAINT fk_209c792e9a34590f FOREIGN KEY (opportunity_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: user_app fk_22781144a76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.user_app
    ADD CONSTRAINT fk_22781144a76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: user_app fk_22781144bddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.user_app
    ADD CONSTRAINT fk_22781144bddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE CASCADE;


--
-- Name: agent fk_268b9c9d727aca70; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent
    ADD CONSTRAINT fk_268b9c9d727aca70 FOREIGN KEY (parent_id) REFERENCES public.agent(id) ON DELETE SET NULL;


--
-- Name: agent fk_268b9c9da76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent
    ADD CONSTRAINT fk_268b9c9da76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: agent fk_268b9c9dbddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent
    ADD CONSTRAINT fk_268b9c9dbddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE SET NULL;


--
-- Name: space fk_2972c13a3414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space
    ADD CONSTRAINT fk_2972c13a3414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: space fk_2972c13a727aca70; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space
    ADD CONSTRAINT fk_2972c13a727aca70 FOREIGN KEY (parent_id) REFERENCES public.space(id) ON DELETE CASCADE;


--
-- Name: space fk_2972c13abddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space
    ADD CONSTRAINT fk_2972c13abddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE SET NULL;


--
-- Name: opportunity_meta fk_2bb06d08232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.opportunity_meta
    ADD CONSTRAINT fk_2bb06d08232d562b FOREIGN KEY (object_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: registration_evaluation fk_2e186c5c833d8f43; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_evaluation
    ADD CONSTRAINT fk_2e186c5c833d8f43 FOREIGN KEY (registration_id) REFERENCES public.registration(id) ON DELETE CASCADE;


--
-- Name: registration_evaluation fk_2e186c5ca76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_evaluation
    ADD CONSTRAINT fk_2e186c5ca76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: seal fk_2e30ae303414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal
    ADD CONSTRAINT fk_2e30ae303414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: seal fk_2e30ae30bddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal
    ADD CONSTRAINT fk_2e30ae30bddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE CASCADE;


--
-- Name: project fk_2fb3d0ee3414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT fk_2fb3d0ee3414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: project fk_2fb3d0ee727aca70; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT fk_2fb3d0ee727aca70 FOREIGN KEY (parent_id) REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project fk_2fb3d0eebddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT fk_2fb3d0eebddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE SET NULL;


--
-- Name: evaluation_method_configuration fk_330cb54c9a34590f; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.evaluation_method_configuration
    ADD CONSTRAINT fk_330cb54c9a34590f FOREIGN KEY (opportunity_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: event_attendance fk_350dd4be140e9f00; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_attendance
    ADD CONSTRAINT fk_350dd4be140e9f00 FOREIGN KEY (event_occurrence_id) REFERENCES public.event_occurrence(id) ON DELETE CASCADE;


--
-- Name: event_attendance fk_350dd4be23575340; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_attendance
    ADD CONSTRAINT fk_350dd4be23575340 FOREIGN KEY (space_id) REFERENCES public.space(id) ON DELETE CASCADE;


--
-- Name: event_attendance fk_350dd4be71f7e88b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_attendance
    ADD CONSTRAINT fk_350dd4be71f7e88b FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- Name: event_attendance fk_350dd4bea76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_attendance
    ADD CONSTRAINT fk_350dd4bea76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: event_occurrence_recurrence fk_388eccb140e9f00; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_recurrence
    ADD CONSTRAINT fk_388eccb140e9f00 FOREIGN KEY (event_occurrence_id) REFERENCES public.event_occurrence(id) ON DELETE CASCADE;


--
-- Name: request fk_3b978f9fba78f12a; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.request
    ADD CONSTRAINT fk_3b978f9fba78f12a FOREIGN KEY (requester_user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: event fk_3bae0aa7166d1f9c; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT fk_3bae0aa7166d1f9c FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: event fk_3bae0aa73414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT fk_3bae0aa73414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: event fk_3bae0aa7bddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT fk_3bae0aa7bddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE SET NULL;


--
-- Name: pcache fk_3d853098a76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.pcache
    ADD CONSTRAINT fk_3d853098a76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: seal_relation fk_487af6513414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_relation
    ADD CONSTRAINT fk_487af6513414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: seal_relation fk_487af65154778145; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_relation
    ADD CONSTRAINT fk_487af65154778145 FOREIGN KEY (seal_id) REFERENCES public.seal(id) ON DELETE CASCADE;


--
-- Name: seal_relation fk_487af6517e3c61f9; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_relation
    ADD CONSTRAINT fk_487af6517e3c61f9 FOREIGN KEY (owner_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: agent_relation fk_54585edd3414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent_relation
    ADD CONSTRAINT fk_54585edd3414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: role fk_57698a6abddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT fk_57698a6abddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE CASCADE;


--
-- Name: role fk_57698a6ac69d3fb; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT fk_57698a6ac69d3fb FOREIGN KEY (usr_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: registration_field_configuration fk_60c85cb19a34590f; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration_field_configuration
    ADD CONSTRAINT fk_60c85cb19a34590f FOREIGN KEY (opportunity_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: registration fk_62a8a7a73414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration
    ADD CONSTRAINT fk_62a8a7a73414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: registration fk_62a8a7a79a34590f; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration
    ADD CONSTRAINT fk_62a8a7a79a34590f FOREIGN KEY (opportunity_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: registration fk_62a8a7a7bddfbe89; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.registration
    ADD CONSTRAINT fk_62a8a7a7bddfbe89 FOREIGN KEY (subsite_id) REFERENCES public.subsite(id) ON DELETE SET NULL;


--
-- Name: notification_meta fk_6fce5f0f232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.notification_meta
    ADD CONSTRAINT fk_6fce5f0f232d562b FOREIGN KEY (object_id) REFERENCES public.notification(id) ON DELETE CASCADE;


--
-- Name: subsite_meta fk_780702f5232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.subsite_meta
    ADD CONSTRAINT fk_780702f5232d562b FOREIGN KEY (object_id) REFERENCES public.subsite(id) ON DELETE CASCADE;


--
-- Name: agent_meta fk_7a69aed6232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.agent_meta
    ADD CONSTRAINT fk_7a69aed6232d562b FOREIGN KEY (object_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: opportunity fk_8389c3d73414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.opportunity
    ADD CONSTRAINT fk_8389c3d73414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id) ON DELETE CASCADE;


--
-- Name: opportunity fk_8389c3d7727aca70; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.opportunity
    ADD CONSTRAINT fk_8389c3d7727aca70 FOREIGN KEY (parent_id) REFERENCES public.opportunity(id) ON DELETE CASCADE;


--
-- Name: file fk_8c9f3610727aca70; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.file
    ADD CONSTRAINT fk_8c9f3610727aca70 FOREIGN KEY (parent_id) REFERENCES public.file(id) ON DELETE CASCADE;


--
-- Name: entity_revision_revision_data fk_9977a8521dfa7c8f; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision_revision_data
    ADD CONSTRAINT fk_9977a8521dfa7c8f FOREIGN KEY (revision_id) REFERENCES public.entity_revision(id) ON DELETE CASCADE;


--
-- Name: entity_revision_revision_data fk_9977a852b4906f58; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision_revision_data
    ADD CONSTRAINT fk_9977a852b4906f58 FOREIGN KEY (revision_data_id) REFERENCES public.entity_revision_data(id) ON DELETE CASCADE;


--
-- Name: event_occurrence_cancellation fk_a5506736140e9f00; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence_cancellation
    ADD CONSTRAINT fk_a5506736140e9f00 FOREIGN KEY (event_occurrence_id) REFERENCES public.event_occurrence(id) ON DELETE CASCADE;


--
-- Name: seal_meta fk_a92e5e22232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.seal_meta
    ADD CONSTRAINT fk_a92e5e22232d562b FOREIGN KEY (object_id) REFERENCES public.seal(id) ON DELETE CASCADE;


--
-- Name: user_meta fk_ad7358fc232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.user_meta
    ADD CONSTRAINT fk_ad7358fc232d562b FOREIGN KEY (object_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: subsite fk_b0f67b6f3414710b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.subsite
    ADD CONSTRAINT fk_b0f67b6f3414710b FOREIGN KEY (agent_id) REFERENCES public.agent(id);


--
-- Name: space_meta fk_bc846ebf232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.space_meta
    ADD CONSTRAINT fk_bc846ebf232d562b FOREIGN KEY (object_id) REFERENCES public.space(id) ON DELETE CASCADE;


--
-- Name: notification fk_bf5476ca427eb8a5; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fk_bf5476ca427eb8a5 FOREIGN KEY (request_id) REFERENCES public.request(id) ON DELETE CASCADE;


--
-- Name: notification fk_bf5476caa76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fk_bf5476caa76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: event_meta fk_c839589e232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_meta
    ADD CONSTRAINT fk_c839589e232d562b FOREIGN KEY (object_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- Name: entity_revision fk_cf97a98ca76ed395; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.entity_revision
    ADD CONSTRAINT fk_cf97a98ca76ed395 FOREIGN KEY (user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: procuration fk_d7bae7f3aeb2ed7; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.procuration
    ADD CONSTRAINT fk_d7bae7f3aeb2ed7 FOREIGN KEY (attorney_user_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: procuration fk_d7bae7fc69d3fb; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.procuration
    ADD CONSTRAINT fk_d7bae7fc69d3fb FOREIGN KEY (usr_id) REFERENCES public.usr(id) ON DELETE CASCADE;


--
-- Name: evaluationmethodconfiguration_meta fk_d7edf8b2232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.evaluationmethodconfiguration_meta
    ADD CONSTRAINT fk_d7edf8b2232d562b FOREIGN KEY (object_id) REFERENCES public.evaluation_method_configuration(id) ON DELETE CASCADE;


--
-- Name: event_occurrence fk_e61358dc23575340; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence
    ADD CONSTRAINT fk_e61358dc23575340 FOREIGN KEY (space_id) REFERENCES public.space(id) ON DELETE CASCADE;


--
-- Name: event_occurrence fk_e61358dc71f7e88b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.event_occurrence
    ADD CONSTRAINT fk_e61358dc71f7e88b FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE;


--
-- Name: term_relation fk_eddf39fde2c35fc; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.term_relation
    ADD CONSTRAINT fk_eddf39fde2c35fc FOREIGN KEY (term_id) REFERENCES public.term(id) ON DELETE CASCADE;


--
-- Name: project_meta fk_ee63dc2d232d562b; Type: FK CONSTRAINT; Schema: public; Owner: mapas
--

ALTER TABLE ONLY public.project_meta
    ADD CONSTRAINT fk_ee63dc2d232d562b FOREIGN KEY (object_id) REFERENCES public.project(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

