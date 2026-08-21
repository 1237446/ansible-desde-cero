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
  hosts: ubuntu
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
ansible-playbook site-nginx.yml --syntax-check

# Ejecución del Playbook
ansible-playbook site-nginx.yml

```

### Salida esperada en consola:

```bash
PLAY [Instalar y configurar Nginx con un rol de Galaxy] ****************************

TASK [Gathering Facts] *************************************************************
ok: [ubuntu-node3]
ok: [ubuntu-node1]
ok: [ubuntu-node2]

TASK [nginx : Include OS-specific variables.] **************************************
ok: [ubuntu-node1]
ok: [ubuntu-node2]
ok: [ubuntu-node3]

TASK [nginx : Define nginx_user.] **************************************************
ok: [ubuntu-node1]
ok: [ubuntu-node2]
ok: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
included: /config/workspace/roles/nginx/tasks/setup-Ubuntu.yml for ubuntu-node1, ubuntu-node2, ubuntu-node3

TASK [nginx : Ensure dirmngr is installed (gnupg dependency).] *********************
changed: [ubuntu-node3]
changed: [ubuntu-node1]
changed: [ubuntu-node2]

TASK [nginx : Add PPA for Nginx (if configured).] **********************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : Ensure nginx will reinstall if the PPA was just added.] **************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
included: /config/workspace/roles/nginx/tasks/setup-Debian.yml for ubuntu-node1, ubuntu-node2, ubuntu-node3

TASK [nginx : Update apt cache.] ***************************************************
ok: [ubuntu-node3]
ok: [ubuntu-node2]
ok: [ubuntu-node1]

TASK [nginx : Ensure nginx is installed.] ******************************************
changed: [ubuntu-node2]
changed: [ubuntu-node3]
changed: [ubuntu-node1]

TASK [nginx : include_tasks] *******************************************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : include_tasks] *******************************************************
skipping: [ubuntu-node1]
skipping: [ubuntu-node2]
skipping: [ubuntu-node3]

TASK [nginx : Remove default nginx vhost config file (if configured).] *************
changed: [ubuntu-node1]
changed: [ubuntu-node2]
changed: [ubuntu-node3]

TASK [nginx : Ensure nginx_vhost_path exists.] *************************************
ok: [ubuntu-node1]
ok: [ubuntu-node2]
ok: [ubuntu-node3]

TASK [nginx : Add managed vhost config files.] *************************************
changed: [ubuntu-node2] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'})
changed: [ubuntu-node1] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'})
changed: [ubuntu-node3] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'})

TASK [nginx : Remove managed vhost config files.] **********************************
skipping: [ubuntu-node1] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'}) 
skipping: [ubuntu-node1]
skipping: [ubuntu-node2] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'}) 
skipping: [ubuntu-node2]
skipping: [ubuntu-node3] => (item={'listen': '80 default_server', 'server_name': 'localhost', 'root': '/usr/share/nginx/html', 'index': 'index.html index.htm', 'extra_parameters': 'location / {\n    try_files $uri $uri/ =404;\n}\n'}) 
skipping: [ubuntu-node3]

TASK [nginx : Remove legacy vhosts.conf file.] *************************************
ok: [ubuntu-node1]
ok: [ubuntu-node2]
ok: [ubuntu-node3]

TASK [nginx : Copy nginx configuration in place.] **********************************
changed: [ubuntu-node2]
changed: [ubuntu-node1]
changed: [ubuntu-node3]

TASK [nginx : Ensure nginx service is running as configured.] **********************
changed: [ubuntu-node1]
changed: [ubuntu-node3]
changed: [ubuntu-node2]

RUNNING HANDLER [nginx : restart nginx] ********************************************
changed: [ubuntu-node3]
changed: [ubuntu-node2]
changed: [ubuntu-node1]

RUNNING HANDLER [nginx : reload nginx] *********************************************
changed: [ubuntu-node1]
changed: [ubuntu-node2]
changed: [ubuntu-node3]

PLAY RECAP *************************************************************************
ubuntu-node1               : ok=16   changed=8    unreachable=0    failed=0    skipped=8    rescued=0    ignored=0   
ubuntu-node2               : ok=16   changed=8    unreachable=0    failed=0    skipped=8    rescued=0    ignored=0   
ubuntu-node3               : ok=16   changed=8    unreachable=0    failed=0    skipped=8    rescued=0    ignored=0   
```

---

## 7. Paso 6: Validar el servicio web

Para verificar que Nginx esté respondiendo adecuadamente en el puerto 80 en cada servidor, ejecuta una consulta HTTP utilizando un comando Ad-Hoc con el módulo `uri`:

```bash
ansible linux -b -m uri \
  -a "url=http://localhost status_code=200 return_content=false"

```

### Resultado de la verificación:

```json
ubuntu-node2 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "connection": "close",
    "content_length": "615",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Fri, 21 Aug 2026 18:58:12 GMT",
    "elapsed": 0,
    "etag": "\"6434bbbe-267\"",
    "last_modified": "Tue, 11 Apr 2023 01:45:34 GMT",
    "msg": "OK (615 bytes)",
    "redirected": false,
    "server": "nginx/1.24.0 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
ubuntu-node1 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "connection": "close",
    "content_length": "615",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Fri, 21 Aug 2026 18:58:12 GMT",
    "elapsed": 0,
    "etag": "\"6434bbbe-267\"",
    "last_modified": "Tue, 11 Apr 2023 01:45:34 GMT",
    "msg": "OK (615 bytes)",
    "redirected": false,
    "server": "nginx/1.24.0 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
ubuntu-node3 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "connection": "close",
    "content_length": "615",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Fri, 21 Aug 2026 18:58:12 GMT",
    "elapsed": 0,
    "etag": "\"6434bbbe-267\"",
    "last_modified": "Tue, 11 Apr 2023 01:45:34 GMT",
    "msg": "OK (615 bytes)",
    "redirected": false,
    "server": "nginx/1.24.0 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
```

Ambos nodos responderán con el código HTTP `200 OK`, confirmando que el rol desplegó el servicio y aplicó la configuración de manera homogénea en ambas plataformas.Ubuntu, y viceversa.
3. **Reusabilidad:** Este mismo rol puede ser invocado en docenas de playbooks distintos, manteniendo un único estándar de instalación.

---
