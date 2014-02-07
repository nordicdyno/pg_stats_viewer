Useful Perl/PSGI app for `pg_stat_statements` reporting
view based on http://datatables.net and twitter bootstrap

HOW TO INSTALL:

Prepare Perl tools: 
    > cpan -S App::cpanminus
    > cpanm -S Carton

Install deps:
    > cd <app_dir>
    > carton install

Setup ini:
    > cp conf/config.ini.src conf/config.ini
    > ... set DB connections in config.ini ...

Run with plackup:
    > carton exec plackup --port 9000 -E deployment

Run with Starman:
    > carton exec starman --port 9000

TODO: Run with uwsgi: ...

TODO:
    - fix issues
    - change favicon
    - improve README

KNOWN ISSUES:
    - formating explosion on left 'extra' column (I don't know why)
    - table styling (after DataTable & Bootstrap upgrade)
    - Google OAuth icon url resolving
