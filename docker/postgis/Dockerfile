FROM 3liz/postgis:17-3

COPY 001_init-lizmap-db.sh /docker-entrypoint-initdb.d/001_init-lizmap-db.sh
COPY 002_init-schema-migrations.sh /docker-entrypoint-initdb.d/002_init-schema-migrations.sh
RUN chmod +x /docker-entrypoint-initdb.d/*.sh
