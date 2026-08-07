---
## Preparación de Nodos Administrados para Ansible

### 1. Actualizar los repositorios y actualizar paquetes
Usa el gestor de paquetes `dnf (RetHat)` o `apt (Ubuntu)` para actualizar los repositorios y paquetes del servidor:

* **En RedHat**
    ```bash
    dnf update && dnf upgrade -y
    ```
    
* **En Ubuntu**
    ```bash
    apt update && apt upgrade -y
    ```

### 2. Instalar el servidor OpenSSH
Usa el gestor de paquetes `dnf (RetHat)` o `apt (Ubuntu)` instalar el paquete `ssh` del servidor:

* **En RedHat**
    ```bash
    sudo dnf install openssh-server -y
    ```
    
* **En Ubuntu**
    ```bash
    sudo apt install openssh-server -y
    ```

### 3. Generar las llaves de host necesarias
Las imágenes mínimas de contenedores a menudo no traen las llaves criptográficas requeridas, lo que provoca un error al iniciar. Generalas ejecutando:

```bash
sudo ssh-keygen -A
```

### 4. Iniciar el servicio SSH
**Dentro de un contenedor Docker** (donde `systemctl` no está disponible), puedes iniciar el demonio SSH manualmente en segundo plano:
```bash
/usr/sbin/sshd
```

> [\!TIP]
> Si estás en una máquina virtual o servidor físico con systemd usa: **sudo systemctl start sshd** y **sudo systemctl enable sshd**

## Creacion de usuario para ansible

### 1. Instalar el servidor OpenSSH
Usa el gestor de paquetes `dnf (RetHat)` o `apt (Ubuntu)` instalar el paquete `sudo` del servidor:

* **En RedHat**
    ```bash
    sudo dnf install sudo -y
    ```
    
* **En Ubuntu**
    ```bash
    sudo apt install sudo -y
    ```

### 2. Crear el usuario
Utiliza el comando `useradd` con la opción `-m` (para que cree automáticamente su directorio personal o *home*) y `-s /bin/bash` (para asignarle la terminal bash por defecto):

```bash
useradd -m -s /bin/bash ansible
```

### 3. Asignar una contraseña
Establece la contraseña (en este ejemplo, `password`) para el usuario recién creado:

```bash
passwd ansible
```

### 4. Dar privilegios de administrador (Sudo)

Para que este usuario pueda ejecutar tareas administrativas que requieran `sudo` en los nodos:

* **En Debian:**
    ```bash
    usermod -aG sudo ansible
    ```

* **En CentOS:**
    ```bash
    usermod -aG wheel ansible
    ```
