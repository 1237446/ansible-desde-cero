# Laboratorio 05: Variables, Facts y Templates

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
ubuntu1  -> Ubuntu (Debian) -> /var/www/html
centos1  -> CentOS (RedHat) -> /usr/share/nginx/html
```

## Paso 1: Crear el proyecto

```bash
cd ~
mkdir -p ~/curso-ansible/sesion04
cd ~/curso-ansible/sesion04
mkdir -p group_vars host_vars templates
```

## Paso 2: Crear el inventario

Crea `inventory.ini`:

```ini
[web]
ubuntu1
centos1

[ubuntu]
ubuntu1

[redhat]
centos1

[linux:children]
ubuntu
redhat

[linux:vars]
ansible_user=ansible
```

## Paso 3: Crear ansible.cfg

Crea `ansible.cfg`:

```ini
[defaults]
inventory = inventory.ini
host_key_checking = False
interpreter_python = auto_silent
forks = 5
retry_files_enabled = False
private_key_file = ~/.ssh/id_ed25519_pit
```

Si aún no tienes la llave SSH:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_pit -C "curso-pit" -N ""
ssh-copy-id -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  -i ~/.ssh/id_ed25519_pit.pub ansible@ubuntu1
ssh-copy-id -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  -i ~/.ssh/id_ed25519_pit.pub ansible@centos1
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

Crea `group_vars/web.yml`:

```yaml
---
app_name: "Portal PIT"
http_port: 8080
nginx_service: nginx
```

## Paso 5: Crear variables de host

Crea `host_vars/ubuntu1.yml`:

```yaml
---
environment_name: desarrollo
site_color: "#2563eb"
site_message: "Servidor Ubuntu para desarrollo"
```

Crea `host_vars/centos1.yml`:

```yaml
---
environment_name: produccion
site_color: "#b91c1c"
site_message: "Servidor CentOS para produccion"
```

## Paso 6: Inspeccionar variables resueltas

```bash
ansible-inventory --host ubuntu1
ansible-inventory --host centos1
```

Consultar una variable específica:

```bash
ansible web -m ansible.builtin.debug -a "var=environment_name"
ansible web -m ansible.builtin.debug -a "var=site_color"
```

Probar un valor temporal:

```bash
ansible web -m ansible.builtin.debug \
  -a "var=environment_name" \
  -e "environment_name=emergencia"
```

## Paso 7: Explorar facts

Recopilar todos los facts de un host:

```bash
ansible ubuntu1 -m ansible.builtin.setup
```

Filtrar facts específicos:

```bash
ansible linux -m ansible.builtin.setup \
  -a "filter=ansible_distribution*"
ansible linux -m ansible.builtin.setup \
  -a "filter=ansible_os_family"
ansible linux -m ansible.builtin.setup \
  -a "filter=ansible_memtotal_mb"
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

## Paso 10: Crear el playbook de facts

Crea `01-explorar-facts.yml`:

```yaml
---
- name: Explorar facts de los servidores
  hosts: linux
  gather_facts: true

  tasks:
    - name: Mostrar facts principales
      ansible.builtin.debug:
        msg:
          - "Inventario: {{ inventory_hostname }}"
          - "Hostname: {{ ansible_hostname }}"
          - "Distribucion: {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "Familia: {{ ansible_os_family }}"
          - "Arquitectura: {{ ansible_architecture }}"
          - "CPU virtuales: {{ ansible_processor_vcpus }}"
          - "Memoria MB: {{ ansible_memtotal_mb }}"
          - "Variable de host: {{ site_message }}"
```

Ejecutar:

```bash
ansible-playbook 01-explorar-facts.yml --syntax-check
ansible-playbook 01-explorar-facts.yml
```

Observa cómo cada host muestra valores diferentes según sus facts y variables.

## Paso 11: Crear el playbook principal

Crea `02-desplegar-sitio.yml`:

```yaml
---
- name: Desplegar un sitio dinamico multiplataforma
  hosts: web
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

### Mostrar hosts

```bash
ansible-playbook 02-desplegar-sitio.yml --list-hosts
```

### Mostrar tareas

```bash
ansible-playbook 02-desplegar-sitio.yml --list-tasks
```

### Primera ejecución

```bash
ansible-playbook 02-desplegar-sitio.yml --ask-become-pass
```

Observa:
- APT ejecutado en Ubuntu, DNF en CentOS
- Templates renderizados con valores diferentes por host
- Handler ejecutado solo si la configuración cambió

### Segunda ejecución

```bash
ansible-playbook 02-desplegar-sitio.yml --ask-become-pass
```

La segunda ejecución debe mostrar principalmente `ok`. El handler no debe ejecutarse.

## Paso 13: Validación manual

### Verificar servicios

```bash
ansible web -b -m ansible.builtin.command \
  -a "systemctl is-active nginx" \
  --ask-become-pass
```

### Verificar puertos

```bash
ansible web -b -m ansible.builtin.shell \
  -a "ss -lntp | grep 8080" \
  --ask-become-pass
```

### Consultar sitios

```bash
ansible ubuntu1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"

ansible centos1 -m ansible.builtin.uri \
  -a "url=http://127.0.0.1:8080 return_content=true"
```

### Ver archivos generados

```bash
ansible ubuntu1 -b -m ansible.builtin.command \
  -a "head -n 20 /var/www/html/index.html" \
  --ask-become-pass

ansible centos1 -b -m ansible.builtin.command \
  -a "head -n 20 /usr/share/nginx/html/index.html" \
  --ask-become-pass
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
