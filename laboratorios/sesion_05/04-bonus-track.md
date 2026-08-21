# Laboratorio 00: Despliegue Estructurado con Ansible Roles y Dependencia de Roles

Este laboratorio marca un salto importante en tu aprendizaje. Dejaremos de usar Playbooks monolíticos y pasaremos a utilizar **Ansible Roles**. Los roles te permiten dividir configuraciones complejas en piezas modulares, reutilizables y altamente estructuradas.

En este ejercicio, crearemos un rol llamado `npm_stack` que desplegará Nginx Proxy Manager junto con su base de datos MariaDB utilizando contenedores Docker.

---

## 1. Inicialización con Ansible Galaxy

En lugar de crear carpetas manualmente, usaremos la herramienta oficial para generar el "esqueleto" del rol con todos los archivos necesarios. Abre tu terminal en tu máquina de control y ejecuta:

```bash
# 1. Crea la carpeta de tu proyecto y entra en ella
mkdir -p proyecto/roles
cd proyecto/

# 2. Genera la estructura oficial del rol
ansible-galaxy role init roles/npm_stack

```

*Galaxy acaba de crear las carpetas `defaults`, `vars`, `tasks`, `handlers`, entre otras, junto con sus respectivos archivos `main.yml` vacíos.*

---

## 2. Preparación del Entorno (Nodos con Docker-in-Docker / DinD)

Dado que tus nodos de Ansible se ejecutarán como contenedores y a su vez alojarán otros contenedores (Nginx Proxy Manager y MariaDB), necesitamos preparar una imagen personalizada y configurar correctamente los privilegios.

### Paso A: Crear el Dockerfile para los nodos (`Dockerfile.ubuntu-dind`)

Crea este archivo en la raíz de tu entorno (donde tienes tu `docker-compose.yml`). Esta imagen instala el servicio de Docker dentro de la imagen base de Ansible:

```dockerfile
FROM geerlingguy/docker-ubuntu2404-ansible:latest

# Instalar OpenSSH Server, Sudo, Docker y utilidades
RUN apt-get update && \
    apt-get install -y openssh-server sudo docker.io containerd iptables && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Crear usuario 'ansible', asignar contraseña y grupos (sudo y docker)
RUN useradd -m -s /bin/bash -u 1001 ansible && \
    echo 'ansible:password' | chpasswd && \
    usermod -aG sudo,docker ansible

# Configurar sudoers sin contraseña para ansible (opcional pero recomendado para automatización)
RUN echo 'ansible ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Preparar directorio .ssh e inyectar la clave pública con permisos estrictos
RUN mkdir -p /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh

COPY --chown=ansible:ansible id_rsa.pub /home/ansible/.ssh/authorized_keys

RUN chmod 600 /home/ansible/.ssh/authorized_keys && \
    chown -R ansible:ansible /home/ansible/.ssh

# Configurar runtime de SSH y habilitar servicios en systemd
RUN mkdir -p /var/run/sshd && \
    systemctl enable ssh && \
    systemctl enable docker

EXPOSE 22

CMD ["/lib/systemd/systemd"]

```

### Paso B: Configurar el Docker Compose (En tu máquina host)

Asegúrate de que tu archivo `docker-compose.yml` construya usando el nuevo Dockerfile, declare el nodo con privilegios elevados (`privileged: true`) y mapee los `cgroups`:

```yaml
  ubuntu-node1:
    build:
      context: .
      dockerfile: Dockerfile.ubuntu-dind
    container_name: ubuntu-node1
    privileged: true
    cgroup: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - ubuntu-node1-docker:/var/lib/docker
    ports:
      - "8080:80"
      - "8081:81"
      - "8082:443"
    networks:
      - lab-net

volumes:
  ubuntu-node1-docker:

```

### Paso C: Ajustar el Storage Driver (Dentro del Nodo)

Una vez que levantes tu entorno con `docker compose up -d`, ingresa al nodo. Incluso con el modo privilegiado activo, el driver de almacenamiento `overlay2` anidado puede fallar. Aplica esta solución dentro del contenedor `ubuntu-node1`:

1. Crea o edita el archivo `/etc/docker/daemon.json` en tu nodo de prueba:
```json
{
  "storage-driver": "vfs"
}

```


2. Reinicia el servicio de Docker en el nodo para aplicar el cambio:
```bash
sudo systemctl restart docker

```



---

## 3. Variables y Manejadores del Rol (Defaults, Vars, Handlers)

Volviendo a nuestro proyecto de Ansible (`proyecto/`), vamos a editar los archivos que Galaxy generó por nosotros.

**A. Edita `roles/npm_stack/defaults/main.yml` (Variables generales):**

```yaml
---
npm_docker_network: "npm_network"
mariadb_container_name: "npm_db"
mariadb_image: "mariadb:11.4"
mariadb_data_dir: "/opt/npm/db"
mariadb_database: "npm"
mariadb_user: "npm"
npm_container_name: "nginx_proxy_manager"
npm_image: "jc21/nginx-proxy-manager:latest"
npm_data_dir: "/opt/npm/data"
npm_letsencrypt_dir: "/opt/npm/letsencrypt"

```

**B. Edita `roles/npm_stack/vars/main.yml` (Secretos y constantes):**

```yaml
---
mariadb_root_password: "RootAdminPassword123"
mariadb_password: "NpmAppPassword456"
container_restart_policy: "unless-stopped"

```

**C. Edita `roles/npm_stack/handlers/main.yml` (Reinicio de servicios):**

```yaml
---
- name: Reiniciar MariaDB
  community.docker.docker_container:
    name: "{{ mariadb_container_name }}"
    state: started
    restart: true

- name: Reiniciar NPM
  community.docker.docker_container:
    name: "{{ npm_container_name }}"
    state: started
    restart: true

```

---

## 4. Tareas Principales del Rol (Tasks)

Este archivo dictará el orden exacto del despliegue en tus nodos.

**Edita `roles/npm_stack/tasks/main.yml`:**

```yaml
---
- name: Instalar dependencias de Python para Docker
  ansible.builtin.apt:
    name: [python3-requests, python3-docker]
    state: present
    update_cache: true

- name: Crear directorios para persistencia de datos
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - "{{ mariadb_data_dir }}"
    - "{{ npm_data_dir }}"
    - "{{ npm_letsencrypt_dir }}"

- name: Crear red bridge para NPM
  community.docker.docker_network:
    name: "{{ npm_docker_network }}"
    state: present

- name: Desplegar contenedor MariaDB
  community.docker.docker_container:
    name: "{{ mariadb_container_name }}"
    image: "{{ mariadb_image }}"
    state: started
    restart_policy: "{{ container_restart_policy }}"
    networks: [{ name: "{{ npm_docker_network }}" }]
    volumes: ["{{ mariadb_data_dir }}:/var/lib/mysql"]
    env:
      MYSQL_ROOT_PASSWORD: "{{ mariadb_root_password }}"
      MYSQL_DATABASE: "{{ mariadb_database }}"
      MYSQL_USER: "{{ mariadb_user }}"
      MYSQL_PASSWORD: "{{ mariadb_password }}"
  notify: Reiniciar MariaDB

- name: Desplegar contenedor Nginx Proxy Manager
  community.docker.docker_container:
    name: "{{ npm_container_name }}"
    image: "{{ npm_image }}"
    state: started
    restart_policy: "{{ container_restart_policy }}"
    networks: [{ name: "{{ npm_docker_network }}" }]
    ports: ["80:80", "81:81", "443:443"]
    volumes:
      - "{{ npm_data_dir }}:/data"
      - "{{ npm_letsencrypt_dir }}:/etc/letsencrypt"
    env:
      DB_MYSQL_HOST: "{{ mariadb_container_name }}"
      DB_MYSQL_PORT: "3306"
      DB_MYSQL_USER: "{{ mariadb_user }}"
      DB_MYSQL_PASSWORD: "{{ mariadb_password }}"
      DB_MYSQL_NAME: "{{ mariadb_database }}"
  notify: Reiniciar NPM

```

---

## 5. Archivos Raíz y Ejecución

Sube a la raíz del proyecto (`proyecto/`) y crea los dos archivos finales que llamarán a tu rol.

* **Archivo `site.yml`:**
```yaml
---
- hosts: ubuntu
  become: true
  roles:
    - role: npm_stack
```

# Dependencia de Roles

Este laboratorio es muy corto y tiene un único objetivo: demostrar cómo puedes hacer que un Rol necesite de otro Rol para funcionar.

En la vida real, esto es útil cuando tienes un rol complejo (como instalar un sitio web) que siempre requiere que primero se ejecute un rol básico (como instalar un firewall o un usuario administrador). En lugar de acordarte de poner ambos en tu Playbook, Ansible lo hace por ti a través del archivo `meta/main.yml`.

Para mantenerlo súper simple y a prueba de errores, usaremos el módulo `debug` para simular las acciones.

## 1. Creación de la Estructura

En tu máquina de control (dentro de tu carpeta `proyecto/`), genera los dos roles: el rol "padre" (la aplicación) y el rol "hijo" (la base necesaria).

```bash
# Crea la estructura para ambos roles
ansible-galaxy role init roles/rol_base
ansible-galaxy role init roles/rol_app

```

---

## 2. Configurar el Rol "Base" (El hijo)

Este rol simulará la preparación del servidor.

**Edita `roles/rol_base/tasks/main.yml`:**

```yaml
---
- name: Tarea del Rol Base
  ansible.builtin.debug:
    msg: "[PASO 1] Ejecutando el rol base: Preparando el servidor..."

```

---

## 3. Configurar el Rol "App" (El padre)

Aquí es donde ocurre la magia. Primero, le diremos a este rol que **depende** del `rol_base`.

**A. Edita `roles/rol_app/meta/main.yml`:**
Busca al final del archivo la sección `dependencies: []` y modifícala para que quede así:

```yaml
---
dependencies:
  - role: rol_base

```

**B. Edita `roles/rol_app/tasks/main.yml`:**

```yaml
---
- name: Tarea del Rol App
  ansible.builtin.debug:
    msg: "[PASO 2] Ejecutando el rol app: Instalando la aplicacion final..."

```

---

## 4. El Playbook Principal (`site.yml`)

Sube a la raíz de tu proyecto y edita tu archivo `site.yml`. Presta mucha atención: **solo vamos a invocar al `rol_app**`.

```yaml
---
- hosts: ubuntu-node1
  gather_facts: false
  roles:
    - role: rol_app

```

---

## 5. Prueba Práctica y Visual

Ejecuta tu playbook apuntando a tu inventario (o a cualquier servidor de prueba que tengas configurado):

```bash
ansible-playbook site.yml

```

### Lo que verás en la consola:

```bash
PLAY [all] *************************************************************************************************************

TASK [rol_base : Tarea del Rol Base] ***********************************************************************************
ok: [ubuntu-node1] => {
    "msg": "[PASO 1] Ejecutando el rol base: Preparando el servidor..."
}

TASK [rol_app : Tarea del Rol App] *************************************************************************************
ok: [ubuntu-node1] => {
    "msg": "[PASO 2] Ejecutando el rol app: Instalando la aplicacion final..."
}

PLAY RECAP *************************************************************************************************************
ubuntu-node1               : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```

### Análisis:

Aunque en tu `site.yml` tú solo escribiste `- role: rol_app`, Ansible leyó la carpeta `meta/main.yml` de ese rol, detectó que dependía de `rol_base`, y automáticamente detuvo la ejecución, buscó el rol base, lo ejecutó primero, y luego continuó con el rol de la aplicación.

Esta es la forma correcta de modularizar infraestructura compleja sin ensuciar tus Playbooks principales.
