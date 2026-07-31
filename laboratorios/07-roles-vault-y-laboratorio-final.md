# Laboratorio 06: Roles, Vault y Laboratorio Final Integrador

## Objetivo del laboratorio

En este laboratorio aprenderás a crear roles reutilizables con `ansible-galaxy`, cifrar secretos con Ansible Vault, instalar y validar Node Exporter para monitoreo, auditar configuraciones de seguridad y crear backups verificables. El laboratorio culminará con un ejercicio integrador que combina todos estos conceptos.

## Requisitos previos

- Laboratorio `spurin/diveintoansible-lab` activo
- Nodo de control `ubuntu-c` accesible
- Llave SSH configurada

## Duración estimada

90 minutos (sesiones 5 y 6 combinadas)

---

# Mini Laboratorio 1: Crear un Rol

## Paso 1: Crear el proyecto y el inventario

```bash
cd ~
mkdir -p ~/sesiones-05-06
cd ~/sesiones-05-06

cat > inventory.ini <<'EOF'
[linux]
ubuntu1
centos1

[linux:vars]
ansible_user=ansible
EOF
```

Verificar conectividad:

```bash
ansible-inventory -i inventory.ini --graph
ansible linux -i inventory.ini -m ansible.builtin.ping
```

## Paso 2: Inicializar el rol

```bash
mkdir -p roles
ansible-galaxy role init roles/pit_banner
find roles/pit_banner -maxdepth 2 -type f | sort
```

Estructura generada:

```text
roles/pit_banner/
├── README.md
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yml
├── templates/
└── vars/
    └── main.yml
```

## Paso 3: Definir valores por defecto

Edita `roles/pit_banner/defaults/main.yml`:

```yaml
---
pit_course_name: "Ansible desde Cero"
pit_session_name: "Sesiones 5 y 6"
pit_banner_dir: "/tmp/pit-ansible"
pit_banner_file: "{{ pit_banner_dir }}/banner.txt"
```

## Paso 4: Crear el template

Crea `roles/pit_banner/templates/banner.j2`:

```jinja2
Curso: {{ pit_course_name }}
Bloque: {{ pit_session_name }}
Host: {{ ansible_hostname }}
Sistema: {{ ansible_distribution }} {{ ansible_distribution_version }}
Administrado por Ansible: si
```

## Paso 5: Definir las tareas

Reemplaza `roles/pit_banner/tasks/main.yml`:

```yaml
---
- name: Crear directorio del banner
  ansible.builtin.file:
    path: "{{ pit_banner_dir }}"
    state: directory
    mode: "0755"

- name: Generar banner personalizado
  ansible.builtin.template:
    src: banner.j2
    dest: "{{ pit_banner_file }}"
    mode: "0644"
  notify: Informar cambio del banner

- name: Consultar el banner generado
  ansible.builtin.command:
    cmd: "cat {{ pit_banner_file }}"
  register: banner_result
  changed_when: false

- name: Mostrar el banner
  ansible.builtin.debug:
    var: banner_result.stdout_lines
```

## Paso 6: Definir el handler

Reemplaza `roles/pit_banner/handlers/main.yml`:

```yaml
---
- name: Informar cambio del banner
  ansible.builtin.debug:
    msg: "El banner cambio en {{ inventory_hostname }}"
```

## Paso 7: Consumir el rol

Crea `site.yml`:

```yaml
---
- name: Aplicar rol de banner
  hosts: linux
  gather_facts: true
  roles:
    - role: pit_banner
```

## Paso 8: Validar y ejecutar

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
ansible-playbook -i inventory.ini site.yml --check
ansible-playbook -i inventory.ini site.yml
```

```bash
PLAY [Aplicar rol de banner] *************************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [pit_banner : Crear directorio del banner] ******************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [pit_banner : Generar banner personalizado] *****************************************************
changed: [ubuntu1]
changed: [centos1]

TASK [pit_banner : Consultar el banner generado] *****************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [pit_banner : Mostrar el banner] ****************************************************************
ok: [ubuntu1] => {
    "banner_result.stdout_lines": [
        "Curso: Ansible desde Cero",
        "Bloque: Sesiones 5 y 6",
        "Host: ubuntu1",
        "Sistema: Ubuntu 22.04",
        "Administrado por Ansible: si"
    ]
}
ok: [centos1] => {
    "banner_result.stdout_lines": [
        "Curso: Ansible desde Cero",
        "Bloque: Sesiones 5 y 6",
        "Host: centos1",
        "Sistema: CentOS 9",
        "Administrado por Ansible: si"
    ]
}

RUNNING HANDLER [pit_banner : Informar cambio del banner] ********************************************
ok: [ubuntu1] => {
    "msg": "El banner cambio en ubuntu1"
}
ok: [centos1] => {
    "msg": "El banner cambio en centos1"
}

PLAY RECAP *******************************************************************************************
centos1                    : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu1                    : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

**Punto clave**: La segunda ejecución debe terminar con `changed=0`. Esto demuestra idempotencia.

---

# Mini Laboratorio 2: Ansible Galaxy

## Paso 1: Buscar roles comunitarios

```bash
ansible-galaxy role search nginx
```

## Paso 2: Crear requirements.yml

```yaml
---
roles:
  - name: nginx
    src: geerlingguy.nginx
    version: "3.2.0"
```

## Paso 3: Instalar el rol

```bash
ansible-galaxy role install -r requirements.yml -p roles
ansible-galaxy role list -p roles
```

## Paso 4: Usar el rol instalado

Crea `site-nginx.yml`:

```yaml
---
- name: Instalar y configurar Nginx con un rol de Galaxy
  hosts: linux
  become: true

  roles:
    - role: nginx
      vars:
        nginx_worker_connections: "512"
```

## Paso 5: Ejecutar

```bash
ansible-playbook -i inventory.ini site-nginx.yml --syntax-check
ansible-playbook -i inventory.ini site-nginx.yml
```

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
included: /root/sesiones-05-06/roles/nginx/tasks/setup-RedHat.yml for centos1

TASK [nginx : Enable nginx repo.] ********************************************************************
changed: [centos1]

TASK [nginx : Ensure nginx is installed.] ************************************************************
ok: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [centos1]
included: /root/sesiones-05-06/roles/nginx/tasks/setup-Ubuntu.yml for ubuntu1

TASK [nginx : Ensure dirmngr is installed (gnupg dependency).] ***************************************
changed: [ubuntu1]

TASK [nginx : Add PPA for Nginx (if configured).] ****************************************************
skipping: [ubuntu1]

TASK [nginx : Ensure nginx will reinstall if the PPA was just added.] ********************************
skipping: [ubuntu1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [centos1]
included: /root/sesiones-05-06/roles/nginx/tasks/setup-Debian.yml for ubuntu1

TASK [nginx : Update apt cache.] *********************************************************************
ok: [ubuntu1]

TASK [nginx : Ensure nginx is installed.] ************************************************************
ok: [ubuntu1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : include_tasks] *************************************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : Remove default nginx vhost config file (if configured).] *******************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : Ensure nginx_vhost_path exists.] *******************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [nginx : Add managed vhost config files.] *******************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : Remove managed vhost config files.] ****************************************************
skipping: [ubuntu1]
skipping: [centos1]

TASK [nginx : Remove legacy vhosts.conf file.] *******************************************************
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

Validar:

```bash
ansible linux -i inventory.ini -b -m uri \
  -a "url=http://localhost status_code=200 return_content=false"
```

```json
ubuntu1 | SUCCESS => {
    "accept_ranges": "bytes",
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "connection": "close",
    "content_length": "612",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Fri, 31 Jul 2026 15:04:50 GMT",
    "elapsed": 0,
    "etag": "\"5e9efe7d-264\"",
    "last_modified": "Tue, 21 Apr 2020 14:09:01 GMT",
    "msg": "OK (612 bytes)",
    "redirected": false,
    "server": "nginx/1.18.0 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
centos1 | FAILED! => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "connection": "close",
    "content_length": "153",
    "content_type": "text/html",
    "date": "Fri, 31 Jul 2026 15:04:50 GMT",
    "elapsed": 0,
    "msg": "Status code was 403 and not [200]: HTTP Error 403: Forbidden",
    "redirected": false,
    "server": "nginx/1.20.1",
    "status": 403,
    "url": "http://localhost"
}
```

> [\!NOTE]
> el servicio de Nginx no funcia debido que no responde correctamente en el puerto 80, pero ademas no tiene permiso para leer la carpeta o no existe el archivo

```bash
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

# Mini Laboratorio 3: Node Exporter

## Paso 1: Instalar Node Exporter (solo en Ubuntu)

```bash
ansible ubuntu1 -i inventory.ini -b \
  -m ansible.builtin.apt \
  -a "name=prometheus-node-exporter state=present update_cache=true" \
  --ask-become-pass
```

## Paso 2: Activar el servicio

```bash
ansible ubuntu1 -i inventory.ini -b \
  -m ansible.builtin.service \
  -a "name=prometheus-node-exporter state=started enabled=true" \
  --ask-become-pass
```

## Paso 3: Validar

```bash
ansible ubuntu1 -i inventory.ini \
  -m ansible.builtin.uri \
  -a "url=http://localhost:9100/metrics status_code=200 return_content=false"
```

---

# Mini Laboratorio 4: Ansible Vault

## Paso 1: Crear directorio de variables

```bash
mkdir -p group_vars/all
```

## Paso 2: Cifrar una variable

```bash
# 1. Crear el archivo YAML plano
echo 'vault_demo_token: "token-demo-pit"' > group_vars/all/vault.yml

# 2. Cifrar el archivo completo
ansible-vault encrypt group_vars/all/vault.yml
```

Se solicitará crear una contraseña. Para el laboratorio usa: `pit-vault-2026`

## Paso 3: Verificar que está cifrado

```bash
cat group_vars/all/vault.yml
```

El archivo debe comenzar con `$ANSIBLE_VAULT;`.

## Paso 4: Visualizar el contenido cifrado

```bash
ansible-vault view group_vars/all/vault.yml
```

## Paso 5: Crear playbook de validación

Crea `vault-check.yml`:

```yaml
---
- name: Validar secreto cifrado
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Comprobar que el token existe
      ansible.builtin.assert:
        that:
          - vault_demo_token is defined
          - vault_demo_token | length > 8
        success_msg: "Vault cargado correctamente"
      no_log: true
```

## Paso 6: Ejecutar

```bash
ansible-playbook -i inventory.ini vault-check.yml --ask-vault-pass
```

---

# Mini Laboratorio 5: Auditoría SSH/UFW

## Paso 1: Consultar configuración SSH

```bash
ansible linux -i inventory.ini -b \
  -m ansible.builtin.shell \
  -a "sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'" \
  --ask-become-pass
```

## Paso 2: Ver puertos en escucha

```bash
ansible linux -i inventory.ini -b \
  -m ansible.builtin.command \
  -a "ss -lnt" \
  --ask-become-pass
```

## Paso 3: Verificar UFW (si está instalado)

```bash
ansible ubuntu1 -i inventory.ini -b \
  -m ansible.builtin.command \
  -a "ufw status verbose" \
  --ask-become-pass
```

---

# Mini Laboratorio 6: Backup Verificable

## Paso 1: Crear el playbook

Crea `backup.yml`:

```yaml
---
- name: Crear backup demostrativo
  hosts: linux
  gather_facts: false
  tasks:
    - name: Crear directorio protegido
      ansible.builtin.file:
        path: /tmp/pit-backups
        state: directory
        mode: "0700"

    - name: Copiar archivo de referencia
      ansible.builtin.copy:
        src: /etc/hosts
        dest: /tmp/pit-backups/hosts.snapshot
        remote_src: true
        mode: "0600"

    - name: Consultar metadata del backup
      ansible.builtin.stat:
        path: /tmp/pit-backups/hosts.snapshot
      register: backup_file

    - name: Validar que el backup existe y no esta vacio
      ansible.builtin.assert:
        that:
          - backup_file.stat.exists
          - backup_file.stat.size > 0
```

## Paso 2: Ejecutar dos veces

```bash
ansible-playbook -i inventory.ini backup.yml
ansible-playbook -i inventory.ini backup.yml
```

La segunda ejecución debe mostrar `changed=0`.

---

# Laboratorio Final Integrador

Este laboratorio combina todos los conceptos aprendidos en un escenario realista.

## Escenario

Una organización necesita desplegar en sus servidores un archivo de configuración protegido. La automatización debe:

1. Estar organizada en un rol nuevo
2. Obtener un token desde un archivo de Ansible Vault
3. Crear la configuración con permisos `0600` sin mostrar el secreto
4. Comprobar que el servicio SSH continúa activo y que el puerto 22 responde
5. Crear una copia de respaldo y validar que no esté vacía
6. Terminar la segunda ejecución con `changed=0`

## Paso 1: Crear el proyecto desde cero

```bash
cd ~
mkdir -p laboratorio-integrador/group_vars/all laboratorio-integrador/roles
cd laboratorio-integrador
ansible-galaxy role init operacion_segura --init-path roles
sudo apt update && sudo apt install -y sshpass
```

## Paso 2: Crear el inventario

Crea `laboratorio-integrador/inventory.ini`:

```ini
[linux]
ubuntu1
centos1

[linux:vars]
ansible_user=ansible
ansible_password=password
ansible_become_password=password
```

Verificar:

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

## Paso 3: Definir variables del rol

Reemplaza `roles/operacion_segura/defaults/main.yml`:

```yaml
---
lab_root: /opt/pit-integrador
lab_environment: entrenamiento
```

## Paso 4: Crear archivo Vault cifrado

```bash
ansible-vault create group_vars/all/vault.yml
```

Dentro del editor escribir:

```yaml
---
vault_app_token: "token-solo-para-laboratorio"
```

Guardar y confirmar que no quedó en texto plano:

```bash
cat group_vars/all/vault.yml
```

Debe comenzar con `$ANSIBLE_VAULT;`.

## Paso 5: Crear el template

Crea `roles/operacion_segura/templates/app.conf.j2`:

```jinja2
# Administrado por Ansible
entorno={{ lab_environment }}
nodo={{ inventory_hostname }}
token={{ vault_app_token }}
```

## Paso 6: Crear el handler

Reemplaza `roles/operacion_segura/handlers/main.yml`:

```yaml
---
- name: Validar configuracion protegida
  ansible.builtin.command:
    cmd: "test -s {{ lab_root }}/app.conf"
  changed_when: false
```

## Paso 7: Implementar el rol

Reemplaza `roles/operacion_segura/tasks/main.yml`:

```yaml
---
- name: Crear directorio protegido
  ansible.builtin.file:
    path: "{{ lab_root }}"
    state: directory
    owner: root
    group: root
    mode: "0750"

- name: Desplegar configuracion con secreto cifrado
  ansible.builtin.template:
    src: app.conf.j2
    dest: "{{ lab_root }}/app.conf"
    owner: root
    group: root
    mode: "0600"
  no_log: true
  notify: Validar configuracion protegida

- name: Recopilar estado de los servicios
  ansible.builtin.service_facts:

- name: Comprobar que SSH continua activo
  ansible.builtin.assert:
    that:
      - >-
        ('ssh.service' in ansible_facts.services and
         ansible_facts.services['ssh.service'].state == 'running') or
        ('sshd.service' in ansible_facts.services and
         ansible_facts.services['sshd.service'].state == 'running') or
        ('ssh' in ansible_facts.services and
         ansible_facts.services['ssh'].state == 'running') or
        ('sshd' in ansible_facts.services and
         ansible_facts.services['sshd'].state == 'running')
    fail_msg: El servicio SSH no esta activo.
    success_msg: El servicio SSH esta activo.

- name: Comprobar que el puerto SSH responde
  ansible.builtin.wait_for:
    host: 127.0.0.1
    port: 22
    timeout: 5

- name: Crear backup de la configuracion
  ansible.builtin.copy:
    src: "{{ lab_root }}/app.conf"
    dest: "{{ lab_root }}/app.conf.bak"
    remote_src: true
    owner: root
    group: root
    mode: "0600"

- name: Consultar el backup
  ansible.builtin.stat:
    path: "{{ lab_root }}/app.conf.bak"
  register: backup_info

- name: Validar el backup
  ansible.builtin.assert:
    that:
      - backup_info.stat.exists
      - backup_info.stat.size | int > 0
    fail_msg: El backup no existe o esta vacio.
    success_msg: El backup existe y contiene datos.
```

## Paso 8: Crear el playbook principal

Crea `laboratorio-integrador/site.yml`:

```yaml
---
- name: Ejecutar laboratorio integrador independiente
  hosts: linux
  become: true
  gather_facts: true

  roles:
    - role: operacion_segura
```

## Paso 9: Validar y ejecutar

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check --ask-vault-pass
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

En la segunda ejecución el resultado esperado es:

```text
ok=N  changed=0  unreachable=0  failed=0
```

## Paso 10: Verificar sin revelar secretos

```bash
ansible linux -i inventory.ini -b \
  -m ansible.builtin.stat \
  -a "path=/opt/pit-integrador/app.conf" \
  --ask-vault-pass

ansible linux -i inventory.ini -b \
  -m ansible.builtin.stat \
  -a "path=/opt/pit-integrador/app.conf.bak" \
  --ask-vault-pass
```

## Preguntas de comprensión

1. ¿Qué archivos del laboratorio anterior utiliza este proyecto?
2. ¿Por qué no se imprime el token en la salida?
3. ¿Qué valida `wait_for`?
4. ¿Por qué el handler no corre en la segunda ejecución?
5. ¿Qué tarea detecta un backup vacío?
6. ¿Qué hace `no_log: true` en una tarea?

## Resumen de comandos

```bash
# Roles
ansible-galaxy role init roles/nombre
ansible-galaxy role list

# Vault
ansible-vault encrypt_string 'valor' --name 'variable'
ansible-vault view archivo.yml
ansible-playbook site.yml --ask-vault-pass

# Node Exporter
ansible ubuntu1 -i inventory.ini -b -m ansible.builtin.apt \
  -a "name=prometheus-node-exporter state=present" \
  --ask-become-pass

# Validación
ansible linux -i inventory.ini -m ansible.builtin.ping
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

## Próximos pasos

Como desafío adicional, intenta convertir los mini laboratorios en roles completos:

```text
roles/node_exporter
roles/backup_mariadb
roles/security
```

Cada rol debe incluir:
- Variables en `defaults/main.yml`
- Handlers
- Templates
- Validaciones con `assert` o `uri`
- Archivo `requirements.yml`
- Segunda ejecución con `changed=0`
