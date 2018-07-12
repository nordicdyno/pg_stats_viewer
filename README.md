# pg_stats_viewer

webview for Postgres [pg_stat_statements](https://www.postgresql.org/docs/current/static/pgstatstatements.html) statisics.

[![Docker build](https://img.shields.io/docker/automated/nordicdyno/pg_stats_viewer.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/nordicdyno/pg_stats_viewer.svg)][hub]

## DESCRIPTION

Supports:

* multiple databases
* filtering queries by user and database names
* search by text in queries
* extra sortable fields like `avgtime`, `rows_per_call` and `shared_blks_hit_percent`
* sort by `pg_stat_statements` and extra fields
* OAuth2 (google, facebook, vk.com)

Used technologies:

* Perl Plack web microframework
* js lib http://datatables.net
* twitter bootstrap lib

## HOW TO INSTALL AND RUN

Prepare config:

    cat > conf/config.ini
    [global]
    defaultDB = master

    [db master]
    name = PG_DB
    host = PG_HOST
    port = PG_PORT
    user = PG_USER
    password = PG_PASSWORD
    Ctrl+D

`PG_DB` should contains `pg_stat_statements` table

`PG_USER` should be with read permission to relation pg_authid (for user list query), by default it is `postgres` user

### run via docker-compose

run after config creation:

    docker-compose pull
    docker-compose up

and open http://localhost:9000/

### build and run via Docker

    make build
    make

check (Makefile) for conrete commands

### run manually

Prepare Perl tools:

    cpan -S App::cpanminus
    cpanm -S Carton

Install deps:

    cd <app_dir>
    carton install

Run with plackup:

    carton exec plackup --port 9000 -E deployment

Run with Starman:

    carton exec starman --port 9000

## TODO

* vendor external js/css dependencies
* remove oauth support (just use tool like https://github.com/bitly/oauth2_proxy)
* don't require permission to `pg_authid` (abilty to run as unpriveleged postgres user)
* add instruction how to connect on localhost from docker on Mac
* add /diag endpoint

[hub]: https://hub.docker.com/r/nordicdyno/pg_stats_viewer/
