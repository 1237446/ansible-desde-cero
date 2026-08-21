---
# Laboratorio 01: Ansible Galaxy y Configuración de Nginx

Este laboratorio tiene como objetivo principal aprender a buscar, instalar y consumir roles de la comunidad utilizando **Ansible Galaxy**. Automatizaremos la instalación y puesta en marcha de un servidor web Nginx en un entorno multiplataforma, aplicando una configuración personalizada y estandarizada mediante variables de rol.

---

## 1. Objetivos del Laboratorio

* Buscar roles comunitarios desde la terminal con `ansible-galaxy`.
* Gestionar la descarga de roles externos de forma local mediante un archivo `requirements.yml`.
* Configurar un directorio local para almacenar los roles (`-p roles`).
* Desarrollar un Playbook que consuma el rol de Nginx y aplique una configuración completa de *Virtual Hosts*.
* Validar el estado operativo del servicio web (código HTTP `200 OK`) en todos los nodos mediante el módulo `uri`.

---

## 2. Paso 1: Buscar roles comunitarios

Ansible Galaxy permite consultar su repositorio público directamente desde la línea de comandos para encontrar soluciones mantenidas por la comunidad.

Ejecuta la búsqueda para Nginx:

```bash
ansible-galaxy role search nginx

```

---

## 3. Paso 2: Crear el archivo de dependencias (`requirements.yml`)

Para estructurar las dependencias de forma profesional y garantizar la reproducibilidad del entorno, definimos el rol y la versión exacta a utilizar.

Crea el archivo `requirements.yml`:

```yaml
---
roles:
  - name: nginx
    src: geerlingguy.nginx
    version: "3.2.0"

```

---

## 4. Paso 3: Instalar el rol localmente

Descarga el rol indicando una ruta relativa (`roles/`) dentro de tu espacio de trabajo. Esto asegura que el rol quede encapsulado dentro del proyecto.

```bash
# Descargar e instalar el rol
ansible-galaxy role install -r requirements.yml -p roles

# Verificar que el rol se encuentre disponible
ansible-galaxy role list -p roles

```

---

## 5. Paso 4: Crear el Playbook de despliegue (`site-nginx.yml`)

Definimos el Playbook invocando el rol `nginx`. Pasaremos variables para ajustar la capacidad de conexiones simultáneas (`worker_connections`), remover la configuración por defecto y aprovisionar un *Virtual Host* compatible con los distintos sistemas operativos.

Crea el archivo `site-nginx.yml`:

```yaml
---
- name: Instalar y configurar Nginx con un rol de Galaxy
  hosts: linux
  become: true

  roles:
    - role: nginx
      vars:
        nginx_worker_connections: "512"
        nginx_remove_default_vhost: true
        nginx_vhosts:
          - listen: "80 default_server"
            server_name: "localhost"
            root: "/usr/share/nginx/html"
            index: "index.html index.htm"
            extra_parameters: |
              location / {
                  try_files $uri $uri/ =404;
              }

```

---

## 6. Paso 5: Validar sintaxis y ejecutar el Playbook

Primero realizamos una verificación estática de sintaxis y luego procedemos con el despliegue.

```bash
# Comprobación de sintaxis
ansible-playbook -i inventory.ini site-nginx.yml --syntax-check

# Ejecución del Playbook
ansible-playbook -i inventory.ini site-nginx.yml

```

### Salida esperada en consola:

```bash
PLAY [Instalar y configurar Nginx con un rol de Galaxy] **********************************************

TASK [Gathering Facts] *******************************************************************************
ok: [centos1]
ok: [ubuntu1]

TASK [nginx : Include OS-specific variables.] ********************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [nginx : Define nginx_user.] ********************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [ubuntu1]
included: /roles/nginx/tasks/setup-RedHat.yml for centos1

TASK [nginx : Enable nginx repo.] ********************************************************************
changed: [centos1]

TASK [nginx : Ensure nginx is installed.] ************************************************************
ok: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [centos1]
included: /roles/nginx/tasks/setup-Debian.yml for ubuntu1

TASK [nginx : Update apt cache.] *********************************************************************
ok: [ubuntu1]

TASK [nginx : Ensure nginx is installed.] ************************************************************
ok: [ubuntu1]

TASK [nginx : Ensure nginx_vhost_path exists.] *******************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [nginx : Copy nginx configuration in place.] ****************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [nginx : Ensure nginx service is running as configured.] ****************************************
ok: [ubuntu1]
ok: [centos1]

RUNNING HANDLER [nginx : reload nginx] ***************************************************************
changed: [ubuntu1]
changed: [centos1]

PLAY RECAP *******************************************************************************************
centos1                    : ok=11   changed=3    unreachable=0    failed=0    skipped=9    rescued=0    ignored=0
ubuntu1                    : ok=13   changed=3    unreachable=0    failed=0    skipped=10   rescued=0    ignored=0

```

---

## 7. Paso 6: Validar el servicio web

Para verificar que Nginx esté respondiendo adecuadamente en el puerto 80 en cada servidor, ejecuta una consulta HTTP utilizando un comando Ad-Hoc con el módulo `uri`:

```bash
ansible linux -i inventory.ini -b -m uri \
  -a "url=http://localhost status_code=200 return_content=false"

```

### Resultado de la verificación:

```json
ubuntu1 | SUCCESS => {
    "accept_ranges": "bytes",
    "changed": false,
    "connection": "close",
    "content_length": "612",
    "content_type": "text/html",
    "msg": "OK (612 bytes)",
    "redirected": false,
    "server": "nginx/1.18.0 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
centos1 | SUCCESS => {
    "accept_ranges": "bytes",
    "changed": false,
    "connection": "close",
    "content_length": "612",
    "content_type": "text/html",
    "msg": "OK (612 bytes)",
    "redirected": false,
    "server": "nginx/1.20.1",
    "status": 200,
    "url": "http://localhost"
}

```

Ambos nodos responderán con el código HTTP `200 OK`, confirmando que el rol desplegó el servicio y aplicó la configuración de manera homogénea en ambas plataformas.Ubuntu, y viceversa.
3. **Reusabilidad:** Este mismo rol puede ser invocado en docenas de playbooks distintos, manteniendo un único estándar de instalación.

---
