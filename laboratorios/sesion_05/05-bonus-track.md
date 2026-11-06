# Laboratorio 01: Monitoreo con Prometheus y Grafana usando Roles, Templates y Docker Compose

En el laboratorio anterior aprendiste a estructurar un despliegue con **Ansible Roles** y a encadenar roles mediante **dependencias**. En este ejercicio daremos un paso más e incorporaremos dos conceptos nuevos:

- **Templates (Jinja2):** archivos de configuración que Ansible genera dinámicamente a partir de variables.
- **Docker Compose desde Ansible:** en lugar de crear cada contenedor por separado, describiremos el stack completo en un `docker-compose.yml` y lo levantaremos con el módulo `community.docker.docker_compose_v2`.

El objetivo es desplegar un stack de monitoreo compuesto por **Prometheus** (recolección de métricas) y **Grafana** (visualización), ya conectados entre sí y listos para usar.

---

## 0. Requisitos Previos

Antes de comenzar, verifica lo siguiente en tu máquina de control:

```bash
# 1. Los nodos Ubuntu responden
ansible ubuntu -m ping

# 2. Docker está instalado y funcionando en los nodos
ansible ubuntu -m command -a "docker --version" -b

# 3. La colección de Docker para Ansible está instalada
ansible-galaxy collection list | grep community.docker
# Si no aparece:
ansible-galaxy collection install community.docker
```

> **Nota:** Si tus nodos son contenedores (DinD o Sysbox) y Docker anidado falla con el driver `overlay2`, aplica la configuración del driver `vfs` vista en el Laboratorio 00.

---

## 1. Inicialización con Ansible Galaxy

Trabajaremos con **dos roles**:

| Rol | Función |
|---|---|
| `docker_base` | Rol "hijo": verifica que Docker esté listo e instala las librerías de Python que necesita Ansible. |
| `monitoring_stack` | Rol "padre": genera las configuraciones y levanta Prometheus + Grafana. Depende de `docker_base`. |

Desde la carpeta de tu proyecto, genera la estructura de ambos roles:

```bash
cd proyecto/

ansible-galaxy role init roles/docker_base
ansible-galaxy role init roles/monitoring_stack
```

*Galaxy creará en cada rol las carpetas `defaults`, `vars`, `tasks`, `handlers`, `meta`, `templates`, entre otras.*

---

## 2. Rol `docker_base` (El hijo)

Este rol garantiza que el nodo está preparado antes de desplegar cualquier contenedor. Si Docker no está instalado, detiene la ejecución con un mensaje claro en lugar de fallar más adelante con un error confuso.

**Edita `roles/docker_base/tasks/main.yml`:**

```yaml
---
- name: Instalar dependencias de Python para Docker
  ansible.builtin.apt:
    name: [python3-requests, python3-docker]
    state: present
    update_cache: true

- name: Comprobar que Docker responde
  ansible.builtin.command: docker info
  register: docker_check
  changed_when: false
  failed_when: false

- name: Detener la ejecución si Docker no está disponible
  ansible.builtin.fail:
    msg: "Docker no está instalado o no está corriendo en {{ inventory_hostname }}. Instálalo antes de continuar."
  when: docker_check.rc != 0
```

---

## 3. Rol `monitoring_stack` (El padre)

### A. Dependencia de roles: `roles/monitoring_stack/meta/main.yml`

Busca la sección `dependencies: []` al final del archivo y modifícala:

```yaml
dependencies:
  - role: docker_base
```

*Con esto, cada vez que se invoque `monitoring_stack`, Ansible ejecutará primero `docker_base` de forma automática.*

### B. Variables generales: `roles/monitoring_stack/defaults/main.yml`

```yaml
---
stack_dir: "/opt/monitoreo"

prometheus_image: "docker.io/prom/prometheus:latest"
prometheus_container_name: "prometheus"
prometheus_port: 9090
prometheus_scrape_interval: "15s"

grafana_image: "docker.io/grafana/grafana:latest"
grafana_container_name: "grafana"
grafana_port: 3000
grafana_admin_user: "admin"
```

### C. Secretos y constantes: `roles/monitoring_stack/vars/main.yml`

```yaml
---
grafana_admin_password: "GrafanaAdmin123"
container_restart_policy: "unless-stopped"
```

> **Recuerda:** las variables en `defaults/` tienen la prioridad más baja (el usuario del rol puede sobrescribirlas fácilmente), mientras que las de `vars/` tienen prioridad alta y se usan para valores que el rol considera fijos.

### D. Templates: `roles/monitoring_stack/templates/`

Los templates son archivos con extensión `.j2` donde Ansible reemplaza cada `{{ variable }}` por su valor antes de copiarlo al nodo. Crea los tres archivos siguientes dentro de la carpeta `templates/`.

**1. `prometheus.yml.j2`** (configuración de Prometheus):

```yaml
global:
  scrape_interval: {{ prometheus_scrape_interval }}

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
```

**2. `datasource.yml.j2`** (conecta Grafana con Prometheus automáticamente):

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

*Observa que la URL usa `prometheus` como nombre de host: dentro de la red que crea Compose, cada servicio es accesible por su nombre.*

**3. `docker-compose.yml.j2`** (definición del stack):

```yaml
services:
  prometheus:
    image: "{{ prometheus_image }}"
    container_name: "{{ prometheus_container_name }}"
    restart: "{{ container_restart_policy }}"
    ports:
      - "{{ prometheus_port }}:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus

  grafana:
    image: "{{ grafana_image }}"
    container_name: "{{ grafana_container_name }}"
    restart: "{{ container_restart_policy }}"
    ports:
      - "{{ grafana_port }}:3000"
    environment:
      GF_SECURITY_ADMIN_USER: "{{ grafana_admin_user }}"
      GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  prometheus_data:
  grafana_data:
```

### E. Manejadores: `roles/monitoring_stack/handlers/main.yml`

Si cambia la configuración de un servicio, solo se reinicia ese servicio (no todo el stack):

```yaml
---
- name: Reiniciar Prometheus
  community.docker.docker_compose_v2:
    project_src: "{{ stack_dir }}"
    services: [prometheus]
    state: restarted

- name: Reiniciar Grafana
  community.docker.docker_compose_v2:
    project_src: "{{ stack_dir }}"
    services: [grafana]
    state: restarted
```

### F. Tareas principales: `roles/monitoring_stack/tasks/main.yml`

```yaml
---
- name: Crear directorios del stack
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - "{{ stack_dir }}"
    - "{{ stack_dir }}/prometheus"
    - "{{ stack_dir }}/grafana/provisioning/datasources"

- name: Generar configuración de Prometheus
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: "{{ stack_dir }}/prometheus/prometheus.yml"
    mode: "0644"
  notify: Reiniciar Prometheus

- name: Generar datasource de Grafana
  ansible.builtin.template:
    src: datasource.yml.j2
    dest: "{{ stack_dir }}/grafana/provisioning/datasources/prometheus.yml"
    mode: "0644"
  notify: Reiniciar Grafana

- name: Generar docker-compose.yml
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: "{{ stack_dir }}/docker-compose.yml"
    mode: "0644"

- name: Levantar el stack con Docker Compose
  community.docker.docker_compose_v2:
    project_src: "{{ stack_dir }}"
    state: present

- name: Mostrar URLs de acceso
  ansible.builtin.debug:
    msg:
      - "Prometheus: http://{{ ansible_facts['default_ipv4']['address'] }}:{{ prometheus_port }}"
      - "Grafana:    http://{{ ansible_facts['default_ipv4']['address'] }}:{{ grafana_port }}"
```

> **¿Por qué `template` y no `copy`?** El módulo `copy` transfiere el archivo tal cual. El módulo `template` primero procesa las variables Jinja2 y luego lo copia. Si mañana quieres cambiar el puerto o la imagen, solo modificas `defaults/main.yml`.

---

## 4. Archivo Raíz: `site.yml`

En la raíz de `proyecto/`, crea (o reemplaza) el playbook principal. Igual que en el laboratorio de dependencias, **solo invocamos al rol padre**:

```yaml
---
- hosts: ubuntu
  become: true
  gather_facts: true
  roles:
    - role: monitoring_stack
```

La estructura final del proyecto debe verse así (se omiten carpetas vacías):

```
proyecto/
├── site.yml
└── roles/
    ├── docker_base/
    │   └── tasks/main.yml
    └── monitoring_stack/
        ├── defaults/main.yml
        ├── handlers/main.yml
        ├── meta/main.yml
        ├── tasks/main.yml
        ├── templates/
        │   ├── datasource.yml.j2
        │   ├── docker-compose.yml.j2
        │   └── prometheus.yml.j2
        └── vars/main.yml
```

---

## 5. Ejecución

```bash
ansible-playbook site.yml
```

### Lo que verás en la consola (resumido):

```bash
PLAY [ubuntu] **********************************************************************

TASK [docker_base : Instalar dependencias de Python para Docker] *******************
ok: [nodo-ubuntu]

TASK [docker_base : Comprobar que Docker responde] *********************************
ok: [nodo-ubuntu]

TASK [docker_base : Detener la ejecución si Docker no está disponible] *************
skipping: [nodo-ubuntu]

TASK [monitoring_stack : Crear directorios del stack] ******************************
changed: [nodo-ubuntu] => (item=/opt/monitoreo)
...

TASK [monitoring_stack : Levantar el stack con Docker Compose] *********************
changed: [nodo-ubuntu]

RUNNING HANDLER [monitoring_stack : Reiniciar Prometheus] **************************
changed: [nodo-ubuntu]

RUNNING HANDLER [monitoring_stack : Reiniciar Grafana] *****************************
changed: [nodo-ubuntu]
```

*Observa que las tareas de `docker_base` aparecen **antes** que las de `monitoring_stack` aunque no lo pusiste en el `site.yml`: es la dependencia definida en `meta/main.yml` en acción.*

> La primera vez los handlers se ejecutan porque los templates se acaban de crear. Es normal y no causa problemas.

---

## 6. Verificación

**A. Desde la máquina de control:**

```bash
# Contenedores corriendo en los nodos
ansible ubuntu -m command -a "docker compose -f /opt/monitoreo/docker-compose.yml ps" -b

# Salud de Prometheus (debe responder "Prometheus Server is Healthy.")
ansible ubuntu -m uri -a "url=http://127.0.0.1:9090/-/healthy return_content=true"

# Salud de Grafana (debe responder con "database": "ok")
ansible ubuntu -m uri -a "url=http://127.0.0.1:3000/api/health return_content=true"
```

**B. Desde el navegador:**

1. Abre Prometheus en `http://<IP-del-nodo>:9090` → menú **Status → Targets**. El target `prometheus` debe aparecer en estado **UP**.
2. Abre Grafana en `http://<IP-del-nodo>:3000` e inicia sesión con `admin` / `GrafanaAdmin123`.
3. Ve a **Connections → Data sources**: verás `Prometheus` ya configurado (gracias al template `datasource.yml.j2`).
4. Ve a **Explore**, selecciona la fuente `Prometheus`, escribe la consulta `up` y pulsa **Run query**. Deberías ver el valor `1`.

> **Nota:** Si tus nodos son contenedores, recuerda publicar los puertos 9090 y 3000 en el `docker-compose.yml` del host o acceder desde una máquina conectada a la misma red del laboratorio.

---

## 7. Prueba de Idempotencia y Handlers

**A. Idempotencia:** ejecuta el playbook una segunda vez sin cambiar nada.

```bash
ansible-playbook site.yml
```

El `PLAY RECAP` debe mostrar `changed=0` y **ningún handler** debe ejecutarse.

**B. Handler selectivo:** cambia el intervalo de recolección en `roles/monitoring_stack/defaults/main.yml`:

```yaml
prometheus_scrape_interval: "5s"
```

Ejecuta de nuevo el playbook y observa:

- Solo la tarea `Generar configuración de Prometheus` aparece como `changed`.
- Solo se ejecuta el handler **Reiniciar Prometheus**. Grafana no se toca.

Comprueba el cambio en **Status → Configuration** dentro de Prometheus.

---

## 8. Retos Opcionales

1. **Sobrescribir variables sin tocar el rol:** cambia el puerto de Grafana a `3001` declarando la variable a nivel de play en el `site.yml`:
   ```yaml
   - hosts: ubuntu
     become: true
     gather_facts: true
     vars:
       grafana_port: 3001
     roles:
       - role: monitoring_stack
   ```
   Ahora intenta lo mismo con `grafana_admin_password`. ¿Por qué el puerto cambia pero la contraseña **no**? *(Pista: las variables del play tienen más prioridad que `defaults/` del rol, pero menos que `vars/` del rol.)*

2. **Agregar Node Exporter:** añade un tercer servicio `docker.io/prom/node-exporter:latest` al template de Compose y un nuevo `job_name` en `prometheus.yml.j2` con el target `node-exporter:9100`. Verifica que aparece como **UP** en **Status → Targets**.

3. **Versión con Podman:** crea un rol `monitoring_stack_podman` para los nodos Rocky que reutilice los mismos templates pero levante el stack con `podman-compose up -d` mediante `ansible.builtin.command`. ¿Qué módulo de Docker no tiene equivalente en Podman?

---

## Análisis

En este laboratorio combinaste tres piezas clave de la automatización profesional:

- **Roles con dependencias:** `monitoring_stack` no tiene que preocuparse por preparar el nodo; delega esa responsabilidad en `docker_base`, que además puedes reutilizar en cualquier otro rol que use Docker.
- **Templates:** las configuraciones dejaron de ser texto fijo y pasaron a depender de variables. Un mismo rol sirve para entornos distintos solo cambiando valores.
- **Handlers selectivos:** los servicios se reinician únicamente cuando su configuración cambia, y solo el servicio afectado. Esto evita cortes innecesarios en producción.
