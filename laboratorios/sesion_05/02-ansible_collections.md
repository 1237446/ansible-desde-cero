# Laboratorio 08: Extendiendo el poder con Ansible Collections (Versión Ampliada)

Este laboratorio tiene como objetivo enseñarte qué son las **Ansible Collections** y cómo utilizarlas en profundidad. A medida que Ansible creció, mantener todos los módulos dentro del paquete principal se volvió insostenible. Las colecciones son el formato de distribución moderno que empaqueta módulos, roles y complementos para que puedas instalarlos solo cuando los necesites.

---

## 1. Objetivos del Laboratorio

* Instalar colecciones manualmente mediante la línea de comandos.
* Automatizar la instalación de múltiples colecciones utilizando un archivo `requirements.yml`.
* Entender y utilizar la nomenclatura **FQCN** (Fully Qualified Collection Name).
* Simplificar la escritura de playbooks declarando colecciones a nivel global.

---

## 2. Ejercicio A: Instalación Manual

Antes de usar un módulo que no viene por defecto en el núcleo de Ansible (`ansible-core`), debes descargarlo. Usaremos la colección `community.general`, la cual contiene cientos de módulos útiles mantenidos por la comunidad.

**Prueba Práctica:** Ejecuta el siguiente comando en tu terminal:

```bash
ansible-galaxy collection install community.general

```

El sistema descargará el paquete y lo instalará en tu directorio local (normalmente en `~/.ansible/collections/`).

---

## 3. Ejercicio B: Instalación Automatizada (`requirements.yml`)

En proyectos reales, no instalas colecciones una por una. Creas un archivo de requisitos para que cualquier miembro de tu equipo pueda preparar su entorno con un solo comando.

**Paso 1: Crea el archivo `requirements.yml**`

```yaml
---
collections:
  - name: community.general
    version: "9.0.0"
  - name: ansible.posix
    version: "1.5.0"

```

**Paso 2: Prueba Práctica**
Ejecuta el comando para instalar todo lo listado en el archivo:

```bash
ansible-galaxy collection install -r requirements.yml

```

---

## 4. Ejercicio C: Usando el FQCN en un Playbook

Para invocar un módulo de una colección, la mejor práctica es usar su **FQCN** (nombre completo estructurado: `namespace.coleccion.modulo`). En este ejemplo usaremos `community.general.archive` para comprimir un archivo.

**Crea el Playbook (`test-collection-fqcn.yml`)**

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Paso 1 - Crear un archivo de registro simulado
      ansible.builtin.copy:
        dest: /tmp/registro_sistema.log
        content: "Datos críticos del servidor."

    - name: Paso 2 - Comprimir el archivo usando la nueva colección
      community.general.archive:
        path: /tmp/registro_sistema.log
        dest: /tmp/registro_sistema.zip
        format: zip

```

**Ejecución:** `ansible-playbook test-collection-fqcn.yml`
*(Si verificas `/tmp/` en tus nodos, verás el archivo `.zip` creado exitosamente).*

---

## 5. Ejercicio D: Simplificando con la directiva `collections`

Si tu playbook va a utilizar muchos módulos de la misma colección, escribir el FQCN completo una y otra vez puede volver el código muy largo. Ansible te permite declarar las colecciones al inicio del playbook para omitir el prefijo en las tareas.

En este ejemplo, usaremos el módulo `timezone` (que pertenece a `community.general`) para cambiar la hora de los servidores.

**Crea el Playbook (`test-collection-keyword.yml`)**

```yaml
---
- hosts: all
  become: true # Cambiar la hora requiere permisos de root
  gather_facts: false

  # Declaramos las colecciones que usaremos en este Playbook
  collections:
    - community.general

  tasks:
    - name: Cambiar la zona horaria del servidor
      # Como ya declaramos la colección arriba, podemos escribir solo 'timezone'
      timezone:
        name: America/Lima
```

**Ejecución y Análisis:**
Ejecuta `ansible-playbook test-collection-keyword.yml`. Al definir `collections: - community.general` en la cabecera, Ansible buscará automáticamente el módulo `timezone` dentro de ese paquete si no lo encuentra en los módulos nativos. Esto hace que tu código sea más limpio, pero debes tener cuidado de no mezclar colecciones que tengan módulos con el mismo nombre.
