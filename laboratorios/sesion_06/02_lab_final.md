# Laboratorio 02: Nextcloud en 3 niveles con Ansible

Esta versión despliega Nextcloud en dos nodos Ubuntu y deja la instalación terminada y conectada a MariaDB y Redis al acabar el playbook, sin pasos manuales en el navegador.

## Arquitectura y requisitos

| Nodo | Grupos | Servicios | Puertos |
| --- | --- | --- | --- |
| ubuntu-node1 | redis, mariadb | Redis + MariaDB (backend) | 6379, 3306 |
| ubuntu-node2 | nextcloud | Apache + PHP + Nextcloud (frontend) | 80 |

Siguen siendo tres niveles, pero la caché y la base de datos comparten el nodo backend. Los tres roles y el playbook no cambian: solo el inventario, que pone `ubuntu-node1` en dos grupos.

Requisitos en el nodo de control:

- `ansible-core` y las dos colecciones que usan los roles:

```bash
ansible-galaxy collection install community.mysql community.general
```

- Acceso SSH a los dos nodos (Ubuntu 22.04 o 24.04) con un usuario con sudo.

Estructura final del proyecto:

```text
lab02-nextcloud/
├── inventory.yml
├── site-nextcloud.yml
├── group_vars/
│   └── all/
│       └── secretos.yml      (cifrado con Vault)
└── roles/
    ├── redis_node/
    ├── mariadb_node/
    └── nextcloud_node/
```

## 1. Inventario y secretos

### A. Inventario (`inventory.yml`)

El archivo usa sintaxis YAML, así que su extensión debe ser `.yml`. Cambia las IPs por las de tus nodos.

```yaml
all:
  children:
    redis:
      hosts:
        ubuntu-node1:
          ansible_host: 192.168.1.11
    mariadb:
      hosts:
        ubuntu-node1:          # mismo nodo que Redis
    nextcloud:
      hosts:
        ubuntu-node2:
          ansible_host: 192.168.1.12
    servers:
      children:
        redis:
        mariadb:
        nextcloud:
```

Un host puede estar en varios grupos. Las variables de `ubuntu-node1` (como `ansible_host`) se definen una sola vez y valen para los dos grupos. Así, `groups['redis'][0]` y `groups['mariadb'][0]` devuelven el mismo nodo, y el rol de Nextcloud recibe la misma IP para la base de datos y para Redis. Para volver a tres nodos basta con poner otro host en el grupo `mariadb`.

La contraseña de `become` ya no está aquí: pasa al archivo cifrado.

### B. Secretos con Ansible Vault

```bash
mkdir -p group_vars/all
ansible-vault create group_vars/all/secretos.yml
```

Contenido del archivo:

```yaml
---
ansible_become_password: "password"
nc_db_password: "SecretoNextcloud2026!"
nc_admin_password: "AdminNextcloudSeguro!"
redis_password: "RedisSecreto2026!"
mariadb_db: "nextcloud_db"
mariadb_user: "nextcloud_user"
```

Para revisarlo o editarlo después usa `ansible-vault view` o `ansible-vault edit` sobre el mismo archivo.

## 2. Inicializar los roles

```bash
mkdir -p roles
cd roles
ansible-galaxy role init redis_node
ansible-galaxy role init mariadb_node
ansible-galaxy role init nextcloud_node
cd ..
```

## 3. Rol 1: Nodo Redis (caché)

Redis escucha solo en `localhost` por defecto. Además tiene `protected-mode` activo: sin contraseña, rechaza las conexiones externas aunque escuche en `0.0.0.0`. Por eso le asignamos una contraseña que viene del Vault.

### `roles/redis_node/tasks/main.yml`

```yaml
---
- name: Instalar servidor Redis
  ansible.builtin.apt:
    name: redis-server
    state: present
    update_cache: yes

- name: Permitir conexiones externas en Redis
  ansible.builtin.lineinfile:
    path: /etc/redis/redis.conf
    regexp: '^bind 127\.0\.0\.1'
    line: 'bind 0.0.0.0'
  notify: reiniciar redis

- name: Proteger Redis con contraseña (desde Vault)
  ansible.builtin.lineinfile:
    path: /etc/redis/redis.conf
    regexp: '^#?\s*requirepass '
    line: 'requirepass {{ redis_password }}'
  no_log: true
  notify: reiniciar redis

- name: Iniciar y habilitar Redis
  ansible.builtin.service:
    name: redis-server
    state: started
    enabled: true
```

### `roles/redis_node/handlers/main.yml`

```yaml
---
- name: reiniciar redis
  ansible.builtin.service:
    name: redis-server
    state: restarted
```

## 4. Rol 2: Nodo MariaDB (base de datos)

Instala el motor, lo abre a la red y crea la base de datos y el usuario con la contraseña del Vault. Ansible se conecta como root por el socket Unix, así que no necesita contraseña de root. También se aplican los dos ajustes que Nextcloud recomienda para MariaDB.

### `roles/mariadb_node/tasks/main.yml`

```yaml
---
- name: Instalar MariaDB y librerias
  ansible.builtin.apt:
    name:
      - mariadb-server
      - python3-pymysql
    state: present
    update_cache: yes

- name: Configurar MariaDB para permitir conexiones externas
  ansible.builtin.lineinfile:
    path: /etc/mysql/mariadb.conf.d/50-server.cnf
    regexp: '^bind-address'
    line: 'bind-address = 0.0.0.0'
  notify: reiniciar mariadb

- name: Ajustes recomendados por Nextcloud
  community.general.ini_file:
    path: /etc/mysql/mariadb.conf.d/50-server.cnf
    section: mysqld
    option: "{{ item.option }}"
    value: "{{ item.value }}"
  loop:
    - { option: transaction_isolation, value: READ-COMMITTED }
    - { option: binlog_format, value: ROW }
  notify: reiniciar mariadb

- name: Iniciar MariaDB
  ansible.builtin.service:
    name: mariadb
    state: started
    enabled: true

- name: Crear base de datos para Nextcloud
  community.mysql.mysql_db:
    name: "{{ mariadb_db }}"
    state: present
    login_unix_socket: /var/run/mysqld/mysqld.sock

- name: Crear usuario de DB usando Ansible Vault
  community.mysql.mysql_user:
    name: "{{ mariadb_user }}"
    password: "{{ nc_db_password }}"
    priv: "{{ mariadb_db }}.*:ALL"
    host: '%'
    state: present
    login_unix_socket: /var/run/mysqld/mysqld.sock
  no_log: true
```

### `roles/mariadb_node/handlers/main.yml`

```yaml
---
- name: reiniciar mariadb
  ansible.builtin.service:
    name: mariadb
    state: restarted
```

Los handlers se ejecutan al final de esta play, así que MariaDB ya escucha en la red cuando empieza la play de Nextcloud.

## 5. Rol 3: Nodo Nextcloud (web y aplicación)

Este rol usa **bucles** (`loop`) para los paquetes y la configuración, **condicionales** (`when`, `creates`, `removes`) para no repetir trabajo y **variables cruzadas** (`hostvars`) para obtener las IPs de los otros nodos. Nextcloud se instala con `occ` dentro del propio playbook, así que ya no hace falta `autoconfig.php`.

### A. Variables cruzadas: `roles/nextcloud_node/vars/main.yml`

```yaml
---
db_host: "{{ hostvars[groups['mariadb'][0]]['ansible_default_ipv4']['address'] }}"
redis_host: "{{ hostvars[groups['redis'][0]]['ansible_default_ipv4']['address'] }}"
nc_ip: "{{ ansible_default_ipv4.address }}"
```

Atención: si tus nodos tienen dos interfaces (por ejemplo, NAT + red interna en Vagrant o VirtualBox), `ansible_default_ipv4` puede devolver la IP de la NAT. En ese caso usa `hostvars[...]['ansible_host']`.

### B. `roles/nextcloud_node/tasks/main.yml`

```yaml
---
- name: Instalar Apache y dependencias PHP mediante bucle
  ansible.builtin.apt:
    name: "{{ item }}"
    state: present
    update_cache: yes
  loop:
    - apache2
    - libapache2-mod-php
    - php
    - php-mysql
    - php-xml
    - php-mbstring
    - php-zip
    - php-gd
    - php-curl
    - php-redis
    - php-intl
    - php-bcmath
    - php-gmp
    - unzip
    - acl          # necesario para become_user: www-data

- name: Comprobar si Nextcloud ya esta descargado (Condicional)
  ansible.builtin.stat:
    path: /var/www/nextcloud/index.php
  register: nextcloud_check

- name: Descargar y extraer Nextcloud
  ansible.builtin.unarchive:
    src: https://download.nextcloud.com/server/releases/latest.zip
    dest: /var/www/
    remote_src: yes
  when: not nextcloud_check.stat.exists

- name: Asignar permisos al usuario web (www-data)
  ansible.builtin.file:
    path: /var/www/nextcloud
    owner: www-data
    group: www-data
    recurse: yes

- name: Generar VirtualHost de Apache
  ansible.builtin.template:
    src: nextcloud.conf.j2
    dest: /etc/apache2/sites-available/nextcloud.conf
  notify: recargar apache

- name: Habilitar modulos de Apache
  community.general.apache2_module:
    name: "{{ item }}"
    state: present
  loop:
    - rewrite
    - headers
  notify: recargar apache

- name: Habilitar sitio Nextcloud
  ansible.builtin.command: a2ensite nextcloud.conf
  args:
    creates: /etc/apache2/sites-enabled/nextcloud.conf
  notify: recargar apache

- name: Deshabilitar sitio por defecto
  ansible.builtin.command: a2dissite 000-default.conf
  args:
    removes: /etc/apache2/sites-enabled/000-default.conf
  notify: recargar apache

- name: Instalar Nextcloud con occ (solo si no esta instalado)
  ansible.builtin.command:
    argv:
      - php
      - occ
      - maintenance:install
      - --database=mysql
      - "--database-host={{ db_host }}"
      - "--database-name={{ mariadb_db }}"
      - "--database-user={{ mariadb_user }}"
      - "--database-pass={{ nc_db_password }}"
      - --admin-user=admin
      - "--admin-pass={{ nc_admin_password }}"
      - --data-dir=/var/www/nextcloud/data
    chdir: /var/www/nextcloud
    creates: /var/www/nextcloud/config/config.php
  become_user: www-data
  no_log: true

- name: Configurar Redis, dominio de confianza y URL
  ansible.builtin.command:
    argv: "{{ ['php', 'occ', 'config:system:set'] + item }}"
    chdir: /var/www/nextcloud
  become_user: www-data
  loop:
    - ['memcache.locking', '--value=\OC\Memcache\Redis']
    - ['memcache.distributed', '--value=\OC\Memcache\Redis']
    - ['redis', 'host', '--value={{ redis_host }}']
    - ['redis', 'port', '--value=6379', '--type=integer']
    - ['redis', 'password', '--value={{ redis_password }}']
    - ['trusted_domains', '1', '--value={{ nc_ip }}']
    - ['overwrite.cli.url', '--value=http://{{ nc_ip }}']
  changed_when: false   # occ sobrescribe el mismo valor en cada ejecucion
  no_log: true
```

Notas:

- `argv` pasa cada argumento tal cual, sin que el shell lo interprete. Así no se rompen las contraseñas con caracteres especiales ni las barras invertidas de `\OC\Memcache\Redis`.
- `creates: config/config.php` es el condicional de la instalación: ese archivo solo existe cuando Nextcloud ya está instalado.
- Instalar con `loop` sirve para practicar bucles. En producción es más rápido pasar la lista directamente en `name:`, porque se hace en una sola transacción de apt.

### C. Plantilla de Apache: `roles/nextcloud_node/templates/nextcloud.conf.j2`

```apache
<VirtualHost *:80>
  DocumentRoot /var/www/nextcloud/
  ServerName {{ ansible_default_ipv4.address }}

  <Directory /var/www/nextcloud/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>
</VirtualHost>
```

### D. `roles/nextcloud_node/handlers/main.yml`

```yaml
---
- name: recargar apache
  ansible.builtin.service:
    name: apache2
    state: reloaded
```

El directorio de datos dentro de `/var/www/nextcloud` sirve para el laboratorio. En producción conviene ponerlo fuera de la raíz web, por ejemplo en `/srv/nextcloud-data`.

## 6. El playbook maestro (`site-nextcloud.yml`)

Los `hosts:` de cada play tienen que coincidir con los grupos del inventario: `redis`, `mariadb` y `nextcloud`. La primera play recoge los facts de todos los nodos. Así `hostvars` tiene las IPs incluso si más adelante ejecutas solo una parte.

```yaml
---
- name: 0. Recoger facts de todos los nodos
  hosts: servers
  gather_facts: true
  tasks: []

- name: 1. Desplegar Servidor de Cache
  hosts: redis
  become: true
  gather_facts: false
  roles:
    - redis_node

- name: 2. Desplegar Base de Datos
  hosts: mariadb
  become: true
  gather_facts: false
  roles:
    - mariadb_node

- name: 3. Desplegar Aplicacion Web
  hosts: nextcloud
  become: true
  gather_facts: false
  roles:
    - nextcloud_node
```

## 7. Ejecución y verificación

1. Revisa la sintaxis:

    ```bash
    ansible-playbook -i inventory.yml site-nextcloud.yml --syntax-check --ask-vault-pass
    ```

2. Despliega:

    ```bash
    ansible-playbook -i inventory.yml site-nextcloud.yml --ask-vault-pass
    ```

3. Comprueba en el nodo web que Nextcloud está instalado y usa Redis:

    ```bash
    cd /var/www/nextcloud
    sudo -u www-data php occ status
    sudo -u www-data php occ config:system:get memcache.distributed
    ```

    `occ status` debe mostrar `installed: true`.

4. Abre `http://192.168.1.12` (la IP de tu nodo web) e inicia sesión como `admin` con la contraseña del Vault.

5. Prueba la idempotencia: vuelve a ejecutar el paso 2. Ahora todas las tareas deberían salir en `ok`, con `changed=0`.

## Anexo: cambios respecto a la guía original

| Guía original | Problema | Corrección |
| --- | --- | --- |
| `hosts: redis_cache`, `mariadb_db`, `nextcloud_web` | No existen en el inventario: las plays no se ejecutaban | `hosts: redis`, `mariadb`, `nextcloud` |
| `inventory.ini` con contenido YAML | El plugin INI no lee YAML | Renombrado a `inventory.yml` |
| `ansible_become_password` en el inventario | Contraseña en texto plano en un lab sobre Vault | Movida a `secretos.yml` |
| Redis con `bind 0.0.0.0` sin más | `protected-mode` bloquea las conexiones externas | `requirepass` con contraseña del Vault |
| `autoconfig.php` | No configura Redis; la instalación esperaba a la primera visita web | `occ maintenance:install` + `occ config:system:set` |
| `command` con `a2enmod` y `a2ensite` | Siempre `changed`; el handler se disparaba en cada ejecución | `apache2_module` y `creates` / `removes` |
| Sin play de facts | `hostvars` fallaba al usar `--limit` | Play 0 con `gather_facts` en `servers` |
| Sin instrucciones de colecciones | `community.mysql` no viene con ansible-core | `ansible-galaxy collection install` |
| Faltaban `php-intl`, `php-bcmath`, `php-gmp` y `acl` | Advertencias en Nextcloud; `become_user` fallaba | Añadidos al bucle de apt |
| Sin `no_log` en tareas con secretos | Contraseñas visibles en la salida con `-v` | `no_log: true` |
