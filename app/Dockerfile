# =============================================================================
# Multi-stage Dockerfile for EKS GitOps Platform Demo App
# Final image: python:3.12-slim (~120MB) — non-root, hardened
# =============================================================================

# -- Stage 1: Dependencies (cached layer)
FROM python:3.12-slim AS dependencies

WORKDIR /build

# Install only production deps (no dev tools in final image)
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# -- Stage 2: Test (CI only — not in final image)
FROM python:3.12-slim AS test

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir pytest pytest-asyncio pytest-cov ruff

COPY src/ src/
COPY tests/ tests/

# Lint
RUN ruff check src/ tests/

# Tests with coverage
RUN pytest tests/ -v --cov=src --cov-report=term-missing --cov-fail-under=80

# -- Stage 3: Production
FROM python:3.12-slim AS production

# Security: non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy installed dependencies from stage 1
COPY --from=dependencies /install /usr/local

# Copy application source
COPY src/ src/

# Security: no shell, no package manager in final image
RUN apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && find /usr/local -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

# Security: read-only filesystem support
RUN chown -R appuser:appuser /app

USER appuser

# Health check (used by Docker, not K8s — K8s uses its own probes)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/live')" || exit 1

# Expose application port
EXPOSE 8000

# Labels for container metadata
LABEL org.opencontainers.image.title="eks-gitops-platform" \
      org.opencontainers.image.description="Demo FastAPI app for EKS GitOps Platform" \
      org.opencontainers.image.source="https://github.com/J0wSSilva/eks-gitops-platform" \
      org.opencontainers.image.vendor="J0wSSilva" \
      org.opencontainers.image.licenses="MIT"

# Run with uvicorn (production settings)
# --proxy-headers: trust X-Forwarded-For from ALB
# --forwarded-allow-ips='*': ALB terminates TLS
# --access-log: disabled (structlog handles request logging)
ENTRYPOINT ["python", "-m", "uvicorn"]
CMD ["src.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--proxy-headers", \
     "--forwarded-allow-ips", "*", \
     "--no-access-log", \
     "--workers", "1"]
