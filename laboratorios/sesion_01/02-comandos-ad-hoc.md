# Laboratorio 02: Comandos Ad-Hoc e Inventario

En este laboratorio, configurarás tu primer archivo de inventario de Ansible y utilizarás comandos ad-hoc de una sola línea para inspeccionar y administrar remotamente tus servidores de prueba.

---

## 1. Objetivos del Laboratorio

* Crear y estructurar un archivo de inventario básico (`inventory.ini`).
* Ejecutar comandos de verificación de conectividad y recopilación de métricas de red.
* Usar módulos de administración (`ping`, `command`, `copy` y `setup`) en múltiples hosts remotos de forma simultánea.

---

## 2. Preparación del Inventario

### Paso 1: Entrar al contenedor de control
Asegúrate de estar dentro del nodo de control del laboratorio en tu VM:
```bash
sudo docker exec -it ansible-control bash
```

### Paso 2: Crear el archivo de inventario
Crea un archivo de texto llamado `inventory.ini` en tu directorio actual:
```bash
cat > inventario.ini <<'EOF'
[web]
ubuntu-node1
ubuntu-node2

[db]
rhel-node1
rhel-node2

[all:vars]
ansible_user=ansible
EOF
```

### Paso 3: Verificar que Ansible detecte los hosts
Ejecuta el siguiente comando para listar las máquinas de tu inventario:
```bash
ansible all -i inventario.ini --list-hosts
```
*Deberías ver listados los servidores `ubuntu1` y `centos1` en la salida.*
```bash
  hosts (4):
    ubuntu-node1
    ubuntu-node2
    rhel-node1
    rhel-node2
```

### Paso 4: Configurar autenticación por Clave SSH
Generar la clave SSH en el nodo de control:
```bash
ssh-keygen -t rsa -b 4096
```
```bash
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Created directory '/root/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa
Your public key has been saved in /root/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:lQWXbke+Rd4JkFRLqPLsvsjaykbFZNnh+PzGxHhx8es root@ubuntu-c
The key's randomart image is:
+---[RSA 4096]----+
|        o.++B=   |
|       +o. *o.= .|
|      +. .+o =.+o|
|       +ooo = o.=|
|      . S+ = . + |
|     .   o=   o  |
|    .   .  +   E |
|    ..o ...      |
|    .+o+.o.      |
+----[SHA256]-----+
```

Copiar la clave pública a los servidores remotos:
```bash
ssh-copy-id ansible@ubuntu-node1
ssh-copy-id ansible@rhel-node1
```

---

## 3. Ejercicios Prácticos Guiados

### Ejercicio 1: Comprobar conectividad global
Envía una señal para comprobar que Ansible puede comunicarse por SSH y tiene listo Python en los dos servidores:
```bash
ansible all -i inventario.ini -m ping
```

**Salida Esperada:**
```json
[WARNING]: Host 'ubuntu-node1' is using the discovered Python interpreter at '/usr/bin/python3.14', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ubuntu-node1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.14"
    },
    "changed": false,
    "ping": "pong"
}
[WARNING]: Host 'rhle-node1' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
rhle-node1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "ping": "pong"
}
```
El aviso de Ansible es un mensaje informativo estándar. Ansible te está avisando de que tuvo que "adivinar" qué versión de Python usar en la máquina remota

> [\!TIP]
> Para quitar esta advertencia y asegurarte de que Ansible use siempre el mismo intérprete, puedes definir la ruta explícitamente de dos formas:

#### hosts
```ini
[all]
ubuntu-node1 ansible_python_interpreter=/usr/bin/python3
```
#### ansible.cfg
```ini
[defaults]
# Fuerza a Ansible a usar python3 explícitamente en todos los nodos
interpreter_python = /usr/bin/python3
```

```json
ubuntu-node1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
ubuntu-node2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
rhle-node2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
rhle-node1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

```

---

### Ejercicio 2: Consultar métricas del sistema
Consulta el tiempo de actividad (`uptime`) y el nombre de host oficial de todos los servidores del grupo `web`:

**uptime:**
```bash
ansible web -i inventario.ini -m command -a "uptime"
```
```bash
ubuntu-node2 | CHANGED | rc=0 >>
 11:56:00 up 1 day, 18:20,  0 users,  load average: 0.41, 0.45, 0.35
ubuntu-node1 | CHANGED | rc=0 >>
 11:56:00 up 1 day, 18:20,  0 users,  load average: 0.41, 0.45, 0.35
```

**hostname:**
```bash
ansible all -i inventory.ini -m command -a "hostname"
```
```bash
ubuntu-node1 | CHANGED | rc=0 >>
6d81b4d2884f
ubuntu-node2 | CHANGED | rc=0 >>
775e461c868c
rhle-node1 | CHANGED | rc=0 >>
c777061997c1
rhle-node2 | CHANGED | rc=0 >>
eb685cc1af1f
```

---

### Ejercicio 3: Transferir un archivo de configuración rápido
Usa el módulo `copy` para enviar una línea de texto a un archivo remoto y luego comprueba que se copió correctamente:

1. **Copiar contenido:**
   ```bash
   ansible web -i inventario.ini -m copy -a "content='Prueba de automatizacion\n' dest=/tmp/prueba.txt"
   ```
   *Notarás que la salida sale en color **Amarillo** (changed: true) porque el archivo no existía en el destino.*
   ```json
   ubuntu-node1 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": true,
    "checksum": "e98f5fe60051f0bc6c23eb77b1eaea83545eea0b",
    "dest": "/tmp/prueba.txt",
    "gid": 1000,
    "group": "ansible",
    "md5sum": "7c80d253156d16819ef9e5b5eaaea635",
    "mode": "0644",
    "owner": "ansible",
    "size": 25,
    "src": "/home/ansible/.ansible/tmp/ansible-tmp-1785363032.2224648-836-124595037641333/.source.txt",
    "state": "file",
    "uid": 1000
   }
   ```

2. **Verificar el contenido en el destino:**
   ```bash
   ansible web -i inventario.ini -m command -a "cat /tmp/prueba.txt"
   ```
   ```bash
    ubuntu-node1 | CHANGED | rc=0 >>
    Prueba de automatizacion
   ```
3. **Ejecutar la copia nuevamente:**
   Vuelve a lanzar el comando del paso 1. Notarás que ahora el resultado es verde (`ok`) e indica `"changed": false`. Esto demuestra la **idempotencia** de Ansible: al detectar que el archivo remoto ya tiene el mismo contenido, no lo sobrescribe innecesariamente.
   ```json
    ubuntu1-node1 | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python3.10"
        },
        "changed": false,
        "checksum": "e98f5fe60051f0bc6c23eb77b1eaea83545eea0b",
        "dest": "/tmp/prueba.txt",
        "gid": 1000,
        "group": "ansible",
        "mode": "0644",
        "owner": "ansible",
        "path": "/tmp/prueba.txt",
        "size": 25,
        "state": "file",
        "uid": 1000
    }
   ```
---

### Ejercicio 4: Recopilar Facts (Setup)
Inspecciona la memoria libre y la distribución de Linux de tus servidores gestionados consultando sus "facts":
```bash
# Filtrar y mostrar solo la versión del SO
ansible all -i inventario.ini -m setup -a "filter=ansible_distribution*"
```
   ```json
    rhle-node1 | SUCCESS => {
        "ansible_facts": {
            "ansible_distribution": "Rocky",
            "ansible_distribution_file_parsed": true,
            "ansible_distribution_file_path": "/etc/redhat-release",
            "ansible_distribution_file_variety": "RedHat",
            "ansible_distribution_major_version": "9",
            "ansible_distribution_release": "Blue Onyx",
            "ansible_distribution_version": "9.8"
        },
        "changed": false
    }
    ubuntu-node1 | SUCCESS => {
        "ansible_facts": {
            "ansible_distribution": "Ubuntu",
            "ansible_distribution_file_parsed": true,
            "ansible_distribution_file_path": "/etc/os-release",
            "ansible_distribution_file_variety": "Debian",
            "ansible_distribution_major_version": "26",
            "ansible_distribution_release": "resolute",
            "ansible_distribution_version": "26.04"
        },
        "changed": false
    }
   ```

---

[Anterior: Laboratorio 00 - Preparacion del Laboratorio](./00-preparacion-del-laboratorio.md) | [Siguiente: Laboratorio 03 - Primer Playbook Nginx](./03-primer-playbook-nginx.md)
