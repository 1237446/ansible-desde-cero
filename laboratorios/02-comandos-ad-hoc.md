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
sudo docker exec -it ubuntu-c bash
```

### Paso 2: Crear el archivo de inventario
Crea un archivo de texto llamado `inventory.ini` en tu directorio actual:
```bash
cat > inventory.ini <<'EOF'
[web]
ubuntu1

[db]
centos1

[all:vars]
ansible_user=ansible
ansible_become_password=password
EOF
```

### Paso 3: Verificar que Ansible detecte los hosts
Ejecuta el siguiente comando para listar las máquinas de tu inventario:
```bash
ansible all -i inventory.ini --list-hosts
```
*Deberías ver listados los servidores `ubuntu1` y `centos1` en la salida.*
```bash
hosts (2):
  ubuntu1
  centos1
```

### Paso 4: Configurar autenticación por Clave SSH
Generar la clave SSH en el nodo de control:
```bash
ssh-keygen -t rsa -b 4096
```

Copiar la clave pública a los servidores remotos:
```bash
ssh-copy-id ansible@ubuntu1
ssh-copy-id ansible@centos1
```

---

## 3. Ejercicios Prácticos Guiados

### Ejercicio 1: Comprobar conectividad global
Envía una señal para comprobar que Ansible puede comunicarse por SSH y tiene listo Python en los dos servidores:
```bash
ansible all -i inventory.ini -m ping
```

**Salida Esperada:**
```json
ubuntu1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}
centos1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "ping": "pong"
}
```

---

### Ejercicio 2: Consultar métricas del sistema
Consulta el tiempo de actividad (`uptime`) y el nombre de host oficial de todos los servidores del grupo `web`:

**uptime:**
```bash
ansible web -i inventory.ini -m command -a "uptime"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
 22:09:52 up 33 min,  1 user,  load average: 0.02, 0.55, 1.18
```

**hostname:**
```bash
ansible all -i inventory.ini -m command -a "hostname"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
ubuntu1
centos1 | CHANGED | rc=0 >>
centos1
```

---

### Ejercicio 3: Transferir un archivo de configuración rápido
Usa el módulo `copy` para enviar una línea de texto a un archivo remoto y luego comprueba que se copió correctamente:

1. **Copiar contenido:**
   ```bash
   ansible web -i inventory.ini -m copy -a "content='Prueba de automatizacion\n' dest=/tmp/prueba.txt"
   ```
   *Notarás que la salida sale en color **Amarillo** (changed: true) porque el archivo no existía en el destino.*
   ```json
   ubuntu1 | CHANGED => {
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
   ansible web -i inventory.ini -m command -a "cat /tmp/prueba.txt"
   ```
   ```bash
    ubuntu1 | CHANGED | rc=0 >>
    Prueba de automatizacion
   ```
3. **Ejecutar la copia nuevamente:**
   Vuelve a lanzar el comando del paso 1. Notarás que ahora el resultado es verde (`ok`) e indica `"changed": false`. Esto demuestra la **idempotencia** de Ansible: al detectar que el archivo remoto ya tiene el mismo contenido, no lo sobrescribe innecesariamente.
   ```json
    ubuntu1 | SUCCESS => {
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
ansible all -i inventory.ini -m setup -a "filter=ansible_distribution*"
```
   ```json
    ubuntu1 | SUCCESS => {
        "ansible_facts": {
            "ansible_distribution": "Ubuntu",
            "ansible_distribution_file_parsed": true,
            "ansible_distribution_file_path": "/etc/os-release",
            "ansible_distribution_file_variety": "Debian",
            "ansible_distribution_major_version": "22",
            "ansible_distribution_release": "jammy",
            "ansible_distribution_version": "22.04",
            "discovered_interpreter_python": "/usr/bin/python3.10"
        },
        "changed": false
    }
    centos1 | SUCCESS => {
        "ansible_facts": {
            "ansible_distribution": "CentOS",
            "ansible_distribution_file_parsed": true,
            "ansible_distribution_file_path": "/etc/centos-release",
            "ansible_distribution_file_variety": "CentOS",
            "ansible_distribution_major_version": "9",
            "ansible_distribution_release": "Stream",
            "ansible_distribution_version": "9",
            "discovered_interpreter_python": "/usr/bin/python3.9"
        },
        "changed": false
    }
   ```

---

[Anterior: Laboratorio 01 - Autobiografía YAML](./01-autobiografia-yaml.md) | [Siguiente: Laboratorio 03 - Primer Playbook Nginx](./03-primer-playbook-nginx.md)
