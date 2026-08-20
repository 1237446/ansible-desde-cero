# Bonus Track: Levantamiento de una Pagina web Personalizada

## Objetivo del laboratorio

En este laboratorio crearás un despliegue multiplataforma que utiliza variables de grupo y host, facts descubiertos automáticamente, condicionales `when`, bucles `loop` y templates Jinja2 para generar archivos diferentes para cada servidor.

## Requisitos previos

- Laboratorio `spurin/diveintoansible-lab` activo
- Nodo de control `ubuntu-c` accesible
- Llave SSH configurada

## Duración estimada

45 minutos

## Arquitectura

```text
ubuntu-node1  -> Ubuntu (Debian) -> /var/www/html
ubuntu-node2  -> Ubuntu (Debian) -> /var/www/html
rocky-node1  -> Rocky (RedHat) -> /usr/share/nginx/html
rocky-node2  -> Rocky (RedHat) -> /usr/share/nginx/html
```

## Paso 1: Crear el proyecto

```bash
cd ~
mkdir -p bonus/inventario/host_vars
mkdir -p bonus/inventario/group_vars
mkdir templates
```

## Paso 2: Crear el inventario

Crea `inventario.yaml`:

```yaml
all:
  children:
    webserver:
      hosts:
        ubuntu-node1:
        rocky-node1:
    ubuntu:
      hosts:
        ubuntu-node1:
        ubuntu-node2:
    rocky:
      hosts:
        rocky-node1:
        rocky-node2:
    servers:
      children:
        ubuntu:
        rocky:
  vars:
    ansible_become_password: password
```

## Paso 3: Crear ansible.cfg

Crea `ansible.cfg`:

```ini
[defaults]
inventory = ./inventario.yaml
remote_user = ansible
stdout_callback = default
forks = 5

[privilege_escalation]
become = False
become_method = sudo
become_user = root
```

## Paso 4: Crear variables de grupo

Crea `group_vars/all.yml`:

```yaml
---
course_name: "Ansible desde Cero"
organization_name: "Cursos PIT - OTI"
managed_by: "Ansible"
common_directories:
  - /opt/pit
  - /opt/pit/logs
```

Crea `group_vars/webserver.yml`:

```yaml
---
app_name: "Portal PIT"
http_port: 8080
nginx_service: nginx
```

## Paso 5: Crear variables de host

Crea `host_vars/ubuntu-node1.yml`:

```yaml
---
environment_name: desarrollo
site_color: "#2563eb"
site_message: "Servidor Ubuntu para desarrollo"
```

Crea `host_vars/rocky-node1.yml`:

```yaml
---
environment_name: produccion
site_color: "#b91c1c"
site_message: "Servidor RockyOS para produccion"
```

## Paso 6: Inspeccionar variables resueltas

```bash
ansible-inventory --host ubuntu-node1
```
```json
{
    "ansible_become_password": "password",
    "app_name": "Portal PIT",
    "common_directories": [
        "/opt/pit",
        "/opt/pit/logs"
    ],
    "course_name": "Ansible desde Cero",
    "environment_name": "desarrollo",
    "http_port": 8080,
    "managed_by": "Ansible",
    "nginx_service": "nginx",
    "organization_name": "Cursos PIT - OTI",
    "site_color": "#2563eb",
    "site_message": "Servidor Ubuntu para desarrollo"
}
```
```bash
ansible-inventory --host rocky-node1
```
```json
{
    "ansible_become_password": "password",
    "app_name": "Portal PIT",
    "common_directories": [
        "/opt/pit",
        "/opt/pit/logs"
    ],
    "course_name": "Ansible desde Cero",
    "environment_name": "produccion",
    "http_port": 8080,
    "managed_by": "Ansible",
    "nginx_service": "nginx",
    "organization_name": "Cursos PIT - OTI",
    "site_color": "#b91c1c",
    "site_message": "Servidor RockyOS para produccion"
}
```

Consultar una variable específica:

```bash
ansible webserver -m ansible.builtin.debug -a "var=environment_name"
```
```json
ubuntu-node1 | SUCCESS => {
    "environment_name": "desarrollo"
}
rocky-node1 | SUCCESS => {
    "environment_name": "produccion"
}
```
```bash
ansible webserver -m ansible.builtin.debug -a "var=site_color"
```
```json
ubuntu-node1 | SUCCESS => {
    "site_color": "#2563eb"
}
rocky-node1 | SUCCESS => {
    "site_color": "#b91c1c"
}
```

## Paso 8: Crear el template HTML

Crea `templates/index.html.j2`:

```jinja2
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ app_name }} - {{ inventory_hostname }}</title>
  <style>
    body {
      max-width: 760px;
      margin: 3rem auto;
      padding: 0 1rem;
      font-family: sans-serif;
      color: #1f2937;
    }
    h1 {
      color: {{ site_color }};
    }
    code {
      background: #f3f4f6;
      padding: 0.15rem 0.35rem;
    }
  </style>
</head>
<body>
  <h1>{{ app_name }}</h1>
  <p>{{ site_message }}</p>
  <ul>
    <li>Host de inventario: <code>{{ inventory_hostname }}</code></li>
    <li>Hostname real: <code>{{ ansible_hostname }}</code></li>
    <li>Distribucion: <code>{{ ansible_distribution }} {{ ansible_distribution_version }}</code></li>
    <li>Familia: <code>{{ ansible_os_family }}</code></li>
    <li>Arquitectura: <code>{{ ansible_architecture }}</code></li>
    <li>Entorno: <code>{{ environment_name }}</code></li>
    <li>Puerto: <code>{{ http_port }}</code></li>
  </ul>

  {% if environment_name == "produccion" %}
  <p><strong>Modo produccion:</strong> cambios controlados y validados.</p>
  {% else %}
  <p><strong>Modo desarrollo:</strong> entorno preparado para pruebas.</p>
  {% endif %}

  <p>Gestionado por {{ managed_by }} para {{ organization_name }}.</p>
</body>
</html>
```

## Paso 9: Crear el template de Nginx

Crea `templates/pit-site.conf.j2`:

```jinja2
server {
    listen {{ http_port }};
    server_name _;

    root {{ web_root }};
    index index.html;

    access_log /var/log/nginx/pit_access.log;
    error_log /var/log/nginx/pit_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

## Paso 11: Crear el playbook principal

Crea `02-desplegar-sitio.yml`:

```yaml
---
- name: Desplegar un sitio dinamico multiplataforma
  hosts: webserver
  become: true
  gather_facts: true

  vars:
    web_root_by_family:
      Debian: /var/www/html
      RedHat: /usr/share/nginx/html

  tasks:
    - name: Resolver la raiz web segun la familia
      ansible.builtin.set_fact:
        web_root: "{{ web_root_by_family[ansible_os_family] }}"

    - name: Mostrar las variables resueltas
      ansible.builtin.debug:
        msg:
          - "Host={{ inventory_hostname }}"
          - "Familia={{ ansible_os_family }}"
          - "Entorno={{ environment_name }}"
          - "Raiz={{ web_root }}"
          - "Puerto={{ http_port }}"

    - name: Actualizar cache de APT en Debian
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

    - name: Actualizar cache de DNF en RedHat
      ansible.builtin.dnf:
        update_cache: true
      when: ansible_os_family == "RedHat"

    - name: Instalar Nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Crear directorios comunes
      ansible.builtin.file:
        path: "{{ item }}"
        state: directory
        owner: root
        group: root
        mode: "0755"
      loop: "{{ common_directories }}"

    - name: Garantizar que la raiz web exista
      ansible.builtin.file:
        path: "{{ web_root }}"
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Generar la pagina personalizada
      ansible.builtin.template:
        src: templates/index.html.j2
        dest: "{{ web_root }}/index.html"
        owner: root
        group: root
        mode: "0644"

    - name: Generar la configuracion de Nginx
      ansible.builtin.template:
        src: templates/pit-site.conf.j2
        dest: /etc/nginx/conf.d/pit-site.conf
        owner: root
        group: root
        mode: "0644"
      notify: Reiniciar Nginx

    - name: Validar la configuracion de Nginx
      ansible.builtin.command:
        cmd: nginx -t
      changed_when: false

    - name: Iniciar y habilitar Nginx
      ansible.builtin.service:
        name: "{{ nginx_service }}"
        state: started
        enabled: true

    - name: Aplicar handlers antes de probar
      ansible.builtin.meta: flush_handlers

    - name: Esperar el puerto del sitio
      ansible.builtin.wait_for:
        host: 127.0.0.1
        port: "{{ http_port }}"
        timeout: 30

    - name: Validar la respuesta HTTP
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ http_port }}"
        return_content: true
        status_code: 200
      register: web_response

    - name: Confirmar el contenido entregado
      ansible.builtin.assert:
        that:
          - app_name in web_response.content
          - inventory_hostname in web_response.content
          - environment_name in web_response.content
        success_msg: "El sitio de {{ inventory_hostname }} responde correctamente."

  handlers:
    - name: Reiniciar Nginx
      ansible.builtin.service:
        name: "{{ nginx_service }}"
        state: restarted
```

## Paso 12: Validar y ejecutar

### Verificar sintaxis
```bash
ansible-playbook 02-desplegar-sitio.yml --syntax-check
```
```yaml
playbook: 02-desplegar-sitio.yml
```

### Mostrar hosts
```bash
ansible-playbook 02-desplegar-sitio.yml --list-hosts
```
```yaml
playbook: 02-desplegar-sitio.yml

  play #1 (web): Desplegar un sitio dinamico multiplataforma    TAGS: []
    pattern: ['web']
    hosts (2):
      ubuntu1
      centos1
```

### Mostrar tareas
```bash
ansible-playbook 02-desplegar-sitio.yml --list-tasks
```
```yaml
playbook: 02-desplegar-sitio.yml

  play #1 (web): Desplegar un sitio dinamico multiplataforma    TAGS: []
    tasks:
      Resolver la raiz web segun la familia     TAGS: []
      Mostrar las variables resueltas   TAGS: []
      Actualizar cache de APT en Debian TAGS: []
      Actualizar cache de DNF en RedHat TAGS: []
      Instalar Nginx    TAGS: []
      Crear directorios comunes TAGS: []
      Garantizar que la raiz web exista TAGS: []
      Generar la pagina personalizada   TAGS: []
      Generar la configuracion de Nginx TAGS: []
      Validar la configuracion de Nginx TAGS: []
      Iniciar y habilitar Nginx TAGS: []
      Aplicar handlers antes de probar  TAGS: []
      Esperar el puerto del sitio       TAGS: []
      Validar la respuesta HTTP TAGS: []
      Confirmar el contenido entregado  TAGS: []
```

### Primera ejecución
```bash
ansible-playbook 02-desplegar-sitio.yml --ask-become-pass
```
Observa:
- APT ejecutado en Ubuntu, DNF en CentOS
- Templates renderizados con valores diferentes por host
- Handler ejecutado solo si la configuración cambió

```bash
PLAY [Desplegar un sitio dinamico multiplataforma] ***************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [centos1]
ok: [ubuntu1]

TASK [Resolver la raiz web segun la familia] *********************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Mostrar las variables resueltas] ***************************************************************
ok: [ubuntu1] => {
    "msg": [
        "Host=ubuntu1",
        "Familia=Debian",
        "Entorno=desarrollo",
        "Raiz=/var/www/html",
        "Puerto=8080"
    ]
}
ok: [centos1] => {
    "msg": [
        "Host=centos1",
        "Familia=RedHat",
        "Entorno=produccion",
        "Raiz=/usr/share/nginx/html",
        "Puerto=8080"
    ]
}

TASK [Actualizar cache de APT en Debian] *************************************************************
skipping: [centos1]
changed: [ubuntu1]

TASK [Actualizar cache de DNF en RedHat] *************************************************************
skipping: [ubuntu1]
ok: [centos1]

TASK [Instalar Nginx] ********************************************************************************
changed: [centos1]
changed: [ubuntu1]

TASK [Crear directorios comunes] *********************************************************************
changed: [ubuntu1] => (item=/opt/pit)
changed: [centos1] => (item=/opt/pit)
changed: [ubuntu1] => (item=/opt/pit/logs)
changed: [centos1] => (item=/opt/pit/logs)

TASK [Garantizar que la raiz web exista] *************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Generar la pagina personalizada] ***************************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [Generar la configuracion de Nginx] *************************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [Validar la configuracion de Nginx] *************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Iniciar y habilitar Nginx] *********************************************************************
ok: [ubuntu1]
changed: [centos1]

TASK [Aplicar handlers antes de probar] **************************************************************

TASK [Aplicar handlers antes de probar] **************************************************************

RUNNING HANDLER [Reiniciar Nginx] ********************************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [Esperar el puerto del sitio] *******************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Validar la respuesta HTTP] *********************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Confirmar el contenido entregado] **************************************************************
ok: [ubuntu1] => {
    "changed": false,
    "msg": "El sitio de ubuntu1 responde correctamente."
}
ok: [centos1] => {
    "changed": false,
    "msg": "El sitio de centos1 responde correctamente."
}

PLAY RECAP *******************************************************************************************
centos1                    : ok=15   changed=6    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
ubuntu1                    : ok=15   changed=6    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### Segunda ejecución

```bash
ansible-playbook 02-desplegar-sitio.yml
```

La segunda ejecución debe mostrar principalmente `ok`. El handler no debe ejecutarse.

## Paso 13: Validación manual

### Verificar servicios
```bash
ansible web -b -m ansible.builtin.command \
  -a "systemctl is-active nginx" 
```
```bash
ubuntu1 | CHANGED | rc=0 >>
active
centos1 | CHANGED | rc=0 >>
active
```

### Verificar puertos
```bash
ansible web -b -m ansible.builtin.shell \
  -a "ss -lntp | grep 8080" 
```
```bash
ubuntu1 | CHANGED | rc=0 >>
LISTEN 0      511          0.0.0.0:8080       0.0.0.0:*    users:(("nginx",pid=9836,fd=8),("nginx",pid=9835,fd=8),("nginx",pid=9834,fd=8))
centos1 | CHANGED | rc=0 >>
LISTEN 0      511          0.0.0.0:8080       0.0.0.0:*    users:(("nginx",pid=4778,fd=8),("nginx",pid=4777,fd=8),("nginx",pid=4776,fd=8))
```

### Consultar sitios
```bash
ansible ubuntu1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"

ansible centos1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"
```
```json
ubuntu1 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "connection": "close",
    "content": "<!doctype html>\n<html lang=\"es\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>Portal PIT - ubuntu1</title>\n  <style>\n    body {\n      max-width: 760px;\n      margin: 3rem auto;\n      padding: 0 1rem;\n      font-family: sans-serif;\n      color: #1f2937;\n    }\n    h1 {\n      color: #2563eb;\n    }\n    code {\n      background: #f3f4f6;\n      padding: 0.15rem 0.35rem;\n    }\n  </style>\n</head>\n<body>\n  <h1>Portal PIT</h1>\n  <p>Servidor Ubuntu para desarrollo</p>\n  <ul>\n    <li>Host de inventario: <code>ubuntu1</code></li>\n    <li>Hostname real: <code>ubuntu1</code></li>\n    <li>Distribucion: <code>Ubuntu 22.04</code></li>\n    <li>Familia: <code>Debian</code></li>\n    <li>Arquitectura: <code>x86_64</code></li>\n    <li>Entorno: <code>desarrollo</code></li>\n    <li>Puerto: <code>8080</code></li>\n  </ul>\n\n    <p><strong>Modo desarrollo:</strong> entorno preparado para pruebas.</p>\n  \n  <p>Gestionado por Ansible para Cursos PIT - OTI.</p>\n</body>\n</html>\n",
    "content_length": "1025",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Thu, 30 Jul 2026 21:05:12 GMT",
    "elapsed": 0,
    "etag": "\"6a6bbba5-401\"",
    "last_modified": "Thu, 30 Jul 2026 21:01:25 GMT",
    "msg": "OK (1025 bytes)",
    "redirected": false,
    "server": "nginx/1.18.0 (Ubuntu)",
    "status": 200,
    "url": "http://127.0.0.1:8080"
}
```

```bash
ansible ubuntu1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"

ansible centos1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"
```
```json
centos1 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "connection": "close",
    "content": "<!doctype html>\n<html lang=\"es\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>Portal PIT - centos1</title>\n  <style>\n    body {\n      max-width: 760px;\n      margin: 3rem auto;\n      padding: 0 1rem;\n      font-family: sans-serif;\n      color: #1f2937;\n    }\n    h1 {\n      color: #b91c1c;\n    }\n    code {\n      background: #f3f4f6;\n      padding: 0.15rem 0.35rem;\n    }\n  </style>\n</head>\n<body>\n  <h1>Portal PIT</h1>\n  <p>Servidor CentOS para produccion</p>\n  <ul>\n    <li>Host de inventario: <code>centos1</code></li>\n    <li>Hostname real: <code>centos1</code></li>\n    <li>Distribucion: <code>CentOS 9</code></li>\n    <li>Familia: <code>RedHat</code></li>\n    <li>Arquitectura: <code>x86_64</code></li>\n    <li>Entorno: <code>produccion</code></li>\n    <li>Puerto: <code>8080</code></li>\n  </ul>\n\n    <p><strong>Modo produccion:</strong> cambios controlados y validados.</p>\n  \n  <p>Gestionado por Ansible para Cursos PIT - OTI.</p>\n</body>\n</html>\n",
    "content_length": "1022",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Thu, 30 Jul 2026 21:05:21 GMT",
    "elapsed": 0,
    "etag": "\"6a6bbba5-3fe\"",
    "last_modified": "Thu, 30 Jul 2026 21:01:25 GMT",
    "msg": "OK (1022 bytes)",
    "redirected": false,
    "server": "nginx/1.20.1",
    "status": 200,
    "url": "http://127.0.0.1:8080"
}
```

### Ver archivos generados
```bash
ansible ubuntu1 -b -m ansible.builtin.command \
  -a "head -n 20 /var/www/html/index.html" \
  --ask-become-pass
```
```html
ubuntu1 | CHANGED | rc=0 >>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Portal PIT - ubuntu1</title>
  <style>
    body {
      max-width: 760px;
      margin: 3rem auto;
      padding: 0 1rem;
      font-family: sans-serif;
      color: #1f2937;
    }
    h1 {
      color: #2563eb;
    }
    code {
      background: #f3f4f6;
      padding: 0.15rem 0.35rem;
```

```bash
ansible centos1 -b -m ansible.builtin.command \
  -a "head -n 20 /usr/share/nginx/html/index.html" \
  --ask-become-pass
```
```html
centos1 | CHANGED | rc=0 >>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Portal PIT - centos1</title>
  <style>
    body {
      max-width: 760px;
      margin: 3rem auto;
      padding: 0 1rem;
      font-family: sans-serif;
      color: #1f2937;
    }
    h1 {
      color: #b91c1c;
    }
    code {
      background: #f3f4f6;
      padding: 0.15rem 0.35rem;
```
## Paso 14: Provocar un cambio controlado

Edita `group_vars/web.yml` y cambia el puerto:

```yaml
http_port: 8081
```

Ejecuta nuevamente:

```bash
ansible-playbook 02-desplegar-sitio.yml --ask-become-pass
```

El handler debe ejecutarse esta vez. Verifica que el sitio responde en el nuevo puerto.

```json
ubuntu1 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "connection": "close",
    "content": "<!doctype html>\n<html lang=\"es\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>Portal PIT - ubuntu1</title>\n  <style>\n    body {\n      max-width: 760px;\n      margin: 3rem auto;\n      padding: 0 1rem;\n      font-family: sans-serif;\n      color: #1f2937;\n    }\n    h1 {\n      color: #2563eb;\n    }\n    code {\n      background: #f3f4f6;\n      padding: 0.15rem 0.35rem;\n    }\n  </style>\n</head>\n<body>\n  <h1>Portal PIT</h1>\n  <p>Servidor Ubuntu para desarrollo</p>\n  <ul>\n    <li>Host de inventario: <code>ubuntu1</code></li>\n    <li>Hostname real: <code>ubuntu1</code></li>\n    <li>Distribucion: <code>Ubuntu 22.04</code></li>\n    <li>Familia: <code>Debian</code></li>\n    <li>Arquitectura: <code>x86_64</code></li>\n    <li>Entorno: <code>desarrollo</code></li>\n    <li>Puerto: <code>8081</code></li>\n  </ul>\n\n    <p><strong>Modo desarrollo:</strong> entorno preparado para pruebas.</p>\n  \n  <p>Gestionado por Ansible para Cursos PIT - OTI.</p>\n</body>\n</html>\n",
    "content_length": "1025",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Fri, 31 Jul 2026 13:41:27 GMT",
    "elapsed": 0,
    "etag": "\"6a6ca5c3-401\"",
    "last_modified": "Fri, 31 Jul 2026 13:40:19 GMT",
    "msg": "OK (1025 bytes)",
    "redirected": false,
    "server": "nginx/1.18.0 (Ubuntu)",
    "status": 200,
    "url": "http://127.0.0.1:8081"
}
```

Restaura el valor original:

```yaml
http_port: 8080
```

## Paso 15: Limpieza

Crea `99-limpieza.yml`:

```yaml
---
- name: Limpiar los recursos del laboratorio
  hosts: web
  become: true
  gather_facts: true

  vars:
    web_root_by_family:
      Debian: /var/www/html
      RedHat: /usr/share/nginx/html

  tasks:
    - name: Resolver la raiz web
      ansible.builtin.set_fact:
        web_root: "{{ web_root_by_family[ansible_os_family] }}"

    - name: Eliminar la configuracion del sitio
      ansible.builtin.file:
        path: /etc/nginx/conf.d/pit-site.conf
        state: absent
      notify: Reiniciar Nginx

    - name: Eliminar la pagina del laboratorio
      ansible.builtin.file:
        path: "{{ web_root }}/index.html"
        state: absent

    - name: Eliminar directorios comunes
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop: "{{ common_directories | reverse | list }}"

  handlers:
    - name: Reiniciar Nginx
      ansible.builtin.service:
        name: "{{ nginx_service }}"
        state: restarted
```

Ejecutar limpieza:

```bash
ansible-playbook 99-limpieza.yml --ask-become-pass
```

```bash
PLAY [Limpiar los recursos del laboratorio] **********************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [centos1]
ok: [ubuntu1]

TASK [Resolver la raiz web] **************************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Eliminar la configuracion del sitio] ***********************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [Eliminar la pagina del laboratorio] ************************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [Eliminar directorios comunes] ******************************************************************
changed: [ubuntu1] => (item=/opt/pit/logs)
changed: [centos1] => (item=/opt/pit/logs)
changed: [ubuntu1] => (item=/opt/pit)
changed: [centos1] => (item=/opt/pit)

RUNNING HANDLER [Reiniciar Nginx] ********************************************************************
changed: [ubuntu1]
changed: [centos1]

PLAY RECAP *******************************************************************************************
centos1                    : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu1                    : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Preguntas de comprensión

1. ¿Qué valor tiene `ansible_os_family` en Ubuntu? ¿Y en CentOS?
2. ¿Por qué se usa `set_fact` en lugar de definir `web_root` directamente?
3. ¿Qué sucede si eliminas `notify: Reiniciar Nginx` del template?
4. ¿Por qué algunas tareas aparecen como `skipped`?
5. ¿Qué hace `flush_handlers` y por qué se usa antes de validar HTTP?
6. ¿Cuál es la diferencia entre `loop` y `when`?

## Resumen

En este laboratorio aprendiste a:

- Definir variables en `group_vars/` y `host_vars/`
- Recopilar y utilizar facts automáticamente
- Usar `set_fact` para calcular variables dinámicas
- Condicionar tareas con `when`
- Repetir tareas con `loop`
- Crear templates Jinja2 con variables, condicionales y hechos
- Notificar handlers solo cuando hay cambios
- Validar servicios y contenido con assertions
- Demostrar idempotencia con múltiples ejecuciones
