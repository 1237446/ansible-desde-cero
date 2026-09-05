<div align="center">
  
# Laboratorio de Automatización con Ansible

Entorno de aprendizaje interactivo local basado en contenedores Docker con soporte nativo para Systemd y acceso centralizado mediante VS Code Web.

![Docker](https://img.shields.io/badge/Docker-Compose_v2-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-2.16+-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-9-10B981?style=for-the-badge&logo=rockylinux&logoColor=white)
![VS Code](https://img.shields.io/badge/VS_Code-code--server-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)

</div>

---

> [!WARNING]
> **Aviso de Seguridad: Entorno Inseguro por Diseño**
> Para simplificar la puesta a punto y emular servidores bare-metal/VMs reales, los contenedores utilizan configuraciones intencionalmente permisivas:
> - Modo privilegiado activo (`privileged: true`).
> - Espacio de nombres `cgroup: host` compartido entre host y contenedores.
> - Subsistema `/sys/fs/cgroup` montado en modo lectura/escritura.
> - Integración directa con el socket de Docker.
> 
> **No exponga este laboratorio directamente a redes públicas ni lo utilice en entornos de producción.**

---

## Arquitectura del Sistema

```text
[ Navegador del Alumno ] ────────► http://IP_HOST:8443
            │
            ▼
┌────────────────────────────────────────────────────────────────────────┐
│ VM Host / Servidor Local (≥ 4 GB RAM)                                  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ ansible-control (VS Code Web + Ansible CLI)                      │  │
│  │ ├─ Interfaz: VS Code Server en puerto 8443                       │  │
│  │ ├─ Binarios: Ansible Core, ansible-lint, Python 3                │  │
│  │ └─ Clave Privada: ~/.ssh/id_rsa inyectada                        │  │
│  └──────────────────────────────────┬───────────────────────────────┘  │
│                                     │ Red Interna Docker: lab-net      │
│         ┌───────────────────────────┴───────────────────────┐          │
│         ▼                                                   ▼          │
│  ┌──────────────────────────────┐            ┌──────────────────────┐  │
│  │ ansible-ubuntu               │            │ ansible-rocky        │  │
│  │ ├─ Distribución: Ubuntu 24.04│            │ ├─ Distro: Rocky 9   │  │
│  │ ├─ Init / PID 1: Systemd     │            │ ├─ Init: Systemd     │  │
│  │ └─ Servicio: OpenSSH (:22)   │            │ └─ Servicio: SSH(:22)│  │
│  └──────────────────────────────┘            └──────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

* **Nodo de Control (`ansible-control`):** Estación central accesible vía web donde se redactan, prueban y ejecutan los playbooks.
* **Nodos Administrados (`ansible-ubuntu` y `ansible-rocky`):** Servidores objetivo heterogéneos (familias Debian y RHEL) con **Systemd como PID 1** para gestionar servicios del sistema (`systemctl`) en tiempo real.
* **Red Aislada (`lab-net`):** Resolución DNS automática por nombre de contenedor sobre el puerto SSH estándar (22).
* **Persistencia:** Montaje bind del directorio `./workspace` para evitar pérdida de datos durante reinicios.

---

## Estructura del Proyecto

```text
├── template/
│   ├── docker-compose.yaml   # Definición de servicios, volúmenes cgroups y redes
│   ├── Dockerfile.control    # Imagen del nodo maestro (code-server + Ansible)
│   ├── Dockerfile.ubuntu     # Imagen del nodo Ubuntu (OpenSSH + Systemd)
│   ├── Dockerfile.rocky      # Imagen del nodo Rocky Linux (OpenSSH + Systemd)
│   ├── id_rsa                # Clave privada SSH para el nodo de control
│   ├── id_rsa.pub            # Clave pública SSH autorizada en los nodos
│   └── workspace/            # Directorio persistente de trabajo
│       └── inventario.yaml   # Configuración de hosts y variables de conexión
```

---

## Requisitos del Sistema

* **Docker Engine** (v24.0 o superior) y **Docker Compose v2**.
* **Kernel Linux** con soporte para `cgroups v2` (`/sys/fs/cgroup`).
* **Procesador x86_64** con soporte para microarquitectura `x86-64-v2` o superior.

---

## Despliegue del Entorno

### Paso 1: Construir e iniciar los servicios

```bash
docker compose up -d --build
```

### Paso 2: Acceder a la interfaz web

Abra su navegador web e ingrese a la dirección: `http://localhost:8443` *(o la IP del host asignada)*.

* **Contraseña Web:** `ansible`
* **Contraseña `sudo` en terminal:** `ansible`

---

## Validación de Conectividad

Abra la terminal integrada en VS Code Web y ejecute el módulo de prueba:

```bash
cd ~/workspace
ansible nodos_lab -i inventario.yaml -m ping
```

**Resultado esperado:**

```json
ansible-ubuntu | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
ansible-rocky | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

---

## Parámetros de Autenticación y Acceso

| Nodo | Rol | Usuario SSH | Contraseña Sudo | Acceso / Puerto | Init System (PID 1) |
| --- | --- | --- | --- | --- | --- |
| **`ansible-control`** | Nodo Maestro | `abc` / `root` | `ansible` | `HTTP 8443` | `s6-overlay` |
| **`ansible-ubuntu`** | Nodo Gestionado | `ansible` | `ansible123` | `SSH 22` (interno) | `/lib/systemd/systemd` |
| **`ansible-rocky`** | Nodo Gestionado | `ansible` | `ansible123` | `SSH 22` (interno) | `/usr/sbin/init` |

---

## Comandos Operativos

* **Detener servicios:**
```bash
docker compose stop
```

* **Reanudar servicios:**
```bash
docker compose start
```

* **Eliminar contenedores y redes:**
```bash
docker compose down
```

* **Eliminar infraestructura y volúmenes persistentes:**
```bash
docker compose down -v
```

* **Monitorear registros del nodo de control:**
```bash
docker compose logs -f control-node
```
