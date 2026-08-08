---

## Laboratorio 00: Inventarios Dinámicos con Docker

En este laboratorio práctico, aprenderás a configurar un inventario dinámico basado en la API de Docker para automatizar entornos multinodo.

---

## 1. Objetivos del Laboratorio

* Configurar un entorno multinodo emulado con Docker utilizando etiquetas (*labels*) y un inventario dinámico en Python.
* Validar el funcionanmiento del inventario dinamico eliminando y añadiendo nuevos contenedores.

---

## 2. Configuración del Entorno con Docker

Para lograr que los hosts dinámicos funcionen emulando máquinas y que tu lista de hosts se actualice automáticamente, utilizaremos contenedores y un script de Python conectado a la API de Docker.

### 2.1. El archivo `docker-compose.yml`

Crea el archivo para mantener activos los contenedores de prueba y etiquetarlos por grupos:

```yaml
version: '3.8'

services:
  web01:
    image: alpine:latest
    container_name: web01
    command: tail -f /dev/null
    labels:
      - "ansible_group=webservers"
      - "ansible_env=lab"

  web02:
    image: alpine:latest
    container_name: web02
    command: tail -f /dev/null
    labels:
      - "ansible_group=webservers"
      - "ansible_env=lab"

  db01:
    image: alpine:latest
    container_name: db01
    command: tail -f /dev/null
    labels:
      - "ansible_group=databases"
      - "ansible_env=lab"

```

---

### 2.2. El script de inventario dinámico (`inventory.py`)

Este script lee las etiquetas de los contenedores activos en tiempo real y genera la estructura JSON requerida por Ansible:

```python
#!/usr/bin/env python3
import json
import docker

def get_inventory():
    inventory = {
        "webservers": {"hosts": []},
        "databases": {"hosts": []},
        "_meta": {"hostvars": {}}
    }

    try:
        client = docker.from_env()
        containers = client.containers.list(filters={"status": "running"})
        
        for container in containers:
            labels = container.labels
            group = labels.get("ansible_group")
            
            if group in inventory:
                name = container.name
                inventory[group]["hosts"].append(name)
                inventory["_meta"]["hostvars"][name] = {
                    "ansible_connection": "docker"
                }
    except Exception as e:
        pass
            
    return inventory

if __name__ == "__main__":
    print(json.dumps(get_inventory(), indent=2))

```

---

## 3. Preparación del Entorno Virtual y Dependencias
Instala el paquete de entorno virtual del sistema y configura las librerías necesarias:
```bash
sudo apt install python3.14-venv
```

Ejecuta el siguiente comando en tu terminal para crear una carpeta con un entorno virtual aislado (por ejemplo, llamado `venv`):
```bash
python3 -m venv venv
```

Actívalo para que los comandos `pip` y `python` apunten al entorno aislado:
```bash
source venv/bin/activate
```

> [!NOTE]
> Verás que el nombre de tu terminal cambia mostrando `(venv)` al inicio).

Instala la librería de docker para python:
```bash
pip install docker
```

Dale permisos de ejecución al script de inventario:
```bash
chmod +x inventory.py
```

Levanta tu infraestructura con Docker Compose:
```bash
docker compose up -d
```

---

## 4. deteccion automatica de hosts de forma dinámica
Ejecuta los siguientes comandos para listar los hosts que el script recupera en tiempo real desde Docker:

* **Listar los hosts disponibles**
```bash
ansible all -i inventory.py --list-hosts
```

```bash
  hosts (4):
    web02
    web01
    db02
    db01
```

* **Visualizar la jerarquía de grupos en modo gráfico**
```bash
ansible-inventory -i inventory.py --graph
```

```bash
@all:
  |--@ungrouped:
  |--@webservers:
  |  |--web02
  |  |--web01
  |--@databases:
  |  |--db02
  |  |--db01
```

* **Consultar el reporte completo del inventario en formato JSON**
```bash
ansible-inventory -i inventory.py --list
```

```bash
{
    "_meta": {
        "hostvars": {
            "db01": {
                "ansible_connection": "docker"
            },
            "db02": {
                "ansible_connection": "docker"
            },
            "web01": {
                "ansible_connection": "docker"
            },
            "web02": {
                "ansible_connection": "docker"
            }
        },
        "profile": "inventory_legacy"
    },
    "all": {
        "children": [
            "ungrouped",
            "webservers",
            "databases"
        ]
    },
    "databases": {
        "hosts": [
            "db02",
            "db01"
        ]
    },
    "webservers": {
        "hosts": [
            "web02",
            "web01"
        ]
    }
}
```

---

## 5. Validación del Comportamiento Dinámico (Eliminación y Adición)

Comprueba la flexibilidad del inventario dinámico simulando cambios en la infraestructura de contenedores.

### 5.1. Validar después de eliminar un contenedor
Detiene y elimina uno de los nodos (por ejemplo, `db02`) para verificar que desaparece de forma automática del inventario:

```bash
docker compose stop db02
docker compose rm -f db02
```

Vuelve a consultar los hosts activos con Ansible:

```bash
ansible all -i inventory.py --list-hosts
```

```text
  hosts (3):
    web02
    web01
    db01
```

### 5.2. Validar después de añadir un nuevo contenedor

Vuelve a levantar el contenedor eliminado (o añade uno nuevo) para comprobar que se reincorpora automáticamente al inventario sin modificar ningún archivo estático:

```bash
docker compose up -d db02
```

Verifica nuevamente la lista de hosts detectados por Ansible:

```bash
ansible all -i inventory.py --list-hosts
```

```text
  hosts (4):
    web02
    web01
    db02
    db01
```
