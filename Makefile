.PHONY: run-interactive
run-interactive:
	docker run --rm -p 9000:9000 -it -v $(shell pwd)/conf:/app/conf:ro pg_stats_viewer:latest

.PHONY: run
run:
	docker run --rm -p 9000:9000 -v $(shell pwd)/conf:/app/conf:ro pg_stats_viewer:latest

.PHONY: build
build:
	docker build -t pg_stats_viewer:latest .
