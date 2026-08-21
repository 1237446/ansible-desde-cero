---

# Laboratorio 09: Gestionando Roles y Dependencias con Ansible Galaxy

Este laboratorio tiene como objetivo principal profundizar en el uso de **Ansible Galaxy**, la herramienta de línea de comandos (y el repositorio oficial en línea) utilizada para compartir y descargar contenido de Ansible.

Aprenderemos a crear la estructura estándar de un Rol desde cero, a gestionar dependencias de forma profesional utilizando un archivo `requirements.yml`, y finalmente, a consumir ese rol externo dentro de un Playbook para aplicarlo a nuestros servidores.

---

## 1. Objetivos del Laboratorio

* Comprender el uso de Ansible Galaxy para inicializar la estructura de directorios de un rol local.
* Aprender a definir dependencias externas (roles de la comunidad) usando un archivo YAML.
* Descargar e instalar roles de forma automatizada mediante `requirements.yml`.
* Ejecutar un Playbook corto que abstraiga la complejidad delegando las tareas a un rol externo.

---

## 1. Ejercicio B: Instalación de dependencias con `requirements.yml`

En un entorno de trabajo real, tu proyecto dependerá de roles creados por otras personas (por ejemplo, para instalar Nginx o bases de datos). En lugar de instalar cada rol uno por uno manualmente, se utiliza un archivo de manifiesto.

### Paso 1: Crea el archivo de requisitos (`requirements.yml`)

Crea este archivo en tu directorio de trabajo. Aquí especificaremos que necesitamos descargar un rol muy popular de la comunidad para instalar Git.

```yaml
---
roles:
  # Nombre del rol en Ansible Galaxy
  - name: geerlingguy.git
    version: "2.1.0" # Es una buena práctica fijar la versión

```

### Paso 2: Prueba Práctica y Visual

Dile a Ansible Galaxy que lea ese archivo e instale todo lo que encuentre allí:

```bash
ansible-galaxy install -r requirements.yml

```

#### Lo que verás:

Ansible Galaxy se conectará a internet, buscará el rol específico, verificará la versión y lo descargará en tu ruta de roles por defecto (usualmente `~/.ansible/roles/`).

```bash
Starting galaxy role install process
- downloading role 'git', owned by geerlingguy
- extracting geerlingguy.git to /home/usuario/.ansible/roles/geerlingguy.git
- geerlingguy.git (2.1.0) was installed successfully

```

---

## 4. Ejercicio C: Consumir el Rol en tu Playbook

Ahora que descargamos el rol `geerlingguy.git`, vamos a utilizarlo. Una de las mayores ventajas de usar roles de la comunidad es que el autor original ya se encargó de lidiar con las diferencias entre sistemas operativos (Ubuntu con `apt` vs Rocky con `dnf`). Tú solo tienes que llamarlo.

### Paso 1: Crea el Playbook (`test-role.yml`)

Crea un archivo nuevo y añade el siguiente código. Nota lo limpio que queda tu Playbook cuando delegas el trabajo a un Rol:

```yaml
---
- hosts: all
  become: true # ¡Crucial! Instalar software requiere permisos de administrador (root)
  gather_facts: true # El rol necesita saber qué SO tiene cada nodo para decidir cómo instalar

  roles:
    - geerlingguy.git
```

### Paso 2: Prueba Práctica y Visual

Ejecuta el playbook en tu terminal para aplicar los cambios en tus nodos (Ubuntu y Rocky):

```bash
ansible-playbook test-role.yml
```

#### Lo que verás:

Al ejecutarlo, Ansible automáticamente "desempaqueta" el rol. La salida mostrará el nombre del rol antes de cada tarea:

```bash
PLAY [all] *************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [geerlingguy.git : Ensure git is installed (RedHat).] *************************************************************
skipping: [ubuntu-node1]
changed: [rocky-node1]

TASK [geerlingguy.git : Ensure git is installed (Debian).] *************************************************************
changed: [ubuntu-node1]
skipping: [rocky-node1]

PLAY RECAP *************************************************************************************************************
rocky-node1                : ok=2    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
ubuntu-node1               : ok=2    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

#### Análisis del comportamiento:

1. **Abstracción:** Tu playbook solo tiene 5 líneas de código, pero logró instalar Git en arquitecturas completamente distintas.
2. **Condicionales internos:** El autor del rol incluyó condicionales en sus tareas. La tarea exclusiva para RedHat se ejecutó en tu nodo Rocky, pero fue omitida (`skipping`) en tu nodo Ubuntu, y viceversa.
3. **Reusabilidad:** Este mismo rol puede ser invocado en docenas de playbooks distintos, manteniendo un único estándar de instalación.

---
