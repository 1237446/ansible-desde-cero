# Laboratorio 03: Generación Dinámica con Plantillas Jinja2 (Ejercicios Individuales)

Este laboratorio tiene como objetivo principal comprender el módulo **`template`** de Ansible y el motor de plantillas **Jinja2**.

A diferencia del módulo `copy` (que copia un archivo estático tal cual es), el módulo `template` toma un archivo base (terminado en `.j2`), busca variables, condicionales lógicos o bucles dentro de él, los procesa en tu nodo de control, y envía el archivo final ya renderizado a tus servidores. Es la herramienta definitiva para crear archivos de configuración dinámicos.

---

## 1. Objetivos del Laboratorio

* Comprender la diferencia entre copiar un archivo estático y renderizar una plantilla.
* Sustituir variables básicas dentro de un archivo de texto.
* Utilizar Ansible Facts directamente dentro de un archivo `.j2`.
* Utilizar condicionales (`{% if %}`) dentro de un archivo para cambiar su contenido.
* Utilizar bucles (`{% for %}`) dentro de un archivo para generar listas de configuración.

> **¡IMPORTANTE ANTES DE EMPEZAR!**
> A diferencia de los laboratorios anteriores donde todo estaba en el Playbook, aquí **necesitas crear el archivo de la plantilla en tu máquina de control** antes de ejecutar el playbook. Ansible leerá este archivo local, lo procesará y lo enviará a `/tmp/` en tus nodos.

---

## 2. Ejercicio A: Sustitución de Variables Básicas

Este es el uso más común: inyectar variables definidas en tu Playbook directamente en un archivo de configuración.

### Paso 1: Crea la plantilla local (`basico.j2`)

Crea un archivo llamado `basico.j2` en el mismo directorio donde ejecutas tus comandos de Ansible:

```jinja2
# Archivo de configuración generado por Ansible
APP_NAME={{ nombre_aplicacion }}
APP_PORT={{ puerto_aplicacion }}
ADMIN_USER={{ usuario_admin }}

```

### Paso 2: Crea el Playbook (`test-template-basic.yml`)

```yaml
---
- hosts: all
  gather_facts: false
  vars:
    nombre_aplicacion: "MiAppWeb"
    puerto_aplicacion: 8080
    usuario_admin: "sysadmin"

  tasks:
    - name: Renderizar plantilla basico.j2 en los servidores
      ansible.builtin.template:
        src: basico.j2           # Archivo en tu máquina de control
        dest: /tmp/basico.conf   # Destino en los nodos remotos

```

### Prueba Práctica y Visual

Ejecuta `ansible-playbook test-template-basic.yml`. Luego, revisa el archivo generado en uno de tus nodos usando un comando Ad-Hoc:

```bash
ansible ubuntu-node1 -m command -a "cat /tmp/basico.conf"

```

#### Lo que verás:

Ansible reemplazó las llaves `{{ }}` con los valores de las variables. El archivo en el servidor remoto lucirá así:

```text
# Archivo de configuración generado por Ansible
APP_NAME=MiAppWeb
APP_PORT=8080
ADMIN_USER=sysadmin

```

---

## 3. Ejercicio B: Inyectar Ansible Facts en Plantillas

Jinja2 puede leer directamente los Facts del sistema sin necesidad de pasarlos a variables intermedias.

### Paso 1: Crea la plantilla local (`facts.j2`)

```jinja2
=========================================
REPORTE DE SERVIDOR
=========================================
Hostname real : {{ ansible_facts['hostname'] }}
Sistema OS    : {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
Memoria Total : {{ ansible_facts['memtotal_mb'] }} MB
=========================================

```

### Paso 2: Crea el Playbook (`test-template-facts.yml`)

```yaml
---
- hosts: all
  gather_facts: true # ¡Crucial para que Jinja2 pueda leer los facts!

  tasks:
    - name: Renderizar reporte del servidor con Facts
      ansible.builtin.template:
        src: facts.j2
        dest: /tmp/reporte_servidor.txt

```

### Prueba Práctica y Visual

Ejecuta el playbook y luego verifica el contenido en diferentes nodos:

```bash
ansible all -m command -a "cat /tmp/reporte_servidor.txt"

```

#### Lo que verás:

El **mismo archivo `.j2` original** generó contenido completamente diferente para cada máquina. En Ubuntu verás `Sistema OS: Ubuntu 22.04` y en Rocky verás `Sistema OS: Rocky 9.2`.

---

## 4. Ejercicio C: Condicionales dentro de la plantilla (`{% if %}`)

A veces quieres que un bloque de texto completo (como una advertencia o una configuración de base de datos) solo aparezca en ciertos entornos. Jinja2 usa la sintaxis `{% %}` para lógica.

### Paso 1: Crea la plantilla local (`entorno.j2`)

```jinja2
# Configuración del entorno
Entorno actual: {{ entorno }}

{% if entorno == "produccion" %}
# ¡ATENCION! ESTO ES PRODUCCION
DEBUG=False
DB_HOST=10.0.0.50
{% else %}
# Entorno de pruebas
DEBUG=True
DB_HOST=localhost
{% endif %}

```

### Paso 2: Crea el Playbook (`test-template-if.yml`)

```yaml
---
- hosts: all
  gather_facts: false
  vars:
    entorno: "produccion" # Prueba cambiar esto a "desarrollo" luego

  tasks:
    - name: Crear archivo de configuración basado en condicionales
      ansible.builtin.template:
        src: entorno.j2
        dest: /tmp/config_entorno.txt

```

#### Lo que verás al verificar `/tmp/config_entorno.txt`:

Si ejecutas el playbook tal cual, el archivo mostrará el bloque de producción (`DEBUG=False`). Si cambias la variable `entorno` a `"desarrollo"` en tu playbook y vuelves a ejecutarlo, Jinja2 borrará el bloque de producción y escribirá el bloque de pruebas. ¡El archivo se adapta lógicamente!

---

## 5. Ejercicio D: Bucles dentro de la plantilla (`{% for %}`)

Este es el poder definitivo de Jinja2. Te permite tomar una lista de tu Playbook y generar múltiples líneas de configuración dinámicamente. Es ideal para crear listas de IPs permitidas en firewalls, configuraciones de Nginx o listas de nodos de clúster.

### Paso 1: Crea la plantilla local (`bucle.j2`)

```jinja2
# Reglas de Firewall generadas automáticamente
# Se permiten las siguientes IPs:

{% for ip in lista_ips_permitidas %}
allow {{ ip }};
{% endfor %}

deny all;

```

### Paso 2: Crea el Playbook (`test-template-for.yml`)

```yaml
---
- hosts: all
  gather_facts: false
  vars:
    lista_ips_permitidas:
      - "192.168.1.100"
      - "192.168.1.101"
      - "10.0.0.5"

  tasks:
    - name: Generar reglas de firewall desde una lista
      ansible.builtin.template:
        src: bucle.j2
        dest: /tmp/reglas_firewall.conf

```

### Prueba Práctica y Visual

Ejecuta el playbook y revisa el resultado en un nodo:

```bash
ansible ubuntu-node1 -m command -a "cat /tmp/reglas_firewall.conf"

```

#### Lo que verás:

Jinja2 recorrió la variable `lista_ips_permitidas` e imprimió la línea `allow ...;` repetidas veces, una por cada elemento. El resultado final en el servidor remoto será:

```text
# Reglas de Firewall generadas automáticamente
# Se permiten las siguientes IPs:

allow 192.168.1.100;
allow 192.168.1.101;
allow 10.0.0.5;

deny all;

```
