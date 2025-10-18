DOCKER_COMPOSE=docker compose

DOCKER_COMPOSE_FILE = ./srcs/docker-compose.yml

all:
	mkdir -p /home/tiizuka/data/mysql
	mkdir -p /home/tiizuka/data/wordpress
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d --build
ps:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) ps
build:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) build
up:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d
kill:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) kill
stop:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) stop
down:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down
restart:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) restart
clean:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down --rmi all --volumes --remove-orphans

fclean: clean
	sudo rm -rf /home/tiizuka/data/mysql
	sudo rm -rf /home/tiizuka/data/wordpress
	docker system prune -a -f

.PHONY: all build up kill stop down clean restart
