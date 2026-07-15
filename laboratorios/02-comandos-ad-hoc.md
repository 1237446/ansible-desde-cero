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
EOF
```

### Paso 3: Verificar que Ansible detecte los hosts
Ejecuta el siguiente comando para listar las máquinas de tu inventario:
```bash
ansible all -i inventory.ini --list-hosts
```
*Deberías ver listados los servidores `ubuntu1` y `centos1` en la salida.*

---

## 3. Ejercicios Prácticos Guiados

### Ejercicio 1: Comprobar conectividad global
Envía una señal para comprobar que Ansible puede comunicarse por SSH y tiene listo Python en los dos servidores:
```bash
ansible all -i inventory.ini -m ping
```

**Salida Esperada (Resumida):**
```json
ubuntu1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
centos1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

### Ejercicio 2: Consultar métricas del sistema
Consulta el tiempo de actividad (`uptime`) y el nombre de host oficial de todos los servidores del grupo `web`:
```bash
ansible web -i inventory.ini -m command -a "uptime"
ansible all -i inventory.ini -m command -a "hostname"
```

---

### Ejercicio 3: Transferir un archivo de configuración rápido
Usa el módulo `copy` para enviar una línea de texto a un archivo remoto y luego comprueba que se copió correctamente:

1. **Copiar contenido:**
   ```bash
   ansible web -i inventory.ini -m copy -a "content='Prueba de automatizacion\n' dest=/tmp/prueba.txt"
   ```
   *Notarás que la salida sale en color **Amarillo** (changed: true) porque el archivo no existía en el destino.*

2. **Verificar el contenido en el destino:**
   ```bash
   ansible web -i inventory.ini -m command -a "cat /tmp/prueba.txt"
   ```

3. **Ejecutar la copia nuevamente:**
   Vuelve a lanzar el comando del paso 1. Notarás que ahora el resultado es verde (`ok`) e indica `"changed": false`. Esto demuestra la **idempotencia** de Ansible: al detectar que el archivo remoto ya tiene el mismo contenido, no lo sobrescribe innecesariamente.

---

### Ejercicio 4: Recopilar Facts (Setup)
Inspecciona la memoria libre y la distribución de Linux de tus servidores gestionados consultando sus "facts":
```bash
# Filtrar y mostrar solo la versión del SO
ansible all -i inventory.ini -m setup -a "filter=ansible_distribution*"
```

---

[Anterior: Laboratorio 01 - Autobiografía YAML](./01-autobiografia-yaml.md) | [Siguiente: Laboratorio 03 - Primer Playbook Nginx](./03-primer-playbook-nginx.md)
