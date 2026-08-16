# Laboratorio 01: Configuración de Nodos Administrados y Preparación para Ansible

Este laboratorio tiene como objetivo principal preparar los nodos administrados (tanto basados en Red Hat como en Ubuntu) para que Ansible pueda conectarse de forma segura mediante SSH y elevar privilegios con `sudo`.

---

## 1. Objetivos del Laboratorio

* Configurar el servidor OpenSSH en los nodos administrados.
* Crear y configurar un usuario dedicado (`ansible`) para la automatización.
* Otorgar privilegios de administrador mediante `sudo` (grupos `wheel` o `sudo`).

---

## 2. Despliegue del entorno con Docker Compose
Utiliza los comandos de Docker Compose para descargar las imágenes y levantar los contenedores en segundo plano (*detached mode*):

### Crear el archivo docker-compose.yaml
En el servidor linux crear el archivo `docker-compose.yaml` y añadir este contenido

```yaml
services:
  # ----------------------------------------------------
  # Nodo de Control (Code-Server)
  # ----------------------------------------------------
  control-node:
    image: linuxserver/code-server:latest
    container_name: ansible-control
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Lima
      - PASSWORD=ansible
      - SUDO_PASSWORD=ansible
    volumes:
      - ./workspace:/config/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "8443:8443"
    networks:
      - ansible-net
    restart: unless-stopped
  # ----------------------------------------------------
  # Nodo 1: ubuntu 22.04 (systemd + python3)
  # ----------------------------------------------------
  ubuntu-node:
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    container_name: ansible-ubuntu
    privileged: true
    cgroup: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: /lib/systemd/systemd
    networks:
      - ansible-net

  # ----------------------------------------------------
  # Nodo 2: Rocky Linux 9 (systemd + python3)
  # ----------------------------------------------------
  rocky-node:
    image: geerlingguy/docker-rockylinux9-ansible:latest
    container_name: ansible-rocky
    privileged: true
    cgroup: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    command: /usr/sbin/init
    networks:
      - ansible-net

networks:
  ansible-net:
    driver: bridge
```

### Crear e iniciar los contenedores:
```bash
docker compose up -d
```

### Verificar que los contenedores están en ejecución:
```bash
docker compose ps
```

### Ingresar a la terminal interactiva de un contenedor:
```bash
docker exec -it <nombre_o_id_del_contenedor> bash
```

> [\!TIP]
> Si la imagen del contenedor es muy liviana (como `Alpine Linux`) y no tiene `bash`, sustitúyelo por `sh`

## 3. Preparación de Nodos Administrados y SSH

### 1. Actualizar los repositorios y paquetes
Usa el gestor de paquetes de tu distribución para actualizar los paquetes del servidor:

* **En Red Hat / Rocky Linux:**
```bash
dnf update && dnf upgrade -y
```

* **En Ubuntu / Debian:**
```bash
apt update && apt upgrade -y
```

### 2. Instalar el servidor OpenSSH y Sudo
Instala el servidor SSH en el servidor:

* **En Red Hat / Rocky Linux:**
```bash
dnf install openssh-server -y
```

* **En Ubuntu / Debian:**
```bash
apt install openssh-server -y
```

### 3. Generar las llaves de host necesarias
Las imágenes mínimas de contenedores a menudo no traen las llaves criptográficas requeridas, lo que provoca un error al iniciar. Genéralas ejecutando:

```bash
ssh-keygen -A
```

### 4. Iniciar el servicio SSH
**Dentro de un contenedor Docker**, debes de iniciar el demonio SSH manualmente ejecutando:

```bash
systemctl enable ssh
systemctl start ssh
```

### 5. Validar el servicio SSH
Ejecutar el comando:

```bash
systemctl status ssh
```
```bash
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-08-16 00:37:04 UTC; 1s ago
       Docs: man:sshd(8)
             man:sshd_config(5)
    Process: 888 ExecStartPre=/usr/sbin/sshd -t (code=exited, status=0/SUCCESS)
   Main PID: 889 (sshd)
      Tasks: 1 (limit: 259)
     Memory: 1.7M
        CPU: 44ms
     CGroup: /system.slice/docker-acff6d0793e5de1e1e882555a96ae05413282f19af26103f963e987d91f06708.scope/system.slice/ssh.service
             └─889 "sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups"

Aug 16 00:37:04 acff6d0793e5 systemd[1]: Starting OpenBSD Secure Shell server...
Aug 16 00:37:04 acff6d0793e5 sshd[889]: Server listening on 0.0.0.0 port 22.
Aug 16 00:37:04 acff6d0793e5 sshd[889]: Server listening on :: port 22.
Aug 16 00:37:04 acff6d0793e5 systemd[1]: Started OpenBSD Secure Shell server.
```

---

## 4. Creación y Configuración del Usuario para Ansible

### 1. Crear el usuario
Utiliza el comando `useradd` con la opción `-m` (para que cree automáticamente su directorio personal o *home*) y `-s /bin/bash` (para asignarle la terminal bash por defecto):

```bash
useradd -m -s /bin/bash ansible
```

### 2. Asignar una contraseña
Establece una contraseña segura (por ejemplo, `password`) para el usuario recién creado:

```bash
passwd ansible
```

### 3. Dar privilegios de administrador (`sudo`)
Para que este usuario pueda ejecutar tareas administrativas que requieran privilegios elevados en los nodos:

* **En Red Hat / Rocky Linux:**
```bash
usermod -aG wheel ansible
```

* **En Ubuntu / Debian:**
```bash
usermod -aG sudo ansible
```

## 5. Instalación de Ansible
Para instalar Ansible en el nodo de control (`ansible-control`), ejecuta los siguientes comandos:

* **En Ubuntu / Debian:**
```bash
sudo apt install -y ansible
```

### Verificación
Una vez completada la instalación, confirma que Ansible quedó instalado correctamente comprobando su versión:
```bash
ansible --version
```
