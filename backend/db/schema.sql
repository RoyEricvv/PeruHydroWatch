-- Perú HydroWatch 3D: modelo de datos (PostgreSQL 16 + PostGIS 3).
-- Principios que el esquema hace cumplir, no solo documenta:
--   1. Todo dato remite a una fuente y a una ingesta (procedencia).
--   2. Observación, modelo, aviso e inventario son clases distintas y obligatorias.
--   3. Los pronósticos conservan cada emisión: nunca se sobrescriben.
--   4. Exposición potencial, daño esperado y afectación confirmada son estados distintos.
--   5. Un valor demostrativo no puede publicarse: la vista pública lo excluye.

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE data_class AS ENUM ('observacion', 'modelo', 'aviso', 'amenaza', 'susceptibilidad', 'exposicion', 'riesgo', 'inventario', 'referencia');
CREATE TYPE verification AS ENUM ('oficial', 'periodistico_verificado', 'periodistico', 'no_verificado');
CREATE TYPE exposure_state AS ENUM ('exposicion_potencial', 'dano_esperado', 'afectacion_confirmada');
CREATE TYPE admin_level AS ENUM ('departamento', 'provincia', 'distrito');
CREATE TYPE integration_state AS ENUM ('integrada', 'parcial', 'pendiente', 'restringida');

-- ------------------------------------------------------------------ Procedencia
CREATE TABLE source (
  id              text PRIMARY KEY,
  institution     text NOT NULL,
  name            text NOT NULL,
  url             text NOT NULL,
  coverage        text,
  resolution      text,
  frequency       text,
  formats         text,
  license         text NOT NULL,
  quality_notes   text,
  state           integration_state NOT NULL,
  verified_at     date,
  verified_note   text
);

CREATE TABLE ingest_run (
  id            bigserial PRIMARY KEY,
  source_id     text NOT NULL REFERENCES source(id),
  started_at    timestamptz NOT NULL DEFAULT now(),
  finished_at   timestamptz,
  status        text NOT NULL CHECK (status IN ('en_curso', 'ok', 'parcial', 'error')),
  source_url    text NOT NULL,
  checksum      text,
  rows_written  integer,
  error         text
);
CREATE INDEX ON ingest_run (source_id, started_at DESC);

-- ------------------------------------------------------------------ Territorio
CREATE TABLE admin_unit (
  id          text PRIMARY KEY,               -- p-code COD-AB (PE2001...)
  level       admin_level NOT NULL,
  name        text NOT NULL,
  parent_id   text REFERENCES admin_unit(id),
  geom        geometry(MultiPolygon, 4326) NOT NULL,
  source_id   text NOT NULL REFERENCES source(id),
  CHECK ((level = 'departamento') = (parent_id IS NULL))
);
CREATE INDEX ON admin_unit USING gist (geom);
CREATE INDEX ON admin_unit (level);

CREATE TABLE hydro_unit (
  id        text PRIMARY KEY,                 -- Código Pfafstetter de ANA
  name      text NOT NULL,
  level     smallint,
  area_km2  numeric,
  geom      geometry(MultiPolygon, 4326) NOT NULL,
  source_id text NOT NULL REFERENCES source(id)
);
CREATE INDEX ON hydro_unit USING gist (geom);

CREATE TABLE watercourse (
  id            text PRIMARY KEY,
  name          text,
  kind          text NOT NULL CHECK (kind IN ('rio', 'quebrada')),
  hydro_unit_id text REFERENCES hydro_unit(id),
  length_km     numeric,
  geom          geometry(MultiLineString, 4326) NOT NULL,
  source_id     text NOT NULL REFERENCES source(id)
);
CREATE INDEX ON watercourse USING gist (geom);

-- ------------------------------------------------------------------ Estaciones y series
CREATE TABLE station (
  id          text PRIMARY KEY,
  source_id   text NOT NULL REFERENCES source(id),
  name        text NOT NULL,
  kind        text NOT NULL,                  -- hidrologica, meteorologica, hidrometeorologica
  watercourse_id text REFERENCES watercourse(id),
  elevation_m numeric,
  active      boolean,
  geom        geometry(Point, 4326) NOT NULL
);
CREATE INDEX ON station USING gist (geom);

-- Umbrales: solo oficiales y con su documento de origen. Sin esto no hay "nivel de alerta".
CREATE TABLE official_threshold (
  station_id    text NOT NULL REFERENCES station(id),
  variable      text NOT NULL,
  label         text NOT NULL,
  value         numeric NOT NULL,
  unit          text NOT NULL,
  source_id     text NOT NULL REFERENCES source(id),
  document_url  text NOT NULL,
  valid_from    date,
  PRIMARY KEY (station_id, variable, label)
);

CREATE TABLE observation (
  station_id   text NOT NULL REFERENCES station(id),
  variable     text NOT NULL,                 -- precipitacion, nivel, caudal
  observed_at  timestamptz NOT NULL,
  value        numeric NOT NULL,
  unit         text NOT NULL,
  qc_flag      text,
  ingest_id    bigint NOT NULL REFERENCES ingest_run(id),
  retrieved_at timestamptz NOT NULL DEFAULT now(),
  is_demo      boolean NOT NULL DEFAULT false,
  PRIMARY KEY (station_id, variable, observed_at)
);

-- ------------------------------------------------------------------ Pronósticos versionados
CREATE TABLE forecast_run (
  id            bigserial PRIMARY KEY,
  model         text NOT NULL,                -- ecmwf_ifs025, glofas_v4, ...
  source_id     text NOT NULL REFERENCES source(id),
  issued_at     timestamptz NOT NULL,         -- emisión del modelo, no de nuestra descarga
  retrieved_at  timestamptz NOT NULL DEFAULT now(),
  max_lead_h    integer NOT NULL CHECK (max_lead_h > 0),
  horizon       text NOT NULL CHECK (horizon IN ('muy_corto', 'h24_72', 'd7_15', 'subestacional', 'estacional', 'escenario')),
  ingest_id     bigint NOT NULL REFERENCES ingest_run(id),
  UNIQUE (model, issued_at)
);

CREATE TABLE forecast_point (
  run_id     bigint NOT NULL REFERENCES forecast_run(id) ON DELETE CASCADE,
  geom       geometry(Point, 4326) NOT NULL,
  variable   text NOT NULL,
  valid_at   timestamptz NOT NULL,
  lead_h     integer NOT NULL CHECK (lead_h >= 0),
  value      numeric,
  p10        numeric,
  p50        numeric,
  p90        numeric,
  unit       text NOT NULL,
  member_n   smallint
);
CREATE INDEX ON forecast_point USING gist (geom);
CREATE INDEX ON forecast_point (run_id, variable, valid_at);

-- El horizonte máximo lo impone la base: un pronóstico no puede pasar de la validez de su corrida.
CREATE FUNCTION forecast_point_guard() RETURNS trigger AS $$
DECLARE r forecast_run;
BEGIN
  SELECT * INTO r FROM forecast_run WHERE id = NEW.run_id;
  IF NEW.lead_h > r.max_lead_h THEN
    RAISE EXCEPTION 'lead_h % excede el horizonte válido % de la corrida %', NEW.lead_h, r.max_lead_h, NEW.run_id;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER forecast_point_guard BEFORE INSERT OR UPDATE ON forecast_point
  FOR EACH ROW EXECUTE FUNCTION forecast_point_guard();

-- Verificación continua: se compara cada corrida con lo observado después.
CREATE TABLE forecast_score (
  run_id      bigint NOT NULL REFERENCES forecast_run(id) ON DELETE CASCADE,
  station_id  text NOT NULL REFERENCES station(id),
  variable    text NOT NULL,
  lead_h      integer NOT NULL,
  metric      text NOT NULL,                  -- bias, mae, crps, csi...
  value       numeric NOT NULL,
  n           integer NOT NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (run_id, station_id, variable, lead_h, metric)
);

-- ------------------------------------------------------------------ Avisos oficiales
CREATE TABLE official_notice (
  id          bigserial PRIMARY KEY,
  source_id   text NOT NULL REFERENCES source(id),
  kind        text NOT NULL,                  -- meteorologico, quebradas, hidrologico, enfen
  number      text,
  title       text NOT NULL,
  level_label text,                           -- tal como lo publica la institución
  state_label text,
  issued_at   timestamptz,
  valid_from  timestamptz,
  valid_to    timestamptz,
  url         text NOT NULL,
  body        text,
  ingest_id   bigint NOT NULL REFERENCES ingest_run(id),
  UNIQUE (source_id, kind, number, issued_at)
);

CREATE TABLE notice_area (
  id          bigserial PRIMARY KEY,
  notice_id   bigint NOT NULL REFERENCES official_notice(id) ON DELETE CASCADE,
  level_label text,
  recommendation text,
  geom        geometry(MultiPolygon, 4326) NOT NULL
);
CREATE INDEX ON notice_area USING gist (geom);

-- ------------------------------------------------------------------ Inventario y capas evaluadas
CREATE TABLE hazard_event (
  id           text PRIMARY KEY,
  source_id    text NOT NULL REFERENCES source(id),
  type_label   text NOT NULL,                 -- dominio oficial decodificado
  subtype_label text,
  name         text,
  sector       text,
  hydro_code   text,
  recorded_on  date,                          -- fecha del registro; puede no ser la del evento
  site_factors text,
  study        text,
  admin_id     text REFERENCES admin_unit(id),
  geom         geometry(Point, 4326) NOT NULL
);
CREATE INDEX ON hazard_event USING gist (geom);

-- Mapas de amenaza, susceptibilidad, exposición o riesgo: la clase no admite ambigüedad.
CREATE TABLE assessed_layer (
  id          text PRIMARY KEY,
  class       data_class NOT NULL CHECK (class IN ('amenaza', 'susceptibilidad', 'exposicion', 'riesgo')),
  title       text NOT NULL,
  source_id   text NOT NULL REFERENCES source(id),
  method_url  text NOT NULL,                  -- criterio técnico verificable
  valid_from  date,
  valid_to    date
);

-- ------------------------------------------------------------------ Exposición
CREATE TABLE exposed_asset (
  id        text PRIMARY KEY,
  kind      text NOT NULL,                    -- carretera, puente, hospital, colegio, agua, agricola
  name      text,
  source_id text NOT NULL REFERENCES source(id),
  geom      geometry(Geometry, 4326) NOT NULL
);
CREATE INDEX ON exposed_asset USING gist (geom);

CREATE TABLE asset_exposure (
  asset_id    text NOT NULL REFERENCES exposed_asset(id),
  state       exposure_state NOT NULL,
  layer_id    text REFERENCES assessed_layer(id),
  notice_id   bigint REFERENCES official_notice(id),
  simulation_id bigint,
  evidence_url text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  -- Una afectación confirmada exige evidencia enlazable.
  CHECK (state <> 'afectacion_confirmada' OR evidence_url IS NOT NULL),
  CHECK (num_nonnulls(layer_id, notice_id, simulation_id) >= 1 OR state = 'afectacion_confirmada')
);
CREATE INDEX ON asset_exposure (asset_id);

-- ------------------------------------------------------------------ Simulaciones
CREATE TABLE simulation (
  id            bigserial PRIMARY KEY,
  engine        text NOT NULL CHECK (engine IN ('HEC-HMS', 'HEC-RAS-2D')),
  hydro_unit_id text NOT NULL REFERENCES hydro_unit(id),
  scenario      text NOT NULL,
  dem_source    text NOT NULL,
  validated     boolean NOT NULL DEFAULT false,
  validation_url text,
  run_at        timestamptz NOT NULL DEFAULT now(),
  depth_cog_url text,                         -- COG en almacenamiento de objetos
  CHECK (NOT validated OR validation_url IS NOT NULL)
);
ALTER TABLE asset_exposure ADD FOREIGN KEY (simulation_id) REFERENCES simulation(id);

-- ------------------------------------------------------------------ Noticias
CREATE TABLE news_item (
  id           bigserial PRIMARY KEY,
  source_name  text NOT NULL,
  title        text NOT NULL,
  url          text NOT NULL UNIQUE,
  published_at timestamptz NOT NULL,
  retrieved_at timestamptz NOT NULL DEFAULT now(),
  phenomenon   text,
  summary_ai   text,                          -- siempre etiquetado en la interfaz como generado por IA
  verification verification NOT NULL DEFAULT 'no_verificado',
  geom         geometry(Geometry, 4326)
);
CREATE INDEX ON news_item USING gist (geom);

-- ------------------------------------------------------------------ RAG
CREATE TABLE document (
  id         bigserial PRIMARY KEY,
  source_id  text NOT NULL REFERENCES source(id),
  title      text NOT NULL,
  url        text NOT NULL UNIQUE,
  published_on date,
  retrieved_at timestamptz NOT NULL DEFAULT now()
);
-- Los embeddings (pgvector) se añaden en la Etapa 5.

-- ------------------------------------------------------------------ Vistas públicas
-- La API lee de aquí: lo marcado como demostración nunca llega a un usuario como observación.
CREATE VIEW public_observation AS
  SELECT o.*, s.source_id FROM observation o JOIN station s ON s.id = o.station_id WHERE NOT o.is_demo;

-- Solo la emisión más reciente de cada modelo; las anteriores siguen en forecast_run para evaluar.
CREATE VIEW latest_forecast_run AS
  SELECT DISTINCT ON (model) * FROM forecast_run ORDER BY model, issued_at DESC;

-- Ejemplo de consulta espacial controlada: carreteras en polígonos de un aviso.
-- SELECT a.id, a.name FROM exposed_asset a JOIN notice_area n ON ST_Intersects(a.geom, n.geom)
--  WHERE a.kind = 'carretera' AND n.notice_id = $1;
