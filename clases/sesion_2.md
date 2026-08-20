# 🚀 SESIÓN 2 - Primer playbook y despliegue de Nginx

* Qué es un playbook y cómo se estructura en YAML.
* Instalación y configuración automatizada de Nginx.
* Idempotencia: cómo Ansible evita repetir cambios innecesarios. 
* Ejecución, validación y corrección de errores básicos en playbooks.

---

## 📑 Índice
1. [Introducción a YAML](#1-introducción-a-yaml)
2. [Playbooks](#2-playbooks)
3. [Despliegue de Nginx (Práctica)](#3-despliegue-de-nginx-práctica)
4. [Ejecución y Validación](#4-ejecución-y-validación)
5. [Idempotencia](#5-idempotencia)
6. [Troubleshooting y Errores Clásicos](#6-troubleshooting-y-errores-clásicos)

---

## 1. Introducción a YAML

Para escribir Playbooks en Ansible, primero debemos entender YAML.

### Formatos de Datos: XML vs JSON vs YAML
* **XML:** Muy formal, basado en etiquetas (tags). Es muy verboso y difícil de leer de forma rápida.
  ```xml
  <usuario>
    <nombre>Ana</nombre>
    <edad>25</edad>
    <cursos>
      <curso>Matemáticas</curso>
      <curso>Física</curso>
    </cursos>
  </usuario>
  ```
  
* **JSON:** Ligero, común en APIs y aplicaciones web. Usa llaves `{}`, corchetes `[]` y comillas con frecuencia, lo que lo hace un poco denso visualmente.
  ```json
  {
    "nombre": "Ana",
    "edad": 25,
    "cursos": ["Matemáticas", "Física"]
  }
  ```

* **YAML:** (YAML Ain't Markup Language) Creado para ser **legible para humanos**. Usado fuertemente en automatización. Prescinde de las llaves y usa indentación (espacios), listas y pares `clave: valor`.
  ```json
  nombre: Ana
  edad: 25
  cursos:
    - Matemáticas
    - Física
  ```
  
### Reglas Básicas de YAML
1. **Comentarios:** Empiezan con el símbolo `#`.
2. **Indentación:** La estructura y jerarquía dependen estrictamente de la indentación.
3. **Espacios:** Se recomiendan **2 espacios** por nivel de indentación. **NO usar tabulaciones (tabs)**.
4. **Listas (Secuencias):** Usan un guion medio `-` seguido de un espacio.
5. **Diccionarios (Mapas):** Suelen escribirse como pares `clave: valor`.

**Ejemplo de Tipos de Datos (Escalares, Mapas y Secuencias):**
```yaml
usuario:
  nombre: ansible
  sudo: true
  grupos:
    - admins
    - devops
contacto: {ciudad: Lima, pais: Peru}
```

> [\!TIP]
> **Mini Actividad:** Crea tu propia autobiografía en YAML para practicar la estructura.
> ```yaml
> # Autobiografia en YAML
> nombre: "Tu nombre"
> contacto: {correo: "tu@correo.com", ciudad: "Lima"}
> habilidades:
>   - Linux
>   - Git
>   - Ansible
> metas:
>   corto_plazo: "Practicar automatizacion"
>   largo_plazo: "Administrar servidores"
> ```

---

## 2. Playbooks

### De Comandos Ad-Hoc a Playbooks
* **Comandos Ad-hoc:** Ideales para pruebas y tareas rápidas. Se ejecutan una vez desde la terminal.
* **Playbooks:** Guardan la automatización en archivos YAML. Permiten **repetir, revisar y versionar** procedimientos (Infraestructura como Código).

### ¿Qué es un Playbook?
Un playbook es un archivo YAML que indica **qué hosts** serán gestionados y **qué tareas** ejecutará Ansible de forma secuencial para llevarlos a un estado deseado.

**Estructura Común:**
```yaml
---
- name: Preparar servidor web         # Etiqueta descriptiva del "play"
  hosts: web                          # Grupo del inventario objetivo
  become: true                        # Ejecutar con privilegios elevados (sudo)
  tasks:                              # Lista de tareas secuenciales
    - name: Instalar nginx            # Nombre de la tarea
      ansible.builtin.apt:            # Módulo a utilizar
        name: nginx                   # Parámetro del módulo
        state: present                # Estado deseado
```

### Anatomía de una Tarea (Task)
Una tarea es la unidad básica de ejecución. Invoca un módulo específico y le pasa parámetros.
* `name`: Describe qué hace la tarea.
* `ansible.builtin.<modulo>`: El módulo usado (ej. `apt`, `service`, `copy`).
* Parámetros (`name`, `state`, etc.): Indican cómo debe actuar el módulo y declaran el estado final deseado.

---

## 3. Despliegue de Nginx (Práctica)

**Meta:** Dejar un servidor web funcionando con una página personalizada usando un solo comando de Ansible.

El flujo de despliegue consta de 4 pasos: **Instalar ➔ Habilitar ➔ Publicar ➔ Validar**.

### El Playbook Completo (`nginx.yml`)
```yaml
---
- name: Desplegar Nginx
  hosts: web
  become: true
  tasks:
    # 1. Instalar
    - name: Instalar Nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    # 2. Habilitar
    - name: Asegurar que Nginx esté activo
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

    # 3. Publicar
    - name: Publicar página principal
      ansible.builtin.copy:
        dest: /var/www/html/index.html
        content: |
          <h1>Servidor gestionado con Ansible</h1>
          <p>Despliegue automatizado de Nginx.</p>
        owner: www-data
        group: www-data
        mode: '0644'
```

---

## 4. Ejecución y Validación

### Aplicar el Playbook
El comando para enviar este playbook desde el Nodo de Control hacia los Servidores (Hosts) es:
```bash
ansible-playbook -i inventory.ini nginx.yml
```

### Validar el Despliegue desde el Nodo de Control
Podemos usar comandos ad-hoc para comprobar si funcionó:
```bash
# Confirma el estado del servicio en el host
ansible web -i inventory.ini -m command -a "systemctl status nginx"

# Prueba una respuesta HTTP desde el servidor
ansible web -i inventory.ini -m uri -a "url=http://localhost"
```

### Cómo Leer el Resultado de Ansible
Al finalizar, Ansible muestra un reporte (PLAY RECAP). Los estados significan:
* `ok`: Ya estaba correcto. **No hubo cambio**.
* `changed`: Ansible modificó algo. **Cambio aplicado**.
* `failed`: La tarea falló. **Revisar error**.
* `skipped`: No se ejecutó. **Condición no cumplida**.
* `unreachable`: No conectó al host. **Revisar SSH/inventario**.

---

## 5. Idempotencia

La idempotencia es el concepto más importante en Ansible: **Ejecutar el mismo playbook varias veces debe producir el mismo estado final, sin repetir cambios innecesarios.**

* Si Nginx ya está instalado, Ansible no lo reinstala.
* Si el servicio ya está activo, no lo reinicia sin motivo.
* Si el archivo HTML no cambió, no vuelve a copiarlo.

**Flujo Visual de la Idempotencia:**
1. Inicia la tarea.
2. Ansible pregunta: *¿El sistema ya está en el estado deseado?*
   * **SÍ ➔** No hacer nada (Estado: `OK`).
   * **NO ➔** Aplicar cambios (Estado: `Changed`).
3. Estado Final Alcanzado.

> [\!TIP]
> **Regla de oro:** La segunda ejecución de un buen playbook debería mostrar `changed=0`.

---

## 6. Troubleshooting y Errores Clásicos

Cuando las cosas fallan, Ansible ofrece herramientas para depurar.

### Visibilidad Detallada (Niveles de Verbosity)
Puedes agregar la bandera `-v` para obtener más información de un error:
* `-v` (Verbose): Muestra el resultado de cada tarea.
* `-vv` (Más verbose): Incluye detalles de conexión.
* `-vvv` (Muy verbose): Incluye comandos SSH completos.
* `-vvvv` (Máximo verbose): Incluye debug profundo de la conexión SSH.

### Modos de Validación Segura
* **Validación Estructural (Sintaxis):** Revisa que el archivo cumpla con YAML sin conectarse a los servidores.
  `ansible-playbook playbook.yml --syntax-check`
* **Modo Dry-Run (Simulación):** Simula la ejecución para ver qué pasaría sin hacer cambios reales.
  `ansible-playbook playbook.yml --check`
* **Ver Diferencias:** Muestra exactamente qué texto o configuraciones cambiarán.
  `ansible-playbook playbook.yml --diff`

### Errores Básicos y Cómo Corregirlos

| Error común | Causa probable | Qué revisar / Solución |
| :--- | :--- | :--- |
| **UNREACHABLE** | Problemas de conexión SSH o inventario. | Revisa IP, usuario (`ansible_user`), llave SSH y que el puerto 22 esté abierto. |
| **Permission denied / Missing sudo** | Falta elevación de privilegios. | Asegúrate de incluir `become: true` y usar `--ask-become-pass` si requiere contraseña sudo. |
| **Error de YAML (Syntax Error)** | Mala tabulación / Indentación incorrecta. | Revisa espacios, guiones y dos puntos. Puedes usar `yamllint playbook.yml` para validar. |
| **Paquete no encontrado** | Caché de APT desactualizada. | Agrega `update_cache: true` en la tarea del módulo apt. |
| **Servicio no inicia** | Configuración inválida (ej. error en nginx.conf). | Revisa los logs de Nginx en el servidor destino. |

---
