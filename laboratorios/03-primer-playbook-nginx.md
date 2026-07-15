# Laboratorio 03: Despliegue de Nginx con Playbooks

En este laboratorio práctico, consolidarás tus conocimientos de Ansible creando, ejecutando y validando un Playbook completo que automatiza la instalación de Nginx, configura su servicio e implementa una página web personalizada.

---

## 1. Objetivos del Laboratorio

* Crear un archivo de Playbook (`nginx.yml`) en formato YAML estructurado.
* Realizar verificaciones de sintaxis y simulaciones de cambios (*Dry Run*).
* Ejecutar el playbook contra un entorno real de servidores y analizar el reporte final (*PLAY RECAP*).
* Validar la **idempotencia** realizando ejecuciones repetidas y modificaciones de contenido.

---

## 2. Instrucciones Paso a Paso

### Paso 1: Crear el archivo del Playbook
Dentro del nodo de control `ubuntu-c`, crea un archivo llamado `nginx.yml` en la misma carpeta donde se encuentra tu archivo `inventory.ini`:

```bash
nano nginx.yml
```

Copia y pega el siguiente código en el archivo:

```yaml
---
- name: Desplegar Servidor Web Nginx
  hosts: web
  become: true
  tasks:
    - name: 1. Instalar el paquete de Nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: 2. Iniciar y habilitar el servicio de Nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

    - name: 3. Publicar el index.html personalizado
      ansible.builtin.copy:
        dest: /var/www/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>Servidor Ansible</title>
          </head>
          <body>
              <h1>Servidor Gestionado con Ansible</h1>
              <p>Despliegue e infraestructura totalmente automatizados por la OTI.</p>
          </body>
          </html>
        owner: www-data
        group: www-data
        mode: '0644'
```

---

### Paso 2: Verificar la Sintaxis
Antes de lanzar el playbook, ejecuta una verificación sintáctica para evitar fallos de formato:
```bash
ansible-playbook -i inventory.ini nginx.yml --syntax-check
```
*Si la salida solo muestra el nombre del playbook, la sintaxis es correcta.*

---

### Paso 3: Simular el Despliegue (Dry Run)
Prueba qué cambios realizaría Ansible sin llegar a modificar los servidores:
```bash
ansible-playbook -i inventory.ini nginx.yml --check
```
*Inspecciona la salida para comprobar qué tareas se reportan como "changed" en la simulación.*

---

### Paso 4: Ejecutar el Playbook
Lanza la automatización para aplicar de verdad los cambios en los servidores remotos:
```bash
ansible-playbook -i inventory.ini nginx.yml
```

**Analiza el PLAY RECAP final:**
```text
PLAY RECAP **************************************************************************
ubuntu1                    : ok=4    changed=3    unreachable=0    failed=0
```
* **`ok=4`:** Cuatro tareas exitosas (incluyendo la recopilación de datos automática *Gathering Facts*).
* **`changed=3`:** Tres tareas realizaron cambios reales en el servidor (instaló, inició y copió el HTML).

---

### Paso 5: Validar el Funcionamiento del Sitio Web
Comprueba que Nginx está activo y responde con la página web personalizada desde tu nodo de control:

```bash
# Verificar estado del servicio por SSH mediante comandos remotos
ansible web -i inventory.ini -m command -a "systemctl status nginx"

# Hacer una petición HTTP al sitio web
ansible web -i inventory.ini -m uri -a "url=http://localhost"
```

---

## 3. Demostración Práctica de la Idempotencia

### Prueba A: Ejecutar el playbook sin cambios
Vuelve a lanzar exactamente el mismo comando de ejecución:
```bash
ansible-playbook -i inventory.ini nginx.yml
```
**Observa el RECAP:**
```text
PLAY RECAP **************************************************************************
ubuntu1                    : ok=4    changed=0    unreachable=0    failed=0
```
*Notarás que `changed=0`. Ansible determinó que el paquete ya existía, el servicio estaba corriendo y el archivo no tenía cambios. No se malgastaron recursos de CPU ni de disco.*

### Prueba B: Modificar una sola configuración
Abre el archivo `nginx.yml` y edita únicamente el texto del HTML (ejemplo: cambia "por la OTI" a "por el Administrador"). Vuelve a ejecutar:
```bash
ansible-playbook -i inventory.ini nginx.yml
```
**Observa la Salida:**
* La tarea de instalación de Nginx saldrá en **Verde (ok)**.
* La tarea de servicio saldrá en **Verde (ok)**.
* La tarea de copiar archivo saldrá en **Amarillo (changed)**.
* **PLAY RECAP:** `ok=4 changed=1`. Ansible solo aplicó el cambio específico del HTML.

---

[Anterior: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md) | [Siguiente: Índice del Curso](../README.md)
