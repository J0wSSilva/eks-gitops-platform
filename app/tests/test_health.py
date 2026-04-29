"""
Tests for health check endpoints.
Validates Kubernetes probe contracts and response schemas.
"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestLiveness:
    """Tests for /health/live (livenessProbe)."""

    async def test_liveness_returns_200(self, client: AsyncClient):
        response = await client.get("/health/live")
        assert response.status_code == 200

    async def test_liveness_response_body(self, client: AsyncClient):
        response = await client.get("/health/live")
        data = response.json()
        assert data["status"] == "alive"

    async def test_liveness_is_fast(self, client: AsyncClient):
        """Liveness should respond in under 100ms (no external deps)."""
        import time

        start = time.perf_counter()
        await client.get("/health/live")
        duration = (time.perf_counter() - start) * 1000
        assert duration < 100, f"Liveness took {duration:.1f}ms (max: 100ms)"


@pytest.mark.asyncio
class TestReadiness:
    """Tests for /health/ready (readinessProbe)."""

    async def test_readiness_returns_200_when_healthy(self, client: AsyncClient):
        response = await client.get("/health/ready")
        assert response.status_code == 200

    async def test_readiness_response_schema(self, client: AsyncClient):
        response = await client.get("/health/ready")
        data = response.json()
        assert "status" in data
        assert "checks" in data
        assert data["status"] in ("healthy", "degraded", "unhealthy")

    async def test_readiness_includes_database_check(self, client: AsyncClient):
        response = await client.get("/health/ready")
        data = response.json()
        assert "database" in data["checks"]
        assert "status" in data["checks"]["database"]


@pytest.mark.asyncio
class TestHealthFull:
    """Tests for /health (full status endpoint)."""

    async def test_health_returns_200(self, client: AsyncClient):
        response = await client.get("/health")
        assert response.status_code == 200

    async def test_health_response_schema(self, client: AsyncClient):
        response = await client.get("/health")
        data = response.json()
        assert "status" in data
        assert "service" in data
        assert "version" in data
        assert "environment" in data
        assert "uptime_seconds" in data
        assert "checks" in data

    async def test_health_reports_correct_environment(self, client: AsyncClient):
        response = await client.get("/health")
        data = response.json()
        assert data["environment"] == "test"

    async def test_health_uptime_is_positive(self, client: AsyncClient):
        response = await client.get("/health")
        data = response.json()
        assert data["uptime_seconds"] > 0


@pytest.mark.asyncio
class TestRoot:
    """Tests for / (root endpoint)."""

    async def test_root_returns_200(self, client: AsyncClient):
        response = await client.get("/")
        assert response.status_code == 200

    async def test_root_includes_service_info(self, client: AsyncClient):
        response = await client.get("/")
        data = response.json()
        assert "service" in data
        assert "version" in data
        assert "environment" in data

    async def test_root_docs_url_present_in_non_prod(self, client: AsyncClient):
        response = await client.get("/")
        data = response.json()
        assert data["docs"] == "/docs"


@pytest.mark.asyncio
class TestMetrics:
    """Tests for /metrics (Prometheus scrape endpoint)."""

    async def test_metrics_endpoint_disabled_in_test(self, client: AsyncClient):
        """Metrics are disabled in test environment to avoid side effects."""
        response = await client.get("/metrics")
        # When METRICS_ENABLED=false, endpoint shouldn't exist → 404
        assert response.status_code == 404


@pytest.mark.asyncio
class TestMiddleware:
    """Tests for custom middleware behavior."""

    async def test_response_includes_timing_header(self, client: AsyncClient):
        response = await client.get("/health/live")
        assert "X-Response-Time" in response.headers
        assert "ms" in response.headers["X-Response-Time"]

    async def test_request_id_propagation(self, client: AsyncClient):
        request_id = "test-req-12345"
        response = await client.get(
            "/health/live", headers={"X-Request-ID": request_id}
        )
        assert response.headers["X-Request-ID"] == request_id
