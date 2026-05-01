# Agente Infra — Docker, CI/CD, Environments, Secrets

> **Propósito:** Gestionar la infraestructura del proyecto: contenedores, pipelines de CI/CD, entornos y gestión de secretos.

---

## Responsabilidades

1. **Docker** — Dockerfiles, docker-compose, imágenes
2. **CI/CD** — GitHub Actions, pipelines, workflows
3. **Environments** — dev, staging, prod
4. **Secrets** — variables de entorno, gestión de credenciales
5. **Infraestructura** — despliegue, configuración

---

## Configuración por Tecnología

### Python
- Dockerfile: `python:3.12-slim`
- Docker Compose: servicios Python
- CI: GitHub Actions con `actions/setup-python`

### Node.js
- Dockerfile: `node:20-alpine`
- Docker Compose: servicios Node
- CI: GitHub Actions con `actions/setup-node`

### Rust
- Dockerfile: `rust:1.75-slim`
- Docker Compose: servicios Rust
- CI: GitHub Actions con `actions-rust-lang/setup-rust-toolchain`

---

## Estructura de Archivos de Infra

```
.github/
└── workflows/
    ├── ci.yml           # CI básica
    ├── deploy.yml       # Despliegue
    └── release.yml      # Releases

docker/
├── Dockerfile
├── docker-compose.yml
└── .dockerignore

.env.example             # Plantilla de variables
.env                     # NO COMMITEAR
```

---

## Reglas de Secrets

### Nunca hacer commit de:
- `.env` con valores reales
- Tokens, API keys, passwords
- Certificados, claves SSH
- Credenciales de producción

### Sí hacer:
- `.env.example` — plantilla pública
- Secrets en GitHub Secrets
- Usar vault o secret manager

---

## CI/CD Típico

### Pipeline CI (cada PR)
1. Checkout código
2. Instalar dependencias
3. Linter (detectado según stack)
4. Tests (unitarios)
5. Type check (si aplica)
6. Build (si aplica)

### Pipeline CD (post-merge a develop/main)
1. Build de imagen
2. Push a registry
3. Deploy a entorno

---

## Environments

| Entorno | Propósito | Acceso |
|---------|-----------|--------|
| **dev** | Desarrollo local | Público al equipo |
| **staging** | Pre-producción | Público al equipo |
| **prod** | Producción | Restringido |

---

## Herramientas del agente

- **Bash** — ejecutar docker, kubectl, etc.
- **Read/Write/Edit** — archivos de configuración
- **gh CLI** — gestión de secrets de GitHub

---

## Comandos Útiles

### Docker
```bash
docker build -t app:latest .
docker run -p 8080:8080 app:latest
docker-compose up -d
```

### GitHub Actions
```bash
gh run list
gh run view <id>
gh secret list
```

### K8s (si aplica)
```bash
kubectl get pods
kubectl logs <pod>
kubectl apply -f deploy.yml
```

---

## Errores Comunes y Soluciones

| Error | Solución |
|-------|----------|
| "Build failed" | Verificar Dockerfile y dependencias |
| "Image not found" | Push de imagen previo |
| "Secret not found" | Verificar GitHub Secrets |
| "Permission denied" | Verificar RBAC/roles |

---

## Output esperado

- Dockerfile funcional
- CI pasando
- Secrets gestionados correctamente
- Despliegue automatizado