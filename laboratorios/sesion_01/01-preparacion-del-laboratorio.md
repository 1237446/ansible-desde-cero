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
Instala el servidor SSH y la herramienta de elevación de privilegios en el servidor:

* **En Red Hat / Rocky Linux:**
```bash
dnf install openssh-server sudo -y
```

* **En Ubuntu / Debian:**
```bash
apt install openssh-server sudo -y
```

### 3. Generar las llaves de host necesarias
Las imágenes mínimas de contenedores a menudo no traen las llaves criptográficas requeridas, lo que provoca un error al iniciar. Genéralas ejecutando:

```bash
ssh-keygen -A
```

### 4. Iniciar el servicio SSH
**Dentro de un contenedor Docker** (donde `systemctl` no está disponible), puedes iniciar el demonio SSH manualmente ejecutando:

```bash
/usr/sbin/sshd
```

> [!TIP]
> Si estás en una máquina virtual o servidor físico con systemd, usa: `sudo systemctl start sshd` y `sudo systemctl enable sshd`.

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
