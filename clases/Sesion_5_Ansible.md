# 🚀 Ansible desde Cero: Automatiza Linux y Servidores

**Instructor:** Cristian Adrian Diaz Garcia  
**Fecha:** 21 de agosto de 2026  
**Evento:** Cursos PIT - 10ma Edición (OTI UNI - Transformación Digital)

---

## 📑 Índice
1. [Roles en Ansible](#1-roles-en-ansible)
2. [Estructura de un Rol](#2-estructura-de-un-rol)
3. [Ansible Galaxy y Collections](#3-ansible-galaxy-y-collections)
4. [Monitoreo Automatizado (Prometheus & Node Exporter)](#4-monitoreo-automatizado-prometheus--node-exporter)
5. [Errores Frecuentes y Buenas Prácticas](#5-errores-frecuentes-y-buenas-prácticas)

---

## 1. Roles en Ansible

### ¿Qué son los Roles?
Un rol es una forma de empaquetar y organizar tareas, variables, manejadores (*handlers*), archivos y plantillas en una estructura de directorios estandarizada. 

**Ventajas principales:**
* **Reutilización:** Escribes la configuración una vez y la usas en múltiples playbooks o proyectos.
* **Organización modular:** Evita los "playbooks gigantes" (código espagueti) separando cada componente en carpetas estándar.

---

## 2. Estructura de un Rol

Un rol bien construido sigue una estructura de árbol precisa.

```text
<role_name>/
├── defaults/     # Variables con la prioridad más baja (fáciles de sobrescribir)
│   └── main.yml
├── files/        # Archivos estáticos que se copian tal cual (ej. imágenes, certs)
│   └── script.sh
├── handlers/     # Los disparadores (ej. reiniciar servicios)
│   └── main.yml
├── meta/         # Metadatos del rol (autor, dependencias)
│   └── main.yml
├── tasks/        # La lógica principal, los módulos a ejecutar
│   └── main.yml
├── templates/    # Archivos dinámicos Jinja2 (.j2)
│   └── config.j2
└── vars/         # Variables de alta prioridad (constantes internas)
    └── main.yml
```

### Dependencias entre roles (`meta/main.yml`)
Permiten que un rol ejecute automáticamente otros roles antes de sus propias tareas.
```yaml
# En el archivo meta/main.yml
---
dependencies:
  - role: common_docker
  - role: geerlingguy.pip
    vars:
      pip_install_packages:
        - name: docker
```
Esto automatiza de forma transparente los prerrequisitos manteniendo el playbook principal limpio.

---

## 3. Ansible Galaxy y Collections

### Ansible Galaxy
Es el repositorio público oficial y la herramienta de línea de comandos para descubrir, descargar y compartir contenido automatizado creado por la comunidad y gigantes tecnológicos (Red Hat, Cisco, AWS).

**Comandos Esenciales:**
* Buscar roles: `ansible-galaxy search docker`
* Ver detalles: `ansible-galaxy info geerlingguy.docker`
* Instalar un rol: `ansible-galaxy install geerlingguy.docker`

### El Archivo `requirements.yml`
En lugar de instalar roles uno por uno de forma manual, la mejor práctica es usar un archivo `requirements.yml` para gestionar las dependencias del proyecto de forma reproducible (similar a un `package.json`).

```yaml
# requirements.yml
roles:
  - name: geerlingguy.docker
    version: 6.1.0
  # Puedes instalar desde Git corporativo
  - src: git@gitlab.com:empresa/rol-interno.git
    name: rol_interno
    scm: git

collections:
  - name: community.general
    version: 8.1.0
```
**Instalación:** `ansible-galaxy install -r requirements.yml`

### Ansible Collections
Las *Collections* son un formato de empaquetado más moderno y grande que distribuye **roles, módulos y plugins** juntos. Ejemplos comunes:
* `community.general` (Módulos generales comunitarios)
* `amazon.aws` (Gestión completa de infraestructura AWS)
* `community.docker` (Gestión de contenedores y redes Docker)

---

## 4. Monitoreo Automatizado (Prometheus & Node Exporter)

Aprenderemos a desplegar un sistema de observabilidad. **Prometheus** utiliza un **Modelo Pull**: Prometheus consulta periódicamente a los servidores en el puerto HTTP (ej. 9100) donde escucha el **Node Exporter**.

### Rol Node_Exporter: Instalación (1/2)
```yaml
# tasks/main.yml
- name: Crear usuario del servicio
  ansible.builtin.user:
    name: node_exporter
    system: true
    shell: /usr/sbin/nologin

- name: Publicar unidad systemd
  ansible.builtin.template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
  notify: Reiniciar node exporter
```

### Rol Node_Exporter: Servicio Systemd (2/2)
**El Template (`node_exporter.service.j2`):**
```ini
[Unit]
Description=Prometheus Node Exporter
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:{{ node_exporter_port }}
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Configuración Dinámica de Prometheus
En el servidor central, podemos configurar Prometheus para que reconozca los nuevos nodos automáticamente leyendo el inventario de Ansible gracias a Jinja2:

```yaml
# Fragmento del template prometheus.yml.j2
scrape_configs:
  - job_name: "linux_nodes"
    static_configs:
      - targets:
        {% for host in groups['linux'] %}
        - "{{ hostvars[host].ansible_host }}:9100"
        {% endfor %}
```
*Ventaja:* Al añadir un servidor al inventario y ejecutar el playbook, se agrega inmediatamente a la vigilancia de Prometheus.

---

## 5. Errores Frecuentes y Buenas Prácticas

| Problema | Causa Habitual | Práctica Recomendada |
| :--- | :--- | :--- |
| **Rol monolítico** | Demasiadas responsabilidades en un solo rol. | Separar roles por servicio o capacidad específica. |
| **Variables rígidas** | Uso de valores públicos incrustados dentro de `vars/`. | Exponer variables personalizables en `defaults/`. |
| **Reinicios en cada corrida** | Uso de tareas directas como `service: restarted`. | Aplicar siempre notificaciones (`notify`) y `handlers`. |
| **Galaxy impredecible** | Versiones de roles no fijadas. | Mantener un archivo `requirements.yml` con versiones ancladas. |
| **Target Prometheus DOWN** | Servicio apagado, firewall bloqueando, o IP incorrecta. | Validar estado del systemd, abrir el puerto 9100 e inspeccionar endpoint. |

---

*Presentación creada por Cristian Adrian Diaz Garcia. ¡Gracias por participar!*
