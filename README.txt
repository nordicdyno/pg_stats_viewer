Useful Perl/PSGI app for `pg_stat_statements` reporting
view based on http://datatables.net and twitter bootstrap

HOW TO INSTALL:

Prepare Perl tools: 
    > cpan App::cpanminus
    > cpanm Carton

Install deps:
    > cd <app_dir>
    > carton install

Run with plackup:
    > carton exec plackup --port 9000 -E deployment

Run with Starman:
    > carton exec starman --port 9000

TODO:
    - check Plack fork & DB connection initialization (not sure I do it right)
    - improve README
    - install instructions
    - split app.psgi code to modules
    - change favicon

KNOWN ISSUES:
    - formating explosion on left 'extra' column (I don't know why)
