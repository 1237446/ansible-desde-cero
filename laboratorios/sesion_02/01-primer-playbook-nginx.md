# Laboratorio 01: Despliegue de Nginx con Playbooks

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
Dentro del nodo de control `ansible-control`, crea un archivo llamado `nginx-ubuntu.yml`:

```bash
nano nginx-ubuntu.yml
```

Copia y pega el siguiente código en el archivo:

```yaml
---
- name: Desplegar Servidor Web Nginx
  hosts: ubuntu
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
              <h1>Servidor Ubuntu Linux con Ansible</h1>
              <p>Despliegue e infraestructura totalmente automatizados por la OTI.</p>
          </body>
          </html>
        owner: www-data
        group: www-data
        mode: '0644'
```

---

### Paso 2: Ejecutar el Playbook
Lanza la automatización para aplicar de verdad los cambios en los servidores remotos:
```bash
ansible-playbook nginx-ubuntu.yml
```

**Analiza el PLAY RECAP final:**
```bash
PLAY [Desplegar Servidor Web Nginx] *************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [ubuntu-node1]

TASK [1. Instalar el paquete de Nginx] **********************************************************************************************
changed: [ubuntu-node1]

TASK [2. Iniciar y habilitar el servicio de Nginx] **********************************************************************************
changed: [ubuntu-node1]

TASK [3. Publicar el index.html personalizado] **************************************************************************************
changed: [ubuntu-node1]

PLAY RECAP **************************************************************************************************************************
ubuntu-node1               : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```
* **`ok=4`:** Cuatro tareas exitosas (incluyendo la recopilación de datos automática *Gathering Facts*).
* **`changed=3`:** Tres tareas realizaron cambios reales en el servidor (instaló, inició y copió el HTML).

---

### Paso 3: Validar el Funcionamiento del Sitio Web
Comprueba que Nginx está activo y responde con la página web personalizada desde tu nodo de control:

**Verificar estado del servicio por SSH mediante comandos remotos**
```bash
ansible ubuntu -m command -a "systemctl status nginx"
```
```bash
ubuntu-node1 | CHANGED | rc=0 >>
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-08-13 17:32:57 UTC; 38s ago
 Invocation: 28b6ba66c472496289c15b92ede5d61e
       Docs: man:nginx(8)
    Process: 484 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 486 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 487 (nginx)
      Tasks: 21 (limit: 2673)
     Memory: 15.9M (peak: 20.1M)
        CPU: 26ms
     CGroup: /system.slice/nginx.service
             ├─487 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─488 "nginx: worker process"
             ├─489 "nginx: worker process"
             ├─490 "nginx: worker process"
             ├─491 "nginx: worker process"
             ├─492 "nginx: worker process"
             ├─494 "nginx: worker process"
             ├─495 "nginx: worker process"
             ├─496 "nginx: worker process"
             ├─497 "nginx: worker process"
             ├─498 "nginx: worker process"
             ├─499 "nginx: worker process"
             ├─500 "nginx: worker process"
             ├─501 "nginx: worker process"
             ├─502 "nginx: worker process"
             ├─503 "nginx: worker process"
             ├─504 "nginx: worker process"
             ├─505 "nginx: worker process"
             ├─506 "nginx: worker process"
             ├─507 "nginx: worker process"
             └─508 "nginx: worker process"

Aug 13 17:32:57 3bf9d81f51d3 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Aug 13 17:32:57 3bf9d81f51d3 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

**Hacer una petición HTTP al sitio web**
```bash
ansible ubuntu -m uri -a "url=http://localhost"
```

```json
ubuntu-node1 | SUCCESS => {
    "accept_ranges": "bytes",
    "changed": false,
    "connection": "close",
    "content_length": "221",
    "content_type": "text/html",
    "cookies": {},
    "cookies_string": "",
    "date": "Thu, 13 Aug 2026 17:35:05 GMT",
    "elapsed": 0,
    "etag": "\"6a7dffc9-dd\"",
    "last_modified": "Thu, 13 Aug 2026 17:32:57 GMT",
    "msg": "OK (221 bytes)",
    "redirected": false,
    "server": "nginx/1.28.3 (Ubuntu)",
    "status": 200,
    "url": "http://localhost"
}
```

---

## 3. Demostración Práctica de la Idempotencia

### Prueba A: Ejecutar el playbook sin cambios
Vuelve a lanzar exactamente el mismo comando de ejecución:
```bash
ansible-playbook nginx.yml
```
**Observa el RECAP:**
```bash
PLAY [Desplegar Servidor Web Nginx] *************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [ubuntu-node1]

TASK [1. Instalar el paquete de Nginx] **********************************************************************************************
ok: [ubuntu-node1]

TASK [2. Iniciar y habilitar el servicio de Nginx] **********************************************************************************
ok: [ubuntu-node1]

TASK [3. Publicar el index.html personalizado] **************************************************************************************
ok: [ubuntu-node1]

PLAY RECAP **************************************************************************************************************************
ubuntu-node1               : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
*Notarás que `changed=0`. Ansible determinó que el paquete ya existía, el servicio estaba corriendo y el archivo no tenía cambios. No se malgastaron recursos de CPU ni de disco.*

### Prueba B: Modificar una sola configuración
Abre el archivo `nginx.yml` y edita únicamente el texto del HTML (ejemplo: cambia "por la OTI" a "por el Administrador"). Vuelve a ejecutar:
```bash
ansible-playbook nginx.yml
```
**Observa la Salida:**
* La tarea de instalación de Nginx saldrá en **Verde (ok)**.
* La tarea de servicio saldrá en **Verde (ok)**.
* La tarea de copiar archivo saldrá en **Amarillo (changed)**.
* **PLAY RECAP:** `ok=4 changed=1`. Ansible solo aplicó el cambio específico del HTML.

---

[Anterior: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md) | [Siguiente: Índice del Curso](../README.md)
