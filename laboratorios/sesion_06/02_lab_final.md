# Laboratorio 16: Despliegue de Nextcloud en Arquitectura de 3 Niveles (Ubuntu)

Este proyecto final unifica todos los conceptos aprendidos (Ansible Vault, Roles, Bucles, Condicionales y Variables Cruzadas) en un caso de uso real y robusto. Separaremos los servicios en tres nodos Ubuntu distintos para replicar una arquitectura de producción:

1. **Nodo Caché:** Redis (Acelera las consultas de Nextcloud).
2. **Nodo Base de Datos:** MariaDB (Almacena metadatos y configuraciones).
3. **Nodo Aplicación:** Nextcloud + Apache + PHP (Interfaz web conectada a los otros dos).

---

## 1. Preparación del Inventario y Secretos

### A. Define tu Inventario (`inventory.ini`)

Asegúrate de que los tres nodos estén claramente separados en grupos distintos.

```ini
[nextcloud_web]
ubuntu-web ansible_host=192.168.1.10

[mariadb_db]
ubuntu-db ansible_host=192.168.1.11

[redis_cache]
ubuntu-cache ansible_host=192.168.1.12

```

### B. Protege las Contraseñas con Ansible Vault

Crea la estructura de variables globales y cifra el archivo:

```bash
mkdir -p group_vars/all
ansible-vault create group_vars/all/secretos.yml

```

Añade este contenido (asigna una contraseña de bóveda cuando te lo pida):

```yaml
---
nc_db_password: "SecretoNextcloud2026!"
nc_admin_password: "AdminNextcloudSeguro!"

```

---

## 2. Inicializar los Roles

En la raíz de tu proyecto, crea la carpeta `roles` e inicializa los tres componentes:

```bash
mkdir -p roles
cd roles
ansible-galaxy role init redis_node
ansible-galaxy role init mariadb_node
ansible-galaxy role init nextcloud_node
cd ..

```

---

## 3. Rol 1: Nodo Redis (Caché)

Redis viene configurado por defecto para escuchar solo en `localhost`. Necesitamos que escuche peticiones externas (desde el nodo web).

### Edita `roles/redis_node/tasks/main.yml`:

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

- name: Iniciar y habilitar Redis
  ansible.builtin.service:
    name: redis-server
    state: started
    enabled: true

```

### Crea el Handler `roles/redis_node/handlers/main.yml`:

```yaml
---
- name: reiniciar redis
  ansible.builtin.service:
    name: redis-server
    state: restarted

```

---

## 4. Rol 2: Nodo MariaDB (Base de Datos)

Aquí instalaremos el motor y crearemos la base de datos utilizando la contraseña extraída de Ansible Vault.

### Edita `roles/mariadb_node/tasks/main.yml`:

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

- name: Iniciar MariaDB
  ansible.builtin.service:
    name: mariadb
    state: started
    enabled: true

- name: Crear base de datos para Nextcloud
  community.mysql.mysql_db:
    name: nextcloud_db
    state: present
    login_unix_socket: /var/run/mysqld/mysqld.sock

- name: Crear usuario de DB usando Ansible Vault
  community.mysql.mysql_user:
    name: nextcloud_user
    password: "{{ nc_db_password }}"
    priv: 'nextcloud_db.*:ALL'
    host: '%'
    state: present
    login_unix_socket: /var/run/mysqld/mysqld.sock

```

### Crea el Handler `roles/mariadb_node/handlers/main.yml`:

```yaml
---
- name: reiniciar mariadb
  ansible.builtin.service:
    name: mariadb
    state: restarted

```

---

## 5. Rol 3: Nodo Nextcloud (Web y Aplicación)

Este rol utilizará **Bucles (`loop`)** para instalar múltiples dependencias de PHP, **Condicionales (`when`)** para no volver a descargar Nextcloud si ya existe, y **Plantillas (`hostvars`)** para conectarse a los otros dos nodos automáticamente.

### A. Edita `roles/nextcloud_node/tasks/main.yml`:

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
    - unzip

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

- name: Generar configuracion de auto-instalacion de Nextcloud
  ansible.builtin.template:
    src: autoconfig.php.j2
    dest: /var/www/nextcloud/config/autoconfig.php
    owner: www-data

- name: Generar VirtualHost de Apache
  ansible.builtin.template:
    src: nextcloud.conf.j2
    dest: /etc/apache2/sites-available/nextcloud.conf
  notify: recargar apache

- name: Habilitar sitio Nextcloud y modulos Apache
  ansible.builtin.command: "{{ item }}"
  loop:
    - a2ensite nextcloud.conf
    - a2enmod rewrite
    - a2dissite 000-default.conf
  notify: recargar apache

```

### B. Crea la Plantilla de Conexión `roles/nextcloud_node/templates/autoconfig.php.j2`:

Aquí inyectamos las IPs dinámicas y las contraseñas cifradas.

```php
<?php
$AUTOCONFIG = array(
  "dbtype"        => "mysql",
  "dbname"        => "nextcloud_db",
  "dbuser"        => "nextcloud_user",
  "dbpass"        => "{{ nc_db_password }}",
  "dbhost"        => "{{ hostvars[groups['mariadb_db'][0]]['ansible_host'] }}",
  "directory"     => "/var/www/nextcloud/data",
  "adminlogin"    => "admin",
  "adminpass"     => "{{ nc_admin_password }}",
);

```

### C. Crea la Plantilla de Apache `roles/nextcloud_node/templates/nextcloud.conf.j2`:

```apache
<VirtualHost *:80>
  DocumentRoot /var/www/nextcloud/
  ServerName localhost

  <Directory /var/www/nextcloud/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>
</VirtualHost>

```

### D. Crea el Handler `roles/nextcloud_node/handlers/main.yml`:

```yaml
---
- name: recargar apache
  ansible.builtin.service:
    name: apache2
    state: reloaded

```

---

## 6. El Playbook Maestro

Crea el archivo `site-nextcloud.yml` en la raíz del proyecto para orquestar los tres roles en orden (primero los backends, luego el frontend).

```yaml
---
- name: 1. Desplegar Servidor de Cache
  hosts: redis_cache
  become: true
  gather_facts: true
  roles:
    - redis_node

- name: 2. Desplegar Base de Datos
  hosts: mariadb_db
  become: true
  gather_facts: true
  roles:
    - mariadb_node

- name: 3. Desplegar Aplicacion Web
  hosts: nextcloud_web
  become: true
  gather_facts: true
  roles:
    - nextcloud_node

```

---

## 7. Ejecución Final

Para desplegar esta infraestructura multicapa, Ansible necesitará descifrar tu archivo Vault.

```bash
ansible-playbook -i inventory.ini site-nextcloud.yml --ask-vault-pass

```

Una vez que el proceso finalice, abre tu navegador web y visita la dirección IP de tu nodo Ubuntu Web (ej. `[http://192.168.1.10](http://192.168.1.10)`). Ansible habrá cruzado las variables de las IPs, configurado Redis y MariaDB, inyectado tus secretos de Vault, y Nextcloud estará listo para usarse directamente sin pasos adicionales de instalación manual.
