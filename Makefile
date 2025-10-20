DOCKER_COMPOSE = docker compose
DOCKER_COMPOSE_FILE = ./srcs/docker-compose.yml

# パス設定
DATA_DIR = /home/tiizuka/data
MYSQL_DIR = $(DATA_DIR)/mysql
WORDPRESS_DIR = $(DATA_DIR)/wordpress
SECRETS_DIR = ./secrets
ENV_FILE = ./srcs/.env
ENV_EXAMPLE = ./srcs/.env.example

# デフォルトのパスワード（本番環境では変更推奨）
DEFAULT_ROOT_PASSWORD = change_this_root_password
DEFAULT_DB_PASSWORD = change_this_db_password

all: init
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d --build

# 初期化（ディレクトリ、.env、シークレット作成）
init: create-dirs init-env init-secrets set-permissions generate-passwords
	@echo "✓ Initialization completed!"

# データディレクトリ作成
create-dirs:
	@echo "Creating data directories..."
	@mkdir -p $(MYSQL_DIR)
	@mkdir -p $(WORDPRESS_DIR)
	@mkdir -p $(SECRETS_DIR)

# .envファイルの初期化
init-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "Creating .env file..."; \
		if [ -f $(ENV_EXAMPLE) ]; then \
			cp $(ENV_EXAMPLE) $(ENV_FILE); \
			echo "✓ .env created from .env.example"; \
		else \
			echo "Creating default .env file..."; \
			echo "# WordPress データベース設定" > $(ENV_FILE); \
			echo "WORDPRESS_DB_HOST=mariadb:3306" >> $(ENV_FILE); \
			echo "WORDPRESS_DB_USER=wpuser" >> $(ENV_FILE); \
			echo "WORDPRESS_DB_NAME=wordpress" >> $(ENV_FILE); \
			echo "WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db_password" >> $(ENV_FILE); \
			echo "" >> $(ENV_FILE); \
			echo "# MariaDB データベース設定" >> $(ENV_FILE); \
			echo "MARIADB_DATABASE=wordpress" >> $(ENV_FILE); \
			echo "MARIADB_USER=wpuser" >> $(ENV_FILE); \
			echo "MARIADB_ROOT_PASSWORD_FILE=/run/secrets/db_root_password" >> $(ENV_FILE); \
			echo "MARIADB_PASSWORD_FILE=/run/secrets/db_password" >> $(ENV_FILE); \
			echo "" >> $(ENV_FILE); \
			echo "# シークレットファイルのホスト側パス" >> $(ENV_FILE); \
			echo "DB_ROOT_PASSWORD_FILE=../secrets/db_root_password.txt" >> $(ENV_FILE); \
			echo "DB_PASSWORD_FILE=../secrets/db_password.txt" >> $(ENV_FILE); \
			echo "✓ Default .env created"; \
		fi; \
	else \
		echo "✓ .env already exists"; \
	fi

# シークレットファイルの初期化
init-secrets:
	@if [ ! -f $(SECRETS_DIR)/db_root_password.txt ]; then \
		echo "Creating secret files..."; \
		echo -n "$(DEFAULT_ROOT_PASSWORD)" > $(SECRETS_DIR)/db_root_password.txt; \
		echo -n "$(DEFAULT_DB_PASSWORD)" > $(SECRETS_DIR)/db_password.txt; \
		chmod 600 $(SECRETS_DIR)/*.txt; \
		echo "⚠ WARNING: Default passwords created. Please change them!"; \
		echo "  Edit: $(SECRETS_DIR)/db_root_password.txt"; \
		echo "  Edit: $(SECRETS_DIR)/db_password.txt"; \
	else \
		echo "✓ Secret files already exist"; \
	fi

# パーミッション設定
set-permissions:
	@echo "Setting permissions..."
	@chmod +x ./srcs/requirements/wordpress/tools/docker-entrypoint.sh 2>/dev/null || true
	@chmod +x ./srcs/requirements/mariadb/tools/docker-entrypoint.sh 2>/dev/null || true
	@if [ -f $(ENV_FILE) ]; then chmod 600 $(ENV_FILE); fi
	@if [ -d $(SECRETS_DIR) ]; then chmod 700 $(SECRETS_DIR); fi
	@if [ -f $(SECRETS_DIR)/db_root_password.txt ]; then chmod 600 $(SECRETS_DIR)/*.txt; fi

# ランダムパスワード生成
generate-passwords:
	@echo "Generating secure random passwords..."
	@openssl rand -base64 32 | tr -d '\n' > $(SECRETS_DIR)/db_root_password.txt
	@openssl rand -base64 32 | tr -d '\n' > $(SECRETS_DIR)/db_password.txt
	@chmod 600 $(SECRETS_DIR)/*.txt
	@echo "✓ Secure passwords generated"
	@echo "Root password saved to: $(SECRETS_DIR)/db_root_password.txt"
	@echo "DB password saved to: $(SECRETS_DIR)/db_password.txt"
	@echo "⚠ WARNING: You must rebuild containers after changing passwords!"
	@echo "  Run: make re"

# パスワード表示
show-passwords:
	@echo "=== Database Passwords ==="
	@echo "Root password: $$(cat $(SECRETS_DIR)/db_root_password.txt 2>/dev/null || echo 'Not found')"
	@echo "DB password: $$(cat $(SECRETS_DIR)/db_password.txt 2>/dev/null || echo 'Not found')"

# 環境変数表示
show-env:
	@echo "=== Environment Variables ==="
	@cat $(ENV_FILE) 2>/dev/null || echo ".env file not found"

# Docker操作
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
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) logs -f

# ヘルスチェック
health:
	@echo "=== Container Health Status ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "nginx|wordpress|mariadb|NAMES"

# クリーンアップ（データは保持）
clean:
	@echo "Stopping and removing containers..."
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) down --rmi all --volumes --remove-orphans
	@echo "Pruning Docker system..."
	@docker system prune -f
	@echo "✓ Cleanup completed (data preserved)"

# 完全クリーンアップ（データも削除）
fclean: clean
	@echo "Removing data directories..."
	@sudo rm -rf $(MYSQL_DIR)
	@sudo rm -rf $(WORDPRESS_DIR)
	@rm -f $(ENV_FILE)
	@rm -rf $(SECRETS_DIR)
	@echo "✓ Full cleanup completed"

# 再初期化（クリーンアップ後に初期化）
re: fclean init
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d --build

# データベース接続テスト
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

# ヘルプ
help:
	@echo "=== WordPress Docker Environment - Makefile Commands ==="
	@echo ""
	@echo "初期化コマンド:"
	@echo "  make init              - 環境を初期化（ディレクトリ、.env、シークレット作成）"
	@echo "  make generate-passwords - ランダムなセキュアパスワードを生成"
	@echo ""
	@echo "ビルド・起動:"
	@echo "  make all               - 初期化してビルド＆起動"
	@echo "  make build             - イメージをビルド"
	@echo "  make up                - コンテナを起動"
	@echo ""
	@echo "停止・再起動:"
	@echo "  make stop              - コンテナを停止"
	@echo "  make kill              - コンテナを強制停止"
	@echo "  make restart           - コンテナを再起動"
	@echo "  make down              - コンテナを停止して削除"
	@echo ""
	@echo "情報確認:"
	@echo "  make ps                - コンテナ一覧を表示"
	@echo "  make logs              - ログをリアルタイム表示"
	@echo "  make health            - ヘルスステータスを表示"
	@echo "  make show-env          - 環境変数を表示"
	@echo "  make show-passwords    - パスワードを表示"
	@echo "  make test-db           - データベース接続をテスト"
	@echo ""
	@echo "クリーンアップ:"
	@echo "  make clean             - コンテナとイメージを削除（データ保持）"
	@echo "  make fclean            - データも含めて完全削除（確認あり）"
	@echo "  make fclean-force      - データも含めて完全削除（確認なし）"
	@echo "  make reset             - .envとシークレットも含めて完全リセット"
	@echo "  make rebuild           - データ保持して再構築"
	@echo "  make re                - 完全削除後に再構築"

.PHONY: all init create-dirs init-env init-secrets set-permissions \
        generate-passwords show-passwords show-env \
        ps build up kill stop down restart logs health \
        clean fclean ｘre test-db help
				