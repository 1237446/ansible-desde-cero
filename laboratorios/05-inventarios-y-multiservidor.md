# Laboratorio 04: Inventarios y Multi-Servidor

## Objetivo del laboratorio

En este laboratorio crearás un inventario estático con grupos para web y base de datos, desplegarás Nginx en los servidores web y MariaDB en el servidor de base de datos, y utilizarás handlers para reiniciar servicios solo cuando sea necesario.

## Requisitos previos

- Laboratorio `spurin/diveintoansible-lab` activo
- Nodo de control `ubuntu-c` accesible
- Conexión SSH configurada con llaves

## Duración estimada

30 minutos

## Arquitectura del laboratorio

```text
control
├── ubuntu-c   -> nodo de control con Ansible
├── ubuntu1    -> nodo Ubuntu (web)
├── centos1    -> nodo CentOS (web)
├── ubuntu2    -> nodo Ubuntu
├── centos2    -> nodo CentOS
├── ubuntu3    -> nodo Ubuntu
└── centos3    -> nodo CentOS
```

Para este laboratorio usaremos `ubuntu1` y `centos1` como nodos web.

## Paso 1: Crear el directorio del proyecto

```bash
cd ~
mkdir -p ~/curso-ansible/sesion03
cd ~/curso-ansible/sesion03
```

## Paso 2: Crear el inventario estático

Crea el archivo `inventory.ini`:

```ini
[web]
ubuntu1
centos1

[db]
ubuntu1

[linux:children]
web
db

[linux:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
```

### Explicación

| Elemento | Función |
|---|---|
| `[web]` | Grupo que contiene los servidores web |
| `ubuntu1`, `centos1` | Hosts que pertenecen al grupo web |
| `[db]` | Grupo para el servidor de base de datos |
| `[linux:children]` | Crea un grupo padre que incluye otros grupos |
| `[linux:vars]` | Variables que se aplican a todos los hosts de linux |

## Paso 3: Inspeccionar el inventario

```bash
ansible-inventory -i inventory.ini --graph
ansible-inventory -i inventory.ini --list
ansible linux -i inventory.ini --list-hosts
```

El comando `--graph` debe mostrar:

```text
@linux:
  |--@web:
  |  |--ubuntu1
  |  |--centos1
  |--@db:
     |--ubuntu1
```

## Paso 4: Verificar conectividad

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

## Paso 5: Crear el playbook principal

Crea el archivo `site.yml`:

```yaml
---
- name: Preparar servidores web con Nginx
  hosts: web
  become: true
  tasks:
    - name: Instalar Nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
      when: ansible_os_family == "Debian"

    - name: Instalar Nginx
      ansible.builtin.dnf:
        name: nginx
        state: present
        update_cache: true
      when: ansible_os_family == "RedHat"

    - name: Iniciar y habilitar Nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

- name: Preparar servidor de base de datos
  hosts: db
  become: true
  tasks:
    - name: Instalar MariaDB y cliente Python
      ansible.builtin.apt:
        name:
          - mariadb-server
          - python3-pymysql
        state: present
        update_cache: true

    - name: Iniciar y habilitar MariaDB
      ansible.builtin.service:
        name: mariadb
        state: started
        enabled: true

    - name: Configurar dirección de escucha
      ansible.builtin.lineinfile:
        path: /etc/mysql/mariadb.conf.d/50-server.cnf
        regexp: '^bind-address'
        line: 'bind-address = 0.0.0.0'
        backup: true
      notify: Reiniciar MariaDB

    - name: Habilitar conexiones remotas en MySQL
      ansible.builtin.lineinfile:
        path: /etc/mysql/mariadb.conf.d/50-server.cnf
        regexp: '^#?skip-networking'
        line: 'skip-networking'
        state: absent
      notify: Reiniciar MariaDB

  handlers:
    - name: Reiniciar MariaDB
      ansible.builtin.service:
        name: mariadb
        state: restarted
```

## Paso 6: Validar y ejecutar

### Verificar sintaxis

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

### Mostrar hosts que serán afectados

```bash
ansible-playbook -i inventory.ini site.yml --list-hosts
```

### Ejecutar en modo check (simulación)

```bash
ansible-playbook -i inventory.ini site.yml --check --ask-become-pass
```

### Primera ejecución

```bash
ansible-playbook -i inventory.ini site.yml --ask-become-pass
```

Observa la salida. Deberías ver:

1. Tareas de Nginx ejecutándose en `ubuntu1` y `centos1`
2. Tareas de MariaDB ejecutándose en `ubuntu1`
3. El handler de MariaDB ejecutándose solo si hubo cambios en la configuración

### Segunda ejecución

```bash
ansible-playbook -i inventory.ini site.yml --ask-become-pass
```

La segunda ejecución debe mostrar principalmente `ok` en lugar de `changed`. Esto demuestra la idempotencia.

## Paso 7: Validar los servicios

### Verificar Nginx

```bash
ansible web -i inventory.ini -b -m ansible.builtin.command \
  -a "systemctl is-active nginx" \
  --ask-become-pass
```

### Verificar MariaDB

```bash
ansible db -i inventory.ini -b -m ansible.builtin.command \
  -a "systemctl is-active mariadb" \
  --ask-become-pass
```

### Verificar puerto de MariaDB

```bash
ansible db -i inventory.ini -b -m ansible.builtin.shell \
  -a "ss -lntp | grep 3306" \
  --ask-become-pass
```

## Paso 8: Explorar patrones de selección

```bash
# Solo web
ansible web -i inventory.ini --list-hosts

# Solo db
ansible db -i inventory.ini --list-hosts

# Unión de grupos
ansible 'web:db' -i inventory.ini --list-hosts

# Linux excepto db
ansible 'linux:!db' -i inventory.ini --list-hosts
```

## Preguntas de comprobación

1. ¿Cuántos hosts tiene el grupo `web`?
2. ¿Cuántos hosts tiene el grupo `linux`?
3. ¿Por qué el grupo `db` usa el mismo host que `web`?
4. ¿Qué sucede si ejecutas el playbook sin `--ask-become-pass`?
5. ¿Cuántas veces se ejecutó el handler en la primera ejecución?
6. ¿Cuántas veces se ejecutó el handler en la segunda ejecución?

## Desafío adicional

Modifica el inventario para agregar un segundo servidor de base de datos `centos1` al grupo `db`. Luego ejecuta el playbook nuevamente y observa cómo Ansible instala MariaDB en ambos hosts automáticamente.

## Limpieza

Para eliminar los recursos creados:

```bash
ansible web -i inventory.ini -b -m ansible.builtin.package \
  -a "name=nginx state=absent" \
  --ask-become-pass

ansible db -i inventory.ini -b -m ansible.builtin.package \
  -a "name=mariadb-server,python3-pymysql state=absent" \
  --ask-become-pass
```

## Resumen

En este laboratorio aprendiste a:

- Crear un inventario estático con grupos y variables
- Ejecutar playbooks contra grupos específicos
- Utilizar `when` para ejecutar tareas según el sistema operativo
- Definir handlers que solo se ejecutan cuando hay cambios
- Validar servicios después de la automatización
- Demostrar idempotencia con múltiples ejecuciones
