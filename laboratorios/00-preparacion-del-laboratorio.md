# Laboratorio 00: Preparacion del Laboratorio Ansible
En este laboratorio y en los siguientes trabajaremos con **Docker**. Para garantizar la estabilidad y contar con la versión más reciente, realizaremos la instalación en Ubuntu mediante el **repositorio oficial**.

### Paso 1: Actualizar el sistema e instalar dependencias
Actualiza la lista de paquetes del sistema e instala las herramientas requeridas para gestionar repositorios mediante HTTPS:
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
```

### Paso 2: Agregar la clave GPG oficial de Docker
Crea el directorio de claves de seguridad e importa la clave criptográfica oficial de Docker para validar la autenticidad de los paquetes:
```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### Paso 3: Añadir el repositorio oficial a APT
Registra la fuente del repositorio de Docker en la configuración de fuentes de tu sistema:
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Paso 4: Instalar Docker Engine y Docker Compose
Sincroniza nuevamente el índice de paquetes e instala el motor de Docker, la interfaz de línea de comandos (CLI) y el complemento de Compose:
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Paso 5: Verificar la instalación
Ejecuta el contenedor de prueba `hello-world` para confirmar que el servicio se encuentra activo y funcionando correctamente:
```bash
sudo docker run hello-world
```
Si la instalación fue exitosa, verás en pantalla el mensaje *"Hello from Docker!"*.

---

### Configuración opcional: Ejecutar Docker sin permisos de superusuario (`sudo`)
Por defecto, la ejecución de comandos de Docker requiere privilegios de `sudo`. Para gestionar Docker de forma directa con tu usuario actual, agrégalo al grupo de seguridad correspondiente:
1. Añade tu usuario actual al grupo `docker`:
```bash
sudo usermod -aG docker $USER
```

2. Aplica el cambio de grupo en la sesión actual sin reiniciar:
```bash
newgrp docker
```

3. Verifica el acceso ejecutando el contenedor de prueba sin `sudo`:
```bash
docker run hello-world
```

---

### Paso 6: Descargar el repositorio del laboratorio
Clona el repositorio oficial de *spurin*, el cual contiene los entornos necesarios para el desarrollo de las prácticas:
```bash
git clone https://github.com/spurin/diveintoansible-lab.git
```

### Paso 7: Desplegar los contenedores
Accede a la carpeta descargada y ejecuta el siguiente comando para levantar la infraestructura del laboratorio en segundo plano:
```bash
docker compose up -d
```

---
[Siguiente: Laboratorio 01 - Comandos Ad-Hoc](./01-autobiografia-yaml.md)
