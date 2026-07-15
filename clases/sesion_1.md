# Sesión 1: Primeros pasos con Ansible y automatización de servidores

### Contenido de la Sesión
1. **¿Qué es Ansible?** y por qué se usa para automatizar infraestructura Linux.
2. **Arquitectura *agentless***: Cómo funciona mediante SSH.
3. **Preparación del laboratorio**: Uso de VirtualBox, Vagrant y servidores Linux.
4. **Primeros comandos *ad-hoc***: Ejecución de tareas remotas rápidas sin necesidad de playbooks.

## 1. ¿Qué es Ansible?

### El Problema: Administración Manual de Servidores
Sin automatización, la administración de servidores presenta múltiples inconvenientes:
* Instalar paquetes uno por uno en cada servidor de manera individual.
* Configurar servicios de forma manual.
* Verificar el estado de los servicios manualmente.
* Manejar múltiples servidores se vuelve una tarea sumamente tediosa.
* Alta probabilidad de cometer errores humanos.

> [\!NOTE]
> Sin automatización, la administración de servidores se vuelve ineficiente, tediosa y propensa a fallos.

### Ansible: Historia y Origen
* **Origen (2012):** Creado por Michael DeHaan con una idea central: automatizar servidores de forma simple, sin instalar agentes remotos (*agentless*).
* **Hitos:**
  * Fundación de la empresa original.
  * AWX y la comunidad de código abierto.
  * Expansión más allá de la gestión de servidores (redes, nube, seguridad).
  * Consolidación en **Red Hat Ansible Automation Platform**.

### Comparativa: Scripts Tradicionales vs. Ansible (Playbooks)

| Criterio | Scripts Tradicionales | Ansible (Playbooks) |
| :--- | :--- | :--- |
| **Enfoque** | Imperativo (cómo hacerlo) | Declarativo (qué estado final se desea) |
| **Esfuerzo de Código** | Requieren controlar muchos casos de error y condiciones de forma manual. | Utiliza módulos listos para usar en tareas comunes. |
| **Idempotencia** | El resultado depende de cómo se escribió (puede fallar al reejecutarse). | Idempotente por diseño (solo actúa si hay cambios). |
| **Mantenimiento** | Complejos, extensos y difíciles de reutilizar. | Playbooks en YAML altamente legibles y mantenibles. |

> [\!NOTE]
> Ansible organiza las tareas de manera clara, lo que permite una automatización auditable, repetible y documentada.

---

## 2. ¿Por qué elegir Ansible?

* **Agentless (Sin agentes):** No requiere instalar ningún software o agente en los servidores remotos que se desean administrar.
* **YAML legible:** Los Playbooks están escritos en un lenguaje simple, estructurado y fácil de entender.
* **Idempotente:** Solo aplica cambios si el sistema no se encuentra en el estado deseado. Si ya está configurado correctamente, no hace nada.
* **Solo necesita SSH:** Utiliza una conexión segura estándar por defecto, ya disponible de forma nativa en casi cualquier sistema Linux.

### Arquitectura Básica de Ansible

```

┌──────────────────┐                        SSH      
│ Nodo de Control  ├─────────────┬────────────────┬─────────────────┐
│ (Python 3.8+)    │             │                │                 │
└──────────────────┘             ▼                ▼                 ▼
                         ┌───────────────┐ ┌──────────────┐ ┌───────────────┐
                         │ Servidor App  │ │ Servidor Web │ │ Base de Datos │
                         └───────────────┘ └──────────────┘ └───────────────┘
```

* **Modelo Push:** El nodo de control de Ansible empuja (*push*) las configuraciones hacia los nodos destino vía SSH.
* Al **no requerir agentes ni demonios** en los servidores de destino, se reduce significativamente la superficie de ataque del entorno.

### El Flujo de Trabajo de Ansible
* **Paso 1: Establecer la conexión** -> Realiza el SSH Handshake con los hosts de destino.
* **Paso 2: Generación y envío de módulos** -> Empaqueta los módulos necesarios y los transfiere al nodo remoto.
* **Paso 3: Ejecución remota** -> Procesa el módulo en el servidor de destino.
* **Paso 4: Retorno de resultados en JSON** -> El nodo remoto reporta el estado final en formato JSON.
* **Paso 5: Limpieza automática** -> Elimina los archivos temporales creados en el destino, sin dejar rastro.

---

## 3. Introducción a YAML

### Formatos de Datos: XML vs. JSON vs. YAML

#### XML
```xml
<Servers>
    <Server>
        <name>Server1</name>
        <owner>John</owner>
        <created>123456</created>
        <status>active</status>
    </Server>
</Servers>
```
* Muy formal, basado en etiquetas de apertura y cierre.
* Demasiado verboso para la lectura humana y la edición de archivos de configuración rápidos.

#### JSON
```json
{
  "Servers": [
    {
      "name": "Server1",
      "owner": "John",
      "created": 123456,
      "status": "active"
    }
  ]
}
```
* Ligero, estándar común en APIs y aplicaciones web.
* Hace uso intensivo de llaves `{}`, corchetes `[]` y comillas `""`.

#### YAML
```yaml
Servers:
  - name: Server1
    owner: John
    created: 123456
    status: active
```
* Diseñado específicamente para ser legible por humanos. Muy utilizado en automatización y DevOps.
* Se basa en la **indentación**, listas y pares clave-valor.

### Reglas Básicas de YAML
* Los comentarios empiezan con el carácter `#`.
* La estructura de datos depende estrictamente de la **indentación**.
* Se recomienda utilizar **2 espacios** para indentar; **no usar tabulaciones (tabs)**.
* Las listas de elementos se definen usando un guion (`- item`).
* Las variables siguen el patrón `clave: valor`.

#### Ejemplo de Escalares, Mapas y Secuencias en YAML:
```yaml
usuario:
  nombre: ansible    # Mapa (clave: valor)
  sudo: true         # Escalar (booleano)
  grupos:            # Secuencia (lista ordenada)
    - admins
    - devops
  contacto: {ciudad: Lima, pais: Peru}  # Formato inline / Diccionario
```

---

## 4. Estructura de un Playbook Común

Un Playbook es un archivo YAML que describe una serie de pasos a ejecutar en un conjunto de hosts.

```yaml
---
- name: Preparar servidor web
  hosts: web
  become: true
  tasks:
    - name: Instalar nginx
      apt:
        name: nginx
        state: present
```

### Explicación de los campos clave:
* `---`: Indica el inicio del archivo YAML.
* `name`: Una etiqueta descriptiva legible para humanos que detalla el propósito de la tarea o play.
* `hosts`: Especifica a qué grupo de servidores definidos en el inventario se le aplicarán estas tareas.
* `become: true`: Permite ejecutar las tareas con privilegios elevados (equivalente a `sudo`).
* `tasks`: Define la lista secuencial de tareas que se van a ejecutar de arriba hacia abajo.
* `apt`: Módulo específico de Ansible utilizado para gestionar paquetes en distribuciones Debian/Ubuntu.
  * `name: nginx`: Nombre del paquete que se quiere instalar o gestionar.
  * `state: present`: Define el estado deseado. En este caso, asegura que el paquete esté instalado.

### Mini Actividad: Autobiografía en YAML
Crea un archivo local `autobiografia.yaml` para practicar la estructura y la indentación correcta:

```yaml
# Autobiografía en YAML
nombre: "Tu nombre"
contacto: {correo: "tu@correo.com", ciudad: "Lima"}
habilidades:
  - Linux
  - Git
  - Ansible
metas:
  corto_plazo: "Practicar automatización"
  largo_plazo: "Administrar servidores"
# Fin del documento
```

---

## 5. Preparación del Laboratorio

### Herramientas Necesarias para el Entorno

```
┌──────────────────────────────────────────────────┐
│              Máquina Virtual (Ubuntu)            │
│                 (VirtualBox / Vagrant)           │
│                                                  │
│   ┌──────────────────────────────────────────┐   │
│   │               Docker Compose             │   │
│   │                                          │   │
│   │  ┌──────────┐  ┌──────────┐  ┌────────┐  │   │
│   │  │ ubuntu-c │  │ ubuntu1  │  │ centos1│  │   │
│   │  │ (Control)│  │  (Nodo)  │  │ (Nodo) │  │   │
│   │  └──────────┘  └──────────┘  └────────┘  │   │
│   └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

1. **VirtualBox + Ubuntu:** Usaremos una única máquina virtual como entorno aislado principal para nuestro laboratorio.
2. **Docker + Dive Into Ansible:** Dentro de la máquina virtual de Ubuntu, Docker levantará múltiples contenedores ligeros que simularán los diferentes servidores (nodos) para que Ansible los gestione.

### Instalación de Ansible por Sistema Operativo (Opcional)
* **Ubuntu / Debian:**
  ```bash
  sudo apt update
  sudo apt install ansible -y
  ```
* **RHEL / CentOS / Fedora:**
  ```bash
  sudo dnf install ansible -y
  ```
* **macOS:**
  ```bash
  brew install ansible
  ```
* **En nuestro laboratorio:** El contenedor `ubuntu-c` ya incluye Ansible preinstalado; solo validaremos su funcionamiento ejecutando `ansible --version`.

### Configuración e Inicialización del Lab

1. **Instalar Docker y Git en la VM base:**
   ```bash
    # 1. Actualiza los paquetes del sistema e instala los requisitos previos
    sudo apt update
    sudo apt install ca-certificates curl
    
    # 2. Añade la clave GPG oficial de Docker y el repositorio
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 3. Instala los paquetes de Docker
    sudo apt update
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git
   ```
   
2. **Clonar el repositorio del laboratorio:**
   ```bash
   git clone https://github.com/spurin/diveintoansible-lab.git
   ```
3. **Iniciar los contenedores en segundo plano:**
   ```bash
   cd diveintoansible-lab && sudo docker compose up -d
   ```
> [\!IMPORTANT]
> Esto creará contenedores interconectados en una red interna. El nodo `ubuntu-c` actuará como tu controlador principal de Ansible y tendrá acceso SSH sin contraseña a los nodos administrados (`ubuntu1`, `centos1`, etc.).

### Verificando el Entorno
El laboratorio de *diveintoansible* viene preconfigurado con llaves SSH autorizadas entre el nodo de control y los servidores remotos. 

Accede al nodo de control y realiza la validación:
```bash
# Entrar al contenedor del nodo de control
sudo docker exec -it ubuntu-c bash

# Verificar la versión de Ansible instalada
ansible --version

# Probar acceso SSH sin contraseña hacia uno de los nodos
ssh ubuntu1
```
Si todo es correcto, estarás listo para utilizar Ansible de forma inmediata y sin configuraciones manuales complejas.

---

## 6. Comandos Ad-Hoc (Ejecución Rápida)

### ¿Qué son los Comandos Ad-Hoc?
Son comandos únicos de una sola línea que se ejecutan directamente en la terminal para realizar tareas rápidas y puntuales, sin necesidad de escribir ni guardar un Playbook completo.

### ¿Cuándo utilizarlos?
* Ejecución de tareas rápidas o diagnósticos puntuales.
* Verificar el estado de los servidores de forma ágil (p. ej., espacio en disco, tiempo de actividad).
* Ejecutar un comando de shell simultáneamente en decenas de máquinas.

```bash
# Estructura general de un comando Ad-Hoc
ansible <grupo/hosts> -i <inventario> -m <módulo> [-a "argumentos"] [--become]
```

#### Ejemplos visualizados en consola:
```bash
# Mostrar el usuario remoto actual en todos los nodos
ansible all -m shell -a "echo $USER"

# Consultar el uptime de todas las máquinas en paralelo
ansible all -m shell -a "uptime"

# Consultar la versión del sistema operativo
ansible all -m shell -a "cat /etc/os-release | grep -i PRETTY_NAME"

# Crear un archivo de prueba en la carpeta temporal /tmp
ansible all -m shell -a "touch /tmp/abc.txt"

# Validar que el archivo fue creado con permisos adecuados
ansible all -m shell -a "ls -l /tmp/abc.txt"
```

---

## 7. El Archivo de Inventario (`inventory.ini`)

El inventario define la lista de servidores que Ansible puede gestionar y permite agruparlos según su rol.

```ini
[web]
ubuntu1
ubuntu2

[db]
centos1
centos2

[all:vars]
ansible_user=ansible
```

* **Grupos (`[web]`, `[db]`):** Permite seccionar tus servidores por propósitos específicos para aplicarles tareas de manera selectiva.
* **Variables globales (`[all:vars]`):** Define parámetros de conexión que se aplicarán automáticamente a todas las máquinas del inventario (por ejemplo, el usuario SSH `ansible_user`).

---

## 8. Sintaxis y Ejemplos Prácticos de Comandos Ad-Hoc

### Estructura de Parámetros:
* `-i`: Especifica la ruta del archivo de inventario (por defecto `/etc/ansible/hosts`).
* `-m`: Define el nombre del módulo de Ansible a utilizar.
* `-a`: Pasa argumentos adicionales requeridos por el módulo.
* `--become`: Solicita escalado de privilegios (ejecutar como `sudo`).

### Ejemplos Prácticos

#### 1. Verificar conectividad básica (módulo ping)
El módulo `ping` de Ansible no es un comando ICMP normal; valida el acceso SSH y la presencia de Python en el nodo de destino.
```bash
ansible all -i inventory.ini -m ping
```

#### 2. Consultar información remota (módulo command)
```bash
ansible web -i inventory.ini -m command -a "uptime"
```

#### 3. Instalar un paquete de software (módulo apt)
```bash
ansible web -i inventory.ini -m apt -a "name=htop state=present" --become
```

#### 4. Copiar un archivo local a todos los servidores remotos
```bash
ansible all -i inventory.ini -m copy -a "src=./hola.txt dest=/tmp/hola.txt"
```

#### 5. Recopilar datos técnicos e información del sistema (facts)
El módulo `setup` extrae información detallada sobre el hardware, red y sistema operativo del servidor.
```bash
ansible web -i inventory.ini -m setup
```

#### 6. Reiniciar o gestionar un servicio del sistema (módulo service)
```bash
ansible web -i inventory.ini -m service -a "name=nginx state=restarted" --become
```

---

## 9. Resumen de Módulos Más Comunes

| Módulo | Función | Ejemplo de Argumento |
| :--- | :--- | :--- |
| **`ping`** | Verifica la conectividad y disponibilidad de Python. | *(No requiere argumentos)* |
| **`command`** | Ejecuta comandos básicos de forma remota (no soporta tuberías o variables de entorno del shell). | `-a 'whoami'` |
| **`shell`** | Ejecuta comandos a través del intérprete de comandos `/bin/sh` del nodo destino (soporta pipes `|` y redirecciones). | `-a 'cat /etc/os-release'` |
| **`copy`** | Copia archivos locales hacia los destinos gestionados. | `-a 'src=./local.txt dest=/tmp/remoto.txt'` |
| **`apt`** | Gestiona paquetes de software en distribuciones basadas en Debian/Ubuntu. | `-a 'name=nginx state=present'` |
| **`service`** | Controla el estado de los servicios del sistema (iniciar, detener, reiniciar). | `-a 'name=nginx state=started'` |
| **`setup`** | Obtiene un conjunto masivo de variables internas e información del host (*facts*). | *(No requiere argumentos)* |

> [\!TIP]
> Ansible cuenta con miles de módulos oficiales y comunitarios listos para automatizar casi cualquier tecnología o infraestructura (nube, bases de datos, firewalls, switches de red, contenedores, etc.).
