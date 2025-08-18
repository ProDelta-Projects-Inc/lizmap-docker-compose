-- UP
CREATE TABLE lizmap.observations (
    id INTEGER PRIMARY KEY,
    portfolio_name TEXT,
    project_name TEXT,
    site_name TEXT,
    owner_organization TEXT,
    service_organization TEXT,
    data_source TEXT,
    date DATE,
    deficiencies TEXT,
    description TEXT,
    symbol_code TEXT,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    geom GEOMETRY(Point, 3857)
);

-- Add spatial index
CREATE INDEX observations_geom_idx ON lizmap.observations USING GIST (geom);

-- Add index on symbol_code
CREATE INDEX idx_observations_symbol_code ON lizmap.observations(symbol_code);

-- Example: populate geom from lat/lon (transforming to EPSG:3857)
-- If importing CSV via COPY or ogr2ogr, you can run this afterwards:
-- UPDATE lizmap.observations
-- SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3857);

-- DOWN
DROP TABLE IF EXISTS lizmap.observations CASCADE;
