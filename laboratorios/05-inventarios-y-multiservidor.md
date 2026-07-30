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

*Esquema de arbol*
El comando `--graph` debe mostrar:
```bash
ansible-inventory -i inventory.ini --graph
```
```bash
@all:
  |--@ungrouped:
  |--@linux:
  |  |--@web:
  |  |  |--ubuntu1
  |  |  |--centos1
  |  |--@db:
  |  |  |--ubuntu1
```

*Esquema Json*
El comando `--list` debe mostrar:
```bash
ansible-inventory -i inventory.ini --list
```
```json
{
    "_meta": {
        "hostvars": {
            "centos1": {
                "ansible_become_password": "password",
                "ansible_python_interpreter": "/usr/bin/python3",
                "ansible_user": "ansible"
            },
            "ubuntu1": {
                "ansible_become_password": "password",
                "ansible_python_interpreter": "/usr/bin/python3",
                "ansible_user": "ansible"
            }
        }
    },
    "all": {
        "children": [
            "ungrouped",
            "linux"
        ]
    },
    "db": {
        "hosts": [
            "ubuntu1"
        ]
    },
    "linux": {
        "children": [
            "web",
            "db"
        ]
    },
    "web": {
        "hosts": [
            "ubuntu1",
            "centos1"
        ]
    }
}
```
*Esquema Json*
El comando `--list-hosts` debe mostrar:
```bash
ansible linux -i inventory.ini --list-hosts
```
```yaml
hosts (2):
  ubuntu1
  centos1
```

## Paso 4: Verificar conectividad

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

## Paso 5: Crear el playbook principal

Crea el archivo `site.yaml`:

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
ansible-playbook -i inventory.ini site.yaml --syntax-check
```
```yaml
playbook: site.yaml
```

### Mostrar hosts que serán afectados
```bash
ansible-playbook -i inventory.ini site.yaml --list-hosts
```
```yaml
playbook: site.yaml

  play #1 (web): Preparar servidores web con Nginx      TAGS: []
    pattern: ['web']
    hosts (2):
      ubuntu1
      centos1

  play #2 (db): Preparar servidor de base de datos      TAGS: []
    pattern: ['db']
    hosts (1):
      ubuntu1
```

### Ejecutar en modo check (simulación)
```bash
ansible-playbook -i inventory.ini site.yaml --check
```
```bash
PLAY [Preparar servidores web con Nginx] *************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [centos1]
ok: [ubuntu1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [ubuntu1]
changed: [centos1]

TASK [Iniciar y habilitar Nginx] *********************************************************************
ok: [ubuntu1]
fatal: [centos1]: FAILED! => {"changed": false, "msg": "Could not find the requested service nginx: host"}

PLAY [Preparar servidor de base de datos] ************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]

TASK [Instalar MariaDB y cliente Python] *************************************************************
changed: [ubuntu1]

TASK [Iniciar y habilitar MariaDB] *******************************************************************
fatal: [ubuntu1]: FAILED! => {"changed": false, "msg": "Could not find the requested service mariadb: host"}

PLAY RECAP *******************************************************************************************
centos1                    : ok=2    changed=1    unreachable=0    failed=1    skipped=1    rescued=0    ignored=0
ubuntu1                    : ok=5    changed=1    unreachable=0    failed=1    skipped=1    rescued=0    ignored=0
```

> [\!NOTE]
> el servicio de Nginx aún no existe en **ubuntu1** y **centos1**. El modo --check no realiza ningún cambio real en los servidores; solo simula qué pasaría si lo ejecutaras. Por eso el *failed*

### Primera ejecución
```bash
ansible-playbook -i inventory.ini site.yaml --ask-become-pass
```

Observa la salida. Deberías ver:

1. Tareas de Nginx ejecutándose en `ubuntu1` y `centos1`
2. Tareas de MariaDB ejecutándose en `ubuntu1`
3. El handler de MariaDB ejecutándose solo si hubo cambios en la configuración

```bash
PLAY [Preparar servidores web con Nginx] *************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [centos1]
ok: [ubuntu1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [centos1]
ok: [ubuntu1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [ubuntu1]
changed: [centos1]

TASK [Iniciar y habilitar Nginx] *********************************************************************
ok: [ubuntu1]
changed: [centos1]

PLAY [Preparar servidor de base de datos] ************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]

TASK [Instalar MariaDB y cliente Python] *************************************************************
changed: [ubuntu1]

TASK [Iniciar y habilitar MariaDB] *******************************************************************
changed: [ubuntu1]

TASK [Configurar direccion de escucha] ***************************************************************
changed: [ubuntu1]

TASK [Habilitar conexiones remotas en MySQL] *********************************************************
ok: [ubuntu1]

RUNNING HANDLER [Reiniciar MariaDB] ******************************************************************
changed: [ubuntu1]

PLAY RECAP *******************************************************************************************
centos1                    : ok=3    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
ubuntu1                    : ok=9    changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### Segunda ejecución
La segunda ejecución debe mostrar principalmente `ok` en lugar de `changed`. Esto demuestra la idempotencia.
```bash
ansible-playbook -i inventory.ini site.yml
```
```bash
PLAY [Preparar servidores web con Nginx] *************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]
ok: [centos1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [centos1]
ok: [ubuntu1]

TASK [Instalar Nginx] ********************************************************************************
skipping: [ubuntu1]
ok: [centos1]

TASK [Iniciar y habilitar Nginx] *********************************************************************
ok: [ubuntu1]
ok: [centos1]

PLAY [Preparar servidor de base de datos] ************************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [ubuntu1]

TASK [Instalar MariaDB y cliente Python] *************************************************************
ok: [ubuntu1]

TASK [Iniciar y habilitar MariaDB] *******************************************************************
ok: [ubuntu1]

TASK [Configurar direccion de escucha] ***************************************************************
ok: [ubuntu1]

TASK [Habilitar conexiones remotas en MySQL] *********************************************************
ok: [ubuntu1]

PLAY RECAP *******************************************************************************************
centos1                    : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
ubuntu1                    : ok=8    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

## Paso 7: Validar los servicios

### Verificar Nginx
```bash
ansible web -i inventory.ini -b -m ansible.builtin.command \
  -a "systemctl is-active nginx" 
```
```bash
ubuntu1 | CHANGED | rc=0 >>
active
centos1 | CHANGED | rc=0 >>
active
```

### Verificar MariaDB
```bash
ansible db -i inventory.ini -b -m ansible.builtin.command \
  -a "systemctl is-active mariadb"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
active
```

### Verificar puerto de MariaDB
```bash
ansible db -i inventory.ini -b -m ansible.builtin.shell \
  -a "ss -lntp | grep 3306"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
LISTEN 0      80           0.0.0.0:3306       0.0.0.0:*    users:(("mariadbd",pid=8384,fd=21))
```

## Paso 8: Explorar patrones de selección

**Solo web**
```bash
ansible web -i inventory.ini --list-hosts
```
```yaml
hosts (2):
  ubuntu1
  centos1
```

**Solo db**
```bash
ansible db -i inventory.ini --list-hosts
```
```yaml
hosts (1):
  ubuntu1
```

**Unión de grupos**
```bash
ansible 'web:db' -i inventory.ini --list-hosts
```
```yaml
hosts (2):
  ubuntu1
  centos1
```

**Linux excepto db**
```bash
ansible 'linux:!db' -i inventory.ini --list-hosts
```
```yaml
hosts (1):
  centos1
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

ansible db -i inventory.ini -b -m ansible.builtin.package \
  -a "name=mariadb-server,python3-pymysql state=absent" \
```

## Resumen
En este laboratorio aprendiste a:
- Crear un inventario estático con grupos y variables
- Ejecutar playbooks contra grupos específicos
- Utilizar `when` para ejecutar tareas según el sistema operativo
- Definir handlers que solo se ejecutan cuando hay cambios
- Validar servicios después de la automatización
- Demostrar idempotencia con múltiples ejecuciones
