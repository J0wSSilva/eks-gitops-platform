"""EKS GitOps Platform — Pod Dashboard. Zero external dependencies."""
import json
import os
import platform
import socket
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone
from pathlib import Path

START_TIME = time.time()
REQUEST_COUNT = 0
_counter_lock = threading.Lock()


def get_memory_info():
    """Read memory from /proc/meminfo (Linux cgroups-aware)."""
    try:
        # Try cgroup v2 first (K8s containers)
        cgroup_limit = Path("/sys/fs/cgroup/memory.max")
        cgroup_usage = Path("/sys/fs/cgroup/memory.current")
        if cgroup_limit.exists() and cgroup_usage.exists():
            limit = cgroup_limit.read_text().strip()
            usage = int(cgroup_usage.read_text().strip())
            if limit == "max":
                limit_mb = "unlimited"
            else:
                limit_mb = f"{int(limit) // (1024*1024)} MB"
            return {"used": f"{usage // (1024*1024)} MB", "limit": limit_mb,
                    "percent": f"{(usage / int(limit) * 100):.1f}%" if limit != "max" else "N/A"}
        # Fallback to /proc/meminfo
        with open("/proc/meminfo") as f:
            lines = f.readlines()
        mem = {}
        for line in lines:
            parts = line.split()
            if parts[0] in ("MemTotal:", "MemAvailable:", "MemFree:"):
                mem[parts[0].rstrip(":")] = int(parts[1])
        total = mem.get("MemTotal", 0)
        avail = mem.get("MemAvailable", mem.get("MemFree", 0))
        used = total - avail
        pct = (used / total * 100) if total else 0
        return {"used": f"{used // 1024} MB", "limit": f"{total // 1024} MB", "percent": f"{pct:.1f}%"}
    except Exception:
        return {"used": "N/A", "limit": "N/A", "percent": "N/A"}


def get_cpu_info():
    """Read CPU from /proc/stat."""
    try:
        cpu_count = os.cpu_count() or 1
        # Get load average
        load1, load5, load15 = os.getloadavg()
        return {"cores": str(cpu_count), "load_1m": f"{load1:.2f}",
                "load_5m": f"{load5:.2f}", "load_15m": f"{load15:.2f}"}
    except Exception:
        return {"cores": str(os.cpu_count() or "N/A"), "load_1m": "N/A", "load_5m": "N/A", "load_15m": "N/A"}


def get_disk_info():
    """Get disk usage for the container filesystem."""
    try:
        st = os.statvfs("/")
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - free
        pct = (used / total * 100) if total else 0
        return {"used": f"{used // (1024**2)} MB", "total": f"{total // (1024**2)} MB", "percent": f"{pct:.1f}%"}
    except Exception:
        return {"used": "N/A", "total": "N/A", "percent": "N/A"}


def get_network_info():
    """Get network interfaces."""
    try:
        hostname = socket.gethostname()
        host_ip = socket.gethostbyname(hostname)
        # DNS resolution test
        dns_ok = False
        try:
            socket.getaddrinfo("kubernetes.default.svc.cluster.local", 443, socket.AF_INET)
            dns_ok = True
        except Exception:
            pass
        return {"hostname": hostname, "host_ip": host_ip, "dns_resolution": "OK" if dns_ok else "FAILED"}
    except Exception:
        return {"hostname": "N/A", "host_ip": "N/A", "dns_resolution": "N/A"}


def get_k8s_info():
    """Read Kubernetes service account info if available."""
    info = {"service_account": "N/A", "namespace_file": "N/A", "token_present": False}
    try:
        sa_path = Path("/var/run/secrets/kubernetes.io/serviceaccount")
        if sa_path.exists():
            ns_file = sa_path / "namespace"
            if ns_file.exists():
                info["namespace_file"] = ns_file.read_text().strip()
            token_file = sa_path / "token"
            info["token_present"] = token_file.exists()
            ca_file = sa_path / "ca.crt"
            info["ca_present"] = ca_file.exists()
    except Exception:
        pass
    return info


def format_uptime(seconds):
    days, remainder = divmod(int(seconds), 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, secs = divmod(remainder, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    parts.append(f"{minutes}m")
    parts.append(f"{secs}s")
    return " ".join(parts)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global REQUEST_COUNT

        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy", "uptime": format_uptime(time.time() - START_TIME),
                                         "requests": REQUEST_COUNT}).encode())
            return

        if self.path == "/readyz":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ready"}).encode())
            return

        if self.path == "/api/metrics":
            with _counter_lock:
                REQUEST_COUNT += 1
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            data = {
                "pod": {"name": os.environ.get("HOSTNAME", socket.gethostname()),
                        "namespace": os.environ.get("POD_NAMESPACE", "unknown"),
                        "node": os.environ.get("NODE_NAME", "unknown"),
                        "ip": os.environ.get("POD_IP", "unknown")},
                "uptime": format_uptime(time.time() - START_TIME),
                "started": datetime.fromtimestamp(START_TIME, tz=timezone.utc).isoformat(),
                "requests": REQUEST_COUNT,
                "memory": get_memory_info(),
                "cpu": get_cpu_info(),
                "runtime": {"python": platform.python_version(), "arch": platform.machine()}
            }
            self.wfile.write(json.dumps(data, indent=2).encode())
            return

        if self.path != "/":
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode())
            return

        with _counter_lock:
            REQUEST_COUNT += 1
        uptime = format_uptime(time.time() - START_TIME)
        pod_name = os.environ.get("HOSTNAME", socket.gethostname())
        namespace = os.environ.get("POD_NAMESPACE", "unknown")
        node_name = os.environ.get("NODE_NAME", "unknown")
        pod_ip = os.environ.get("POD_IP", "unknown")
        started = datetime.fromtimestamp(START_TIME, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        mem = get_memory_info()
        cpu = get_cpu_info()
        disk = get_disk_info()
        net = get_network_info()
        k8s = get_k8s_info()

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="10">
<title>EKS GitOps Platform — Pod Dashboard</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0a0e1a; color: #e2e8f0; min-height: 100vh; padding: 1.5rem; }}
  .container {{ max-width: 1100px; margin: 0 auto; }}
  .top-bar {{ display: flex; justify-content: space-between; align-items: center;
              margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem; }}
  .top-bar h1 {{ font-size: 1.4rem; color: #f8fafc; display: flex; align-items: center; gap: 0.5rem; }}
  .top-bar h1 .logo {{ color: #38bdf8; }}
  .badge {{ display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.3rem 0.75rem;
            border-radius: 20px; font-size: 0.75rem; font-weight: 600; }}
  .badge-green {{ background: rgba(34,197,94,0.15); color: #22c55e; border: 1px solid rgba(34,197,94,0.3); }}
  .badge-blue {{ background: rgba(56,189,248,0.15); color: #38bdf8; border: 1px solid rgba(56,189,248,0.3); }}
  .badge-dot {{ width: 8px; height: 8px; border-radius: 50%; animation: pulse 2s infinite; }}
  .badge-green .badge-dot {{ background: #22c55e; }}
  @keyframes pulse {{ 0%,100% {{ opacity:1; }} 50% {{ opacity:0.4; }} }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1rem; }}
  .card {{ background: #111827; border: 1px solid #1e293b; border-radius: 12px;
           padding: 1.25rem; transition: border-color 0.2s; }}
  .card:hover {{ border-color: #334155; }}
  .card-header {{ display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;
                  padding-bottom: 0.75rem; border-bottom: 1px solid #1e293b; }}
  .card-header .icon {{ font-size: 1.1rem; }}
  .card-header h2 {{ font-size: 0.85rem; color: #94a3b8; text-transform: uppercase;
                     letter-spacing: 0.08em; font-weight: 600; }}
  .metric-grid {{ display: grid; gap: 0.5rem; }}
  .metric {{ display: flex; justify-content: space-between; align-items: center;
             padding: 0.5rem 0.75rem; background: #0a0e1a; border-radius: 6px; }}
  .metric .label {{ color: #64748b; font-size: 0.78rem; }}
  .metric .value {{ color: #f1f5f9; font-weight: 500; font-size: 0.85rem;
                    font-family: 'JetBrains Mono', 'Fira Code', monospace;
                    text-align: right; word-break: break-all; max-width: 55%; }}
  .metric .value.highlight {{ color: #38bdf8; }}
  .metric .value.warn {{ color: #f59e0b; }}
  .progress-bar {{ height: 4px; background: #1e293b; border-radius: 2px; margin-top: 0.25rem; overflow: hidden; }}
  .progress-fill {{ height: 100%; border-radius: 2px; transition: width 0.5s; }}
  .progress-fill.green {{ background: linear-gradient(90deg, #22c55e, #4ade80); }}
  .progress-fill.yellow {{ background: linear-gradient(90deg, #f59e0b, #fbbf24); }}
  .progress-fill.red {{ background: linear-gradient(90deg, #ef4444, #f87171); }}
  .footer {{ text-align: center; margin-top: 2rem; padding-top: 1rem;
             border-top: 1px solid #1e293b; color: #475569; font-size: 0.75rem; }}
  .footer a {{ color: #38bdf8; text-decoration: none; }}
  .health-checks {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 0.5rem; }}
  .health-item {{ text-align: center; padding: 0.75rem; background: #0a0e1a; border-radius: 8px; }}
  .health-item .check-icon {{ font-size: 1.5rem; margin-bottom: 0.25rem; }}
  .health-item .check-label {{ font-size: 0.7rem; color: #64748b; text-transform: uppercase; }}
  .health-item .check-value {{ font-size: 0.8rem; color: #22c55e; font-weight: 600; margin-top: 0.15rem; }}
  .req-counter {{ font-family: 'JetBrains Mono', monospace; font-size: 2rem;
                  color: #38bdf8; font-weight: 700; text-align: center; padding: 0.5rem 0; }}
  .req-label {{ text-align: center; color: #64748b; font-size: 0.75rem; text-transform: uppercase; }}
</style>
</head>
<body>
<div class="container">
  <div class="top-bar">
    <h1><span class="logo">&#9670;</span> EKS GitOps Platform</h1>
    <div style="display:flex; gap:0.5rem; align-items:center;">
      <span class="badge badge-green"><span class="badge-dot"></span>Healthy</span>
      <span class="badge badge-blue">v1.0.0</span>
    </div>
  </div>

  <div class="grid">
    <!-- Pod Identity -->
    <div class="card">
      <div class="card-header"><span class="icon">&#9641;</span><h2>Pod Identity</h2></div>
      <div class="metric-grid">
        <div class="metric"><span class="label">Pod Name</span><span class="value highlight">{pod_name}</span></div>
        <div class="metric"><span class="label">Namespace</span><span class="value">{namespace}</span></div>
        <div class="metric"><span class="label">Node</span><span class="value">{node_name}</span></div>
        <div class="metric"><span class="label">Pod IP</span><span class="value">{pod_ip}</span></div>
        <div class="metric"><span class="label">Service Account</span><span class="value">{os.environ.get("SERVICE_ACCOUNT", "default")}</span></div>
        <div class="metric"><span class="label">PID</span><span class="value">{os.getpid()}</span></div>
      </div>
    </div>

    <!-- Uptime & Requests -->
    <div class="card">
      <div class="card-header"><span class="icon">&#9202;</span><h2>Runtime</h2></div>
      <div class="req-counter">{REQUEST_COUNT}</div>
      <div class="req-label">Total Requests Served</div>
      <div class="metric-grid" style="margin-top:1rem;">
        <div class="metric"><span class="label">Uptime</span><span class="value highlight">{uptime}</span></div>
        <div class="metric"><span class="label">Started</span><span class="value">{started}</span></div>
        <div class="metric"><span class="label">Python</span><span class="value">{platform.python_version()}</span></div>
        <div class="metric"><span class="label">Arch</span><span class="value">{platform.machine()}</span></div>
      </div>
    </div>

    <!-- Resources -->
    <div class="card">
      <div class="card-header"><span class="icon">&#9881;</span><h2>Resources</h2></div>
      <div class="metric-grid">
        <div class="metric"><span class="label">Memory Used</span><span class="value">{mem['used']}</span></div>
        <div class="metric"><span class="label">Memory Limit</span><span class="value">{mem['limit']}</span></div>
        <div class="metric">
          <span class="label">Memory Usage</span><span class="value">{mem['percent']}</span>
        </div>
        <div class="progress-bar"><div class="progress-fill {'green' if mem['percent'] == 'N/A' or float(mem['percent'].rstrip('%')) < 70 else 'yellow' if float(mem['percent'].rstrip('%')) < 90 else 'red'}" style="width:{mem['percent'] if mem['percent'] != 'N/A' else '0%'}"></div></div>
        <div class="metric"><span class="label">CPU Cores</span><span class="value">{cpu['cores']}</span></div>
        <div class="metric"><span class="label">Load (1m/5m/15m)</span><span class="value">{cpu['load_1m']} / {cpu['load_5m']} / {cpu['load_15m']}</span></div>
        <div class="metric"><span class="label">Disk Used</span><span class="value">{disk['used']} / {disk['total']}</span></div>
      </div>
    </div>

    <!-- Network & K8s -->
    <div class="card">
      <div class="card-header"><span class="icon">&#9729;</span><h2>Network & Kubernetes</h2></div>
      <div class="metric-grid">
        <div class="metric"><span class="label">DNS Resolution</span><span class="value {'highlight' if net['dns_resolution'] == 'OK' else 'warn'}">{net['dns_resolution']}</span></div>
        <div class="metric"><span class="label">Cluster DNS</span><span class="value">kubernetes.default.svc</span></div>
        <div class="metric"><span class="label">SA Token</span><span class="value">{"Mounted" if k8s['token_present'] else "Not Found"}</span></div>
        <div class="metric"><span class="label">CA Cert</span><span class="value">{"Present" if k8s.get('ca_present') else "Not Found"}</span></div>
        <div class="metric"><span class="label">K8s Namespace (file)</span><span class="value">{k8s['namespace_file']}</span></div>
      </div>
    </div>
  </div>

  <!-- Health Checks -->
  <div class="card" style="margin-top:1rem;">
    <div class="card-header"><span class="icon">&#10003;</span><h2>Health Checks</h2></div>
    <div class="health-checks">
      <div class="health-item">
        <div class="check-icon" style="color:#22c55e;">&#10004;</div>
        <div class="check-label">HTTP Server</div>
        <div class="check-value">Listening :8080</div>
      </div>
      <div class="health-item">
        <div class="check-icon" style="color:#22c55e;">&#10004;</div>
        <div class="check-label">Process</div>
        <div class="check-value">PID {os.getpid()}</div>
      </div>
      <div class="health-item">
        <div class="check-icon" style="color:{'#22c55e' if net['dns_resolution'] == 'OK' else '#f59e0b'};">{'&#10004;' if net['dns_resolution'] == 'OK' else '&#9888;'}</div>
        <div class="check-label">DNS</div>
        <div class="check-value">{net['dns_resolution']}</div>
      </div>
      <div class="health-item">
        <div class="check-icon" style="color:{'#22c55e' if k8s['token_present'] else '#f59e0b'};">{'&#10004;' if k8s['token_present'] else '&#9888;'}</div>
        <div class="check-label">SA Token</div>
        <div class="check-value">{"Mounted" if k8s['token_present'] else "Missing"}</div>
      </div>
      <div class="health-item">
        <div class="check-icon" style="color:#22c55e;">&#10004;</div>
        <div class="check-label">Filesystem</div>
        <div class="check-value">{disk['percent']} used</div>
      </div>
    </div>
  </div>

  <div class="footer">
    <strong>EKS GitOps Platform</strong> &mdash; Pod Dashboard v1.0.0<br>
    GitOps: <a href="#">ArgoCD</a> &bull; IaC: Terraform &bull; Cluster: Kind (local) / EKS (prod)<br>
    Auto-refresh: 10s &bull; API: <a href="/api/metrics">/api/metrics</a> &bull; Health: <a href="/healthz">/healthz</a>
  </div>
</div>
</body>
</html>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(html.encode())

    def log_message(self, format, *args):
        print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {self.address_string()} {args[0]}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"Pod-info server running on :{port}")
    server.serve_forever()
