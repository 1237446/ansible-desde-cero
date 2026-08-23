# 🚀 Ansible desde Cero: Automatiza Linux y Servidores

**Instructor:** Cristian Adrian Diaz Garcia  
**Fecha:** 20 de agosto de 2026  
**Evento:** Cursos PIT - 10ma Edición (OTI UNI - Transformación Digital)

---

## 📑 Índice
1. [Facts: La Información del Sistema](#1-facts-la-información-del-sistema)
2. [Condicionales con `when`](#2-condicionales-con-when)
3. [Repetición de Tareas con `loop`](#3-repetición-de-tareas-con-loop)
4. [Control de Ejecución con `tags`](#4-control-de-ejecución-con-tags)
5. [Templates Dinámicos con Jinja2](#5-templates-dinámicos-con-jinja2)
6. [Flujo Completo Inteligente](#6-flujo-completo-inteligente)

---

## 1. Facts: La Información del Sistema

### ¿Qué son los Facts?
Los **Facts** son variables que Ansible descubre automáticamente al conectarse a un host, *antes* de ejecutar cualquier tarea. Recopila información vital como el sistema operativo, dirección IP, RAM, CPUs disponibles y hostname.

### Explorando los Facts
Puedes inspeccionar los facts de un servidor directamente desde la terminal usando el módulo `setup`:
```bash
# Ver todos los facts de un host
ansible ubuntu-node -m setup

# Filtrar por un patrón específico
ansible ubuntu-node -m setup -a "filter=ansible_memory*"
ansible ubuntu-node -m setup -a "filter=ansible_*ipv4*"
```

**Variables más usadas:**
* `ansible_facts['os_family']` (Ej: Debian, RedHat)
* `ansible_facts['distribution']` (Ej: Ubuntu, Rocky)
* `ansible_facts['distribution_version']` (Ej: 22.04, 8.7)
* `ansible_facts['memtotal_mb']` (Ej: 8192)

**Deshabilitar Facts (Optimización):**
Si tu playbook no requiere esta información, puedes ahorrar 1-2 segundos por host añadiendo `gather_facts: false` a nivel del play.

### Crear Facts Personalizados (`set_fact`)
`set_fact` es un módulo que te permite crear o modificar variables dinámicamente en tiempo de ejecución. Estas variables persisten durante todo el play.
```yaml
- name: Calcular memoria disponible para la JVM (70% de la RAM total)
  set_fact:
    jvm_heap_mb: "{{ (ansible_facts['memtotal_mb'] * 0.7) | int }}"
```

---

## 2. Condicionales con `when`

La cláusula `when` permite ejecutar una tarea **solo si se cumple una condición**. Es ideal para hacer que un mismo playbook funcione en diferentes distribuciones de Linux combinándolo con los Facts.

### Ejemplos Comunes

**1. Condición Simple (Por Familia de SO):**
```yaml
- name: Instalar Nginx en Debian/Ubuntu
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"
```

**2. Verificar si existe un archivo/directorio:**
```yaml
- name: Configurar backup solo si existe el directorio
  command: /usr/local/bin/backup.sh
  when: backup_dir.stat.exists
```

**3. Múltiples condiciones (AND Lógico):**
```yaml
  when: 
    - ansible_facts['distribution'] == "Ubuntu"
    - ansible_facts['environment'] == "production"
```

**4. Condición OR lógico:**
```yaml
  when: ansible_facts['distribution'] == "Debian" or ansible_facts['distribution'] == "Ubuntu"
```

---

## 3. Repetición de Tareas con `loop`

### ¿Cuándo usar `loop`?
Se utiliza para ejecutar la misma acción sobre una lista de elementos (ej. instalar múltiples paquetes, crear varios usuarios) sin tener que repetir bloques de código.

```yaml
- name: Instalar paquetes básicos
  ansible.builtin.apt:
    name: "{{ item }}"
    state: present
  loop:
    - curl
    - git
    - vim
```

### Loops con Diccionarios
Puedes iterar sobre estructuras complejas de datos:
```yaml
- name: Crear múltiples usuarios
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    shell: /bin/bash
  loop:
    - { name: 'alice', groups: 'sudo,developers' }
    - { name: 'bob', groups: 'developers' }
```

### `loop_control` (Control Avanzado)
Es una directiva que se utiliza junto con `loop` para personalizar su comportamiento:
* `loop_var`: Cambia el nombre de la variable iteradora (por defecto es `item`). Muy útil en bucles anidados.
* `label`: Limpia la consola ocultando datos masivos o sensibles al imprimir el resultado.
* `pause`: Agrega segundos de espera entre iteraciones (útil para no saturar APIs).
* `index_var`: Crea un contador (0, 1, 2...) para saber en qué iteración estás.

---

## 4. Control de Ejecución con `tags`

Los tags son etiquetas que te permiten ejecutar solo ciertas partes específicas de un playbook completo, ahorrando tiempo.

```yaml
- name: Instalar paquetes base
  apt:
    name: "{{ item }}"
    state: present
  tags:
    - install
    - base
```

**Comandos Útiles:**
* Ejecutar solo las tareas con tag "install": `ansible-playbook site.yml --tags install`
* Ejecutar TODO excepto la configuración: `ansible-playbook site.yml --skip-tags config`
* Listar tags disponibles: `ansible-playbook site.yml --list-tags`
* *Nota:* Los tags especiales `always` y `never` forzan la ejecución incondicional o la omiten por completo respectivamente.

---

## 5. Templates Dinámicos con Jinja2

Los Templates son archivos de texto con marcadores que Ansible reemplaza con variables reales antes de enviarlos al servidor. Son procesados mediante el motor **Jinja2**. Típicamente usan la extensión `.j2`.

### Sintaxis Jinja2 Esencial
* **Variables:** `{{ nombre_var }}` (Inserta el valor).
* **Condicionales:** `{% if condicion %}` ... `{% endif %}`
* **Bucles:** `{% for x in lista %}` ... `{% endfor %}`
* **Comentarios:** `{# comentario interno, no se renderiza #}`

### Ejemplo: Template de Nginx (`nginx.conf.j2`)
```nginx
server {
    listen {{ puerto_http }};
    server_name {{ ansible_hostname }};
    root {{ directorio_web }};

    {% if entorno == 'produccion' %}
    access_log /var/log/nginx/access_prod.log;
    {% else %}
    access_log /var/log/nginx/access_dev.log;
    {% endif %}
}
```

### Aplicando el Template en la Tarea
```yaml
- name: Generar configuración dinámica de Nginx
  ansible.builtin.template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/sites-available/default
    owner: root
    mode: '0644'
  notify: Reiniciar Nginx
```

---

## 6. Flujo Completo Inteligente

Combinando todas estas piezas logramos automatización de alto nivel:
1. **Variables:** Definidas en `vars`, `group_vars/` o `host_vars/`.
2. **Facts:** Descubiertos automáticamente (OS, IP).
3. **`when` / `loop`:** Lógica condicional y repetición.
4. **Template `.j2`:** Configuraciones adaptadas al entorno.

> **Resultado:** Un playbook inteligente que adapta su comportamiento **automáticamente** según el servidor, el entorno de despliegue y los datos del sistema, sin requerir intervención manual.

---

*Presentación creada por Cristian Adrian Diaz Garcia. ¡Gracias por participar!*
