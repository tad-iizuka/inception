# Inception Project - Dockerized WordPress Environment

This project provides an automated setup for a **WordPress** and **MariaDB** environment using **Docker Compose**.  
All necessary directories, environment variables, and secrets are automatically prepared through the Makefile.

---

## 📦 Project Structure

```
.
├── Makefile
├── srcs/
│   ├── docker-compose.yml
│   ├── .env.example
│   └── ...
├── secrets/
└── data/
    ├── mysql/
    └── wordpress/
```

---

## 🚀 Usage

### 1. Initialize and Build

Run the following command to:
- Create necessary data and secret directories
- Generate `.env` and secret files
- Build and start all Docker containers

```bash
make
```

or explicitly:

```bash
make all
```

---

### 2. Initialize Only (without starting containers)

You can run initialization steps manually if you want to check directories and environment setup before starting:

```bash
make init
```

This performs:
- Directory creation (`data/mysql`, `data/wordpress`, `secrets/`)
- `.env` setup (from `.env.example`)
- Secret file creation
- Permission settings

---

### 3. Start the Containers

If already initialized, start containers using:

```bash
make up
```

---

### 4. Stop Containers

To stop all running containers:

```bash
make down
```

---

### 5. Full Cleanup

Removes all containers, volumes, and related data.

```bash
make fclean
```

> ⚠️ **Warning:** This will delete all persistent WordPress and database data under `/home/tiizuka/data`.

---

### 6. Clean Without Deleting Data

Stops containers and prunes unused Docker resources without removing data directories.

```bash
make clean
```

---

## ⚙️ Configuration

### Environment Variables
Environment variables are defined in `.env`.  
If `.env` doesn’t exist, it will be automatically created from `.env.example`.

Typical variables include:
```
MYSQL_ROOT_PASSWORD=...
MYSQL_USER=...
MYSQL_PASSWORD=...
WORDPRESS_DB_NAME=...
```

### Default Paths
| Directory | Description |
|------------|-------------|
| `/home/tiizuka/data/mysql` | MariaDB data |
| `/home/tiizuka/data/wordpress` | WordPress files |
| `./secrets/` | Secret files (passwords, etc.) |

---

## 🧹 Maintenance Commands

| Command | Description |
|----------|-------------|
| `make ps` | Show running containers |
| `make logs` | View container logs |
| `make restart` | Restart all services |

---

## 🛡️ Security Notice

Default passwords are placeholders:
```
DEFAULT_ROOT_PASSWORD = change_this_root_password
DEFAULT_DB_PASSWORD = change_this_db_password
```
You **must** update them before deploying to production.

---

## 🧰 Requirements

- Docker
- Docker Compose
- GNU Make

---

## 📝 License

This project is provided as-is for educational purposes under the MIT License.
