
d_network=ladesa-net
d_container_app=ladesa-ro-sso

compose_options=--file .development/docker-compose.yml -p ladesa-ro-sso

setup:
	$(shell (cd .development; find . -type f -name "*.example" -exec sh -c 'cp -n {} $$(basename {} .example)' \;))
	$(shell (bash -c "docker network create $(d_network) &>/dev/null"))

up:
	make setup;
	docker-compose $(compose_options) up --force-recreate --remove-orphans -d;

start:
	make setup;

	make down;
	make up;

	docker compose $(compose_options) exec \
		-u node \
		--no-TTY \
		-d $(d_container_app) \
			bash -c "npm i && npm run migration:run && npm run start:dev" \& \
		;

logs:
	make setup;
	docker compose $(compose_options) logs -f;

shell:
	make setup;
	make up;
	docker compose $(compose_options) exec $(d_container_app) bash;

shell-root:
	make setup;
	make up;
	docker compose $(compose_options) exec -u root $(d_container_app) bash;

stop:
	make setup;
	docker compose $(compose_options) stop;

down:
	make setup;
	docker-compose $(compose_options) down --remove-orphans;

cleanup:
	docker compose $(compose_options) down --remove-orphans -v;