# Laboratorio Práctico de Ansible: `group_vars`, `host_vars` y Despliegue Real

## Objetivo del Laboratorio
* Aprender a organizar variables usando los directorios `group_vars/` y `host_vars/`
* comprender la precedencia de variables (cómo una variable de host sobrescribe a una de grupo)
* auditar tu inventario usando el comando `ansible-inventory` y ejecutar un despliegue real instalando Nginx y MariaDB.

---

## Paso 1: Crear el inventario y directorios

Primero, crea la estructura de carpetas y el archivo de inventario. Reemplaza las IPs (`ansible_host`) con las de tus máquinas reales de prueba.

```bash
mkdir ansible-deploy-lab
cd ansible-deploy-lab
mkdir group_vars host_vars
```

Crea el archivo **`inventario.yaml`** en la raíz de la carpeta `ansible-deploy-lab`:

```yaml
all:
  children:
    webservers:
      hosts:
        ubuntu-node1:
        ubuntu-node2:
    dbservers:
      hosts:
        rocky-node1:
        rocky-node2:
    servers:
      children:
        webservers:
        dbservers:
```

---

## Paso 2: Definir variables por grupo (`group_vars/`)

Aquí definiremos qué se instalará en los servidores web y qué en los de base de datos. Ansible leerá estos archivos automáticamente basándose en los nombres de los grupos del inventario.

**1. Crea el archivo `group_vars/webservers.yml`:**
```yaml
---
# Variables para instalar Nginx
pkg_name: nginx
svc_name: nginx
# Mensaje por defecto para la página web
web_greeting: "Bienvenido al servidor web estándar del clúster."
```

**2. Crea el archivo `group_vars/dbservers.yml`:**
```yaml
---
# Variables para instalar MariaDB
pkg_name: mariadb-server
svc_name: mariadb
```

---

## Paso 3: Personalizar un host específico (`host_vars/`)

Para demostrar que las variables de host tienen mayor prioridad (precedencia), vamos a hacer que el servidor `web1` tenga un mensaje único en su página web.

**Crea el archivo `host_vars/ubuntu-node1.yml`:**
```yaml
---
# Esto sobrescribe la variable 'web_greeting' de group_vars/webservers.yml
web_greeting: "¡Hola! Soy ubuntu-node1. Tengo una configuración personalizada gracias a host_vars."
```

---

## Paso 4: Auditar con `ansible-inventory`

Antes de ejecutar nada, vamos a verificar que Ansible está leyendo nuestra estructura de directorios y variables correctamente.

**1. Ver la topología en formato árbol:**
```bash
ansible-inventory --graph
```
```bash
@all:
  |--@ungrouped:
  |--@webservers:
  |  |--ubuntu-node1
  |  |--ubuntu-node2
  |--@dbservers:
  |  |--rocky-node1
  |  |--rocky-node2
  |--@servers:
  |  |--@webservers:
  |  |  |--ubuntu-node1
  |  |  |--ubuntu-node2
  |  |--@dbservers:
  |  |  |--rocky-node1
  |  |  |--rocky-node2
```

*Salida esperada:* Verás el árbol de tu `datacenter` con los subgrupos `webservers` y `dbservers`, y los hosts correspondientes dentro de cada uno.

**2. Auditar las variables resueltas (formato JSON):**
```bash
ansible-inventory --list
```
```json
{
    "_meta": {
        "hostvars": {
            "rocky-node1": {
                "datacenter_location": "Madrid",
                "ntp_server": "ntp.laboratorio.local",
                "pkg_name": "mariadb-server",
                "svc_name": "mariadb"
            },
            "rocky-node2": {
                "datacenter_location": "Madrid",
                "ntp_server": "ntp.laboratorio.local",
                "pkg_name": "mariadb-server",
                "svc_name": "mariadb"
            },
            "ubuntu-node1": {
                "datacenter_location": "Madrid",
                "ntp_server": "ntp.laboratorio.local",
                "pkg_name": "nginx",
                "svc_name": "nginx",
                "web_greeting": "¡Hola! Soy ubuntu-node. Tengo una configuración personalizada gracias a host_vars."
            },
            "ubuntu-node2": {
                "datacenter_location": "Madrid",
                "ntp_server": "ntp.laboratorio.local",
                "pkg_name": "nginx",
                "svc_name": "nginx",
                "web_greeting": "Bienvenido al servidor web estándar del clúster."
            }
        }
    },
    "all": {
        "children": [
            "ungrouped",
            "webservers",
            "dbservers",
            "servers"
        ]
    },
    "dbservers": {
        "hosts": [
            "rocky-node1",
            "rocky-node2"
        ]
    },
    "servers": {
        "children": [
            "webservers",
            "dbservers"
        ]
    },
    "webservers": {
        "hosts": [
            "ubuntu-node1",
            "ubuntu-node2"
        ]
    }
}
```

*Análisis de la salida:* 
* En la sección de `ubuntu-node1`, `web_greeting` tendrá el mensaje personalizado.
* En la sección de `ubuntu-node2`, `web_greeting` tendrá el mensaje estándar.
* Ambos webservers usarán el paquete `nginx`, mientras que `redhat-node1` usará `mariadb-server`.

---

## Paso 5: Crear el Playbook de instalación

Ahora creamos la "receta" que automatizará el despliegue. Crea un archivo llamado **`deploy.yml`** en la raíz de tu laboratorio:

```yaml
---
- name: Despliegue de Servidores Web
  hosts: webservers
  become: yes # Ejecutar con privilegios de root (sudo)
  tasks:
    - name: Instalar el servidor web (usando la variable pkg_name)
      apt:
        name: "{{ pkg_name }}"
        state: present
        update_cache: yes

    - name: Crear página index.html personalizada
      copy:
        dest: /var/www/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>{{ inventory_hostname }}</title>
            </head>
            <body>
              <h1>{{ web_greeting }}</h1>
              <p>Servidor: {{ inventory_hostname }}</p>
            </body>
          </html>

    - name: Asegurar que el servicio web está corriendo
      service:
        name: "{{ svc_name }}"
        state: started
        enabled: yes

- name: Despliegue de Servidor de Base de Datos
  hosts: dbservers
  become: yes
  tasks:
    - name: Instalar el motor de base de datos
      dnf:
        name: "{{ pkg_name }}"
        state: present
        update_cache: yes

    - name: Asegurar que la base de datos está corriendo
      service:
        name: "{{ svc_name }}"
        state: started
        enabled: yes
```

---

## Paso 6: ¡Ejecutar el Playbook!

Llegó el momento de aplicar la configuración a tus servidores ejecutando el siguiente comando:

```bash
ansible-playbook deploy.yml -K
```
> [!NOTE]
> El flag `-K` o `--ask-become-pass` te pedirá la contraseña de sudo de tus servidores para poder instalar los paquetes. Si tienes configurado sudo sin contraseña (NOPASSWD), puedes omitirlo).

```bash
PLAY [Despliegue de Servidores Web] ***************************************************************************************************************************************************************************************

TASK [Gathering Facts] ****************************************************************************************************************************************************************************************************
ok: [ubuntu-node2]
ok: [ubuntu-node1]

TASK [Instalar el servidor web (usando la variable pkg_name)] *************************************************************************************************************************************************************
changed: [ubuntu-node1]
changed: [ubuntu-node2]

TASK [Crear página index.html personalizada] ******************************************************************************************************************************************************************************
changed: [ubuntu-node2]
changed: [ubuntu-node1]

TASK [Asegurar que el servicio web está corriendo] ************************************************************************************************************************************************************************
changed: [ubuntu-node2]
changed: [ubuntu-node1]

PLAY [Despliegue de Servidor de Base de Datos] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] ****************************************************************************************************************************************************************************************************
ok: [rocky-node1]
ok: [rocky-node2]

TASK [Instalar el motor de base de datos] *********************************************************************************************************************************************************************************
changed: [rocky-node2]
changed: [rocky-node1]

TASK [Asegurar que la base de datos está corriendo] ***********************************************************************************************************************************************************************
changed: [rocky-node1]
changed: [rocky-node2]

PLAY RECAP ****************************************************************************************************************************************************************************************************************
rocky-node1                : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
rocky-node2                : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
ubuntu-node1               : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
ubuntu-node2               : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### ¿Qué ocurrirá durante la ejecución?
1. Ansible se conectará a `ubuntu-node1` y `ubuntu-node2`, instalará Nginx, e insertará un archivo `index.html`. 
2. Si visitas en tu navegador `http://<IP-DE-UBUNTU-NODE-1>`, verás el mensaje personalizado (definido en `host_vars`).
3. Si visitas `http://<IP-DE-UBUNTU-NODE-2>`, verás el mensaje estándar (definido en `group_vars`).
4. En `redhat-node1`, Ansible instalará y arrancará MariaDB. Todo usando el mismo bloque de tareas base, pero inyectando variables distintas dependiendo del grupo.

---

## Resumen del aprendizaje

1. **Reutilización de código:** La tarea de instalación (`apt`) y gestión de servicio (`service`) fue idéntica para Nginx y MariaDB; lo único que cambió fue el valor de las variables `pkg_name` y `svc_name`.
2. **Precedencia (Prioridad):** Demostraste que `host_vars` tiene prioridad sobre `group_vars` al inyectar contenido distinto en el `index.html` del host `ubuntu-node1`.
3. **Visibilidad:** Aprendiste a usar `ansible-inventory` (`--graph` y `--list`) para previsualizar y auditar cómo se asignarán las variables antes de alterar los servidores reales.









