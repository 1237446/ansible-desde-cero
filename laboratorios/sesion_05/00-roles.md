

# Laboratorio 00: Despliegue Básico con Ansible Roles y Variables

## 1. Objetivos del Laboratorio

* Crear dos roles desde cero usando `ansible-galaxy role init`.
* Utilizar el archivo `vars/main.yml` de cada rol para definir variables locales.
* Desplegar un motor de base de datos en servidores Rocky (`dbservers`).
* Desplegar un servidor web con una página HTML personalizada en servidores Ubuntu (`webservers`).
* Escribir un Playbook maestro que asigne cada rol a su grupo correspondiente.

---

## 2. Paso 1: Preparar el Inventario

Asegúrate de que tu archivo `inventario.yaml` tenga los grupos definidos exactamente como los necesitamos:

```yaml
all:
  children:
    webservers:
      hosts:
        ubuntu-node1:
        ubuntu-node2:
        ubuntu-node3:
    dbservers:
      hosts:
        rocky-node1:
        rocky-node2:
        rocky-node3:
    servers:
      children:
        webservers:
        dbservers:
  vars:
    ansible_become_password: password
```

---

## 3. Paso 2: Crear la estructura de los Roles

En tu nodo de control, colócate en la carpeta de tu proyecto, crea el directorio `roles` y genera la estructura básica:

```bash
mkdir -p roles
cd roles

ansible-galaxy role init rol_base_datos
ansible-galaxy role init rol_servidor_web

cd ..

```

---

## 4. Paso 3: Configurar el Rol de Base de Datos (Para Rocky)

Este rol instalará MariaDB. En lugar de escribir el nombre del paquete directamente en la tarea, lo definiremos como una variable. Esto hace que el rol sea fácil de modificar en el futuro.

### A. Define las variables en `roles/rol_base_datos/vars/main.yml`

```yaml
---
# Variables locales para el rol de base de datos
db_paquete: "mariadb-server"
db_servicio: "mariadb"

```

### B. Escribe las tareas en `roles/rol_base_datos/tasks/main.yml`

```yaml
---
- name: Instalar el motor de base de datos
  ansible.builtin.dnf:
    name: "{{ db_paquete }}"
    state: present

- name: Iniciar y habilitar el servicio de base de datos
  ansible.builtin.service:
    name: "{{ db_servicio }}"
    state: started
    enabled: true

```

---

## 5. Paso 4: Configurar el Rol del Servidor Web (Para Ubuntu)

Este rol instalará Nginx y utilizará variables para inyectar texto personalizado en una página web mediante una plantilla Jinja2.

### A. Define las variables en `roles/rol_servidor_web/vars/main.yml`

```yaml
---
# Variables locales para el rol web
web_paquete: "nginx"
web_servicio: "nginx"
pagina_titulo: "Bienvenidos a mi Servidor Automatizado"
pagina_mensaje: "Este sitio web fue desplegado de forma exitosa utilizando Ansible Roles y Variables simples."

```

### B. Escribe las tareas en `roles/rol_servidor_web/tasks/main.yml`

```yaml
---
- name: Instalar el servidor web
  ansible.builtin.apt:
    name: "{{ web_paquete }}"
    state: present
    update_cache: yes

- name: Iniciar y habilitar el servicio web
  ansible.builtin.service:
    name: "{{ web_servicio }}"
    state: started
    enabled: true

- name: Desplegar la pagina web personalizada
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html

```

### C. Crea la plantilla en `roles/rol_servidor_web/templates/index.html.j2`

*(Si la carpeta `templates` no existe dentro de tu rol, créala).*

```html
<!DOCTYPE html>
<html>
<head>
    <title>{{ pagina_titulo }}</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        h1 { color: #2c3e50; }
        p { color: #34495e; font-size: 18px; }
    </style>
</head>
<body>
    <h1>{{ pagina_titulo }}</h1>
    <p>{{ pagina_mensaje }}</p>
    <hr>
    <p><i>Atendido por el servidor: {{ ansible_facts['hostname'] }}</i></p>
</body>
</html>

```

---

## 6. Paso 5: El Playbook Maestro (`site.yml`)

Ahora, en la raíz de tu proyecto (fuera de la carpeta `roles`), crea tu playbook principal. Fíjate en lo fácil que es leerlo ahora que toda la complejidad está encapsulada en los roles.

```yaml
---
# Tareas para los servidores Rocky
- name: Configurar Servidores de Base de Datos
  hosts: dbservers
  become: true
  roles:
    - rol_base_datos

# Tareas para los servidores Ubuntu
- name: Configurar Servidores Web
  hosts: webservers
  become: true
  roles:
    - rol_servidor_web

```

---

## 7. Ejecución y Validación

**1. Ejecuta el Playbook Maestro:**

```bash
ansible-playbook site.yml

```

**2. Verifica el servidor de Base de Datos:**
Puedes lanzar un comando Ad-Hoc para asegurarte de que MariaDB está corriendo en tu nodo Rocky:

```bash
ansible dbservers -b -m command -a "systemctl status mariadb"

```

**3. Verifica el Servidor Web:**
Abre tu navegador y visita la IP de tu nodo Ubuntu (ej. `[http://192.168.1.10](http://192.168.1.10)`), o usa `curl` desde la terminal de tu nodo de control:

```bash
curl http://192.168.1.10
```

Verás el código HTML con el título y el mensaje que definiste en las variables de tu rol, junto con el nombre del servidor (hostname) inyectado automáticamente.
