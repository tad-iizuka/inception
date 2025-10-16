DOCKER_COMPOSE=docker compose

DOCKER_COMPOSE_FILE = ./srcs/docker-compose.yml

all:
	mkdir -p /home/tiizuka/data/mysql
	mkdir -p /home/tiizuka/data/wordpress
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d --build
up:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) up -d
build:
	@$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_FILE) build
kill:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) kill
down:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down --rmi all --volumes --remove-orphans
clean:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down -v

fclean: clean
	sudo rm -rf /home/tiizuka/data/mysql
	sudo rm -rf /home/tiizuka/data/wordpress
# docker run --rm -v .$(pwd)/srcs:/mnt alpine sh -c "rm -rf /mnt/wordpress"
	docker system prune -a -f

.PHONY: all up kill build down clean restart
