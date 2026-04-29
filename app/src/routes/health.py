"""
Health check endpoints following Kubernetes probe conventions.

- /health/live  → livenessProbe  (is the process alive?)
- /health/ready → readinessProbe (can it serve traffic?)
- /health      → full status     (human/dashboard consumption)
"""

import time
from enum import Enum

import structlog
from fastapi import APIRouter, Response, status

from src.config import get_settings

router = APIRouter(prefix="/health")
logger = structlog.get_logger()

# -- Track startup time for uptime calculation
_start_time = time.time()


class HealthStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


@router.get(
    "/live",
    status_code=status.HTTP_200_OK,
    summary="Liveness probe",
    response_model=dict,
)
async def liveness():
    """
    Kubernetes livenessProbe endpoint.
    Returns 200 if the process is alive. If this fails, K8s restarts the pod.
    Keep this check lightweight — no external dependencies.
    """
    return {"status": "alive"}


@router.get(
    "/ready",
    status_code=status.HTTP_200_OK,
    summary="Readiness probe",
)
async def readiness(response: Response):
    """
    Kubernetes readinessProbe endpoint.
    Returns 200 if the app can serve traffic (DB connected, etc.).
    If this fails, K8s removes the pod from Service endpoints.
    """
    checks = {}
    overall_healthy = True

    # -- Check: Database connectivity
    try:
        # TODO: Replace with actual DB ping when DB module is wired
        # async with get_db_session() as session:
        #     await session.execute(text("SELECT 1"))
        checks["database"] = {"status": "healthy", "latency_ms": 0}
    except Exception as e:
        checks["database"] = {"status": "unhealthy", "error": str(e)}
        overall_healthy = False
        logger.warning("readiness_check_failed", component="database", error=str(e))

    if not overall_healthy:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": HealthStatus.HEALTHY if overall_healthy else HealthStatus.UNHEALTHY,
        "checks": checks,
    }


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    summary="Full health status",
)
async def health_full(response: Response):
    """
    Comprehensive health check for dashboards and monitoring.
    Returns detailed status of all dependencies.
    """
    settings = get_settings()
    checks = {}
    degraded = False
    unhealthy = False

    # -- Check: Database
    try:
        checks["database"] = {"status": "healthy", "latency_ms": 0}
    except Exception as e:
        checks["database"] = {"status": "unhealthy", "error": str(e)}
        unhealthy = True

    # -- Check: External services (placeholder)
    checks["external_apis"] = {"status": "healthy"}

    # -- Determine overall status
    if unhealthy:
        overall = HealthStatus.UNHEALTHY
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    elif degraded:
        overall = HealthStatus.DEGRADED
    else:
        overall = HealthStatus.HEALTHY

    uptime_seconds = time.time() - _start_time

    return {
        "status": overall,
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
        "uptime_seconds": round(uptime_seconds, 2),
        "checks": checks,
    }
