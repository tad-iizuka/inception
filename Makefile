# Docker definition
DOCKER_COMPOSE = docker compose
DOCKER_COMPOSE_FILE = ./srcs/docker-compose.yml

# Path settings
DATA_DIR = /home/tiizuka/data
MYSQL_DIR = $(DATA_DIR)/mysql
WORDPRESS_DIR = $(DATA_DIR)/wordpress
SECRETS_DIR = ./secrets
ENV_FILE = ./srcs/.env
ENV_EXAMPLE = ./.env.example

# Default password
DEFAULT_ROOT_PASSWORD = change_this_root_password
DEFAULT_DB_PASSWORD = change_this_db_password
FIXED_ADMIN_PASSWORD = password42
FIXED_GUEST_PASSWORD = password42

# Initialize and build
all: init
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d --build

# Initialize
init: create-dirs init-env init-secrets set-permissions generate-passwords
	@echo "✓ Initialization completed!"

# Create directories
create-dirs:
	@echo "Creating data directories..."
	@mkdir -p $(MYSQL_DIR)
	@mkdir -p $(WORDPRESS_DIR)
	@mkdir -p $(SECRETS_DIR)

# .env initialize
init-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "Creating .env file..."; \
		cp $(ENV_EXAMPLE) $(ENV_FILE); \
		echo "✓ .env created from .env.example"; \
	else \
		echo "✓ .env already exists"; \
	fi

# Initialize secrets
init-secrets:
	@if [ ! -f $(SECRETS_DIR)/db_root_password.txt ]; then \
		echo "Creating secret files..."; \
		echo -n "$(DEFAULT_ROOT_PASSWORD)" > $(SECRETS_DIR)/db_root_password.txt; \
		echo -n "$(DEFAULT_DB_PASSWORD)" > $(SECRETS_DIR)/db_password.txt; \
		echo -n "$(FIXED_ADMIN_PASSWORD)" > $(SECRETS_DIR)/wp_admin_password.txt; \
		echo -n "$(FIXED_GUEST_PASSWORD)" > $(SECRETS_DIR)/wp_guest_password.txt; \
		chmod 600 $(SECRETS_DIR)/*.txt; \
		echo "⚠ WARNING: Default passwords created. Please change them!"; \
		echo "  Edit: $(SECRETS_DIR)/db_root_password.txt"; \
		echo "  Edit: $(SECRETS_DIR)/db_password.txt"; \
		echo "  WP Admin (tiizuka): $(SECRETS_DIR)/wp_admin_password.txt"; \
		echo "  WP Author (guest): $(SECRETS_DIR)/wp_guest_password.txt"; \
	else \
		echo "✓ Secret files already exist"; \
	fi

# Permission settings
set-permissions:
	@echo "Setting permissions..."
	@chmod +x ./srcs/requirements/wordpress/tools/docker-entrypoint.sh 2>/dev/null || true
	@chmod +x ./srcs/requirements/mariadb/tools/docker-entrypoint.sh 2>/dev/null || true
	@if [ -f $(ENV_FILE) ]; then chmod 600 $(ENV_FILE); fi
	@if [ -d $(SECRETS_DIR) ]; then chmod 700 $(SECRETS_DIR); fi
	@if [ -f $(SECRETS_DIR)/db_root_password.txt ]; then chmod 600 $(SECRETS_DIR)/*.txt; fi

# Generate random password
generate-passwords:
	@echo "Generating secure random passwords..."
	@openssl rand -base64 12 | tr -d '/+' | tr -d '\n' > $(SECRETS_DIR)/db_root_password.txt
	@openssl rand -base64 12 | tr -d '/+' | tr -d '\n' > $(SECRETS_DIR)/db_password.txt
	@openssl rand -base64 12 | tr -d '/+' | tr -d '\n' > $(SECRETS_DIR)/wp_admin_password.txt
	@openssl rand -base64 12 | tr -d '/+' | tr -d '\n' > $(SECRETS_DIR)/wp_guest_password.txt
	@chmod 600 $(SECRETS_DIR)/*.txt
	@echo "✓ Secure passwords generated"
	@echo "Root password saved to: $(SECRETS_DIR)/db_root_password.txt"
	@echo "DB password saved to: $(SECRETS_DIR)/db_password.txt"
	@echo "WP admin password saved to: $(SECRETS_DIR)/wp_admin_password.txt"
	@echo "WP guest password saved to: $(SECRETS_DIR)/wp_guest_password.txt"

# Display passwords
show-passwords:
	@echo "=== Database Passwords ==="
	@echo "Root password: $$(cat $(SECRETS_DIR)/db_root_password.txt 2>/dev/null || echo 'Not found')"
	@echo "DB password: $$(cat $(SECRETS_DIR)/db_password.txt 2>/dev/null || echo 'Not found')"
	@echo "=== WordPress Passwords ==="
	@echo "Admin (tiizuka): $$(cat $(SECRETS_DIR)/wp_admin_password.txt 2>/dev/null || echo 'Not found')"
	@echo "Author (guest): $$(cat $(SECRETS_DIR)/wp_guest_password.txt 2>/dev/null || echo 'Not found')"

# Display .env
show-env:
	@echo "=== Environment Variables ==="
	@cat $(ENV_FILE) 2>/dev/null || echo ".env file not found"

# Docker control
ps:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) ps

build:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) build

up:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d

kill:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) kill

stop:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) stop

down:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down

restart:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) restart

logs:
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) logs

# Container health check
health:
	@echo "=== Container Health Status ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "nginx|wordpress|mariadb|NAMES"

# Cleanup (Data retained)
clean:
	@echo "Stopping and removing containers..."
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down --rmi all --volumes --remove-orphans
	@echo "Pruning Docker system..."
	@docker system prune -f
	@echo "✓ Cleanup completed (data preserved)"

# Cleanup completely
fclean: down clean
	@echo "Removing data directories..."
	@sudo rm -rf $(MYSQL_DIR)
	@sudo rm -rf $(WORDPRESS_DIR)
	@rm -f $(ENV_FILE)
	@rm -rf $(SECRETS_DIR)
	@echo "✓ Full cleanup completed"

# Cleanup and init then re-build
re: fclean init
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d --build

# Check database connection
test-db:
	@echo "=== Testing Database Connection ==="
	@echo "Testing MariaDB..."
	@docker exec mariadb mysql -u root -p$$(cat $(SECRETS_DIR)/db_root_password.txt) -e "SHOW DATABASES;" 2>/dev/null && echo "✓ Root connection OK" || echo "✗ Root connection failed"
	@echo ""
	@echo "Testing WordPress user..."
	@docker exec mariadb mysql -u wpuser -p$$(cat $(SECRETS_DIR)/db_password.txt) -e "SHOW DATABASES;" 2>/dev/null && echo "✓ WordPress user connection OK" || echo "✗ WordPress user connection failed"
	@echo ""
	@echo "Testing from WordPress container..."
	@docker exec wordpress mysql -h mariadb -u wpuser -p$$(cat $(SECRETS_DIR)/db_password.txt) -e "SHOW DATABASES;" 2>/dev/null && echo "✓ WordPress to MariaDB connection OK" || echo "✗ WordPress to MariaDB connection failed"

.PHONY: all init create-dirs init-env init-secrets set-permissions \
        generate-passwords show-passwords show-env \
        ps build up kill stop down restart logs health \
        clean fclean re test-db
