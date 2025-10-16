DOCKER_COMPOSE=docker compose

DOCKER_COMPOSE_FILE = ./srcs/docker-compose.yml

all:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d --build
up:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d
build:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) build
kill:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) kill
down:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down
clean:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down -v

fclean: clean
	docker run --rm -v .$(pwd)/srcs:/mnt alpine sh -c "rm -rf /mnt/wordpress"
	docker system prune -a -f

.PHONY: all up kill build down clean restart
