# 🚀 SESIÓN 3 - Inventarios y Automatizacion Multiservidor 

* Inventarios: estaticos, dinamicos, hosts, grupos y variables por servidor.
* Automatización de varios servidores desde un único proyecto. 
* Instalación y configuración de MariaDB en un servidor separado. 
* Uso de handlers para reiniciar servicios solo cuando existan cambios reales.

---

## 📑 Índice
1. [Inventarios a Nivel de Infraestructura](#1-inventarios-a-nivel-de-infraestructura)
2. [Variables en Ansible](#2-variables-en-ansible)
3. [Automatización Multi-Servidor](#3-automatización-multi-servidor)
4. [Control de Ejecución: Forks, Serials y Strategies](#4-control-de-ejecución-forks-serials-y-strategies)
5. [Handlers y Cambios Reales](#5-handlers-y-cambios-reales)
6. [Troubleshooting y Errores Básicos](#6-troubleshooting-y-errores-básicos)

---

## 1. Inventarios a Nivel de Infraestructura

El inventario es la **fuente de verdad** que le indica a Ansible qué equipos gestiona, cómo se conecta a ellos y cómo se agrupan. 

> *Inventario = alcance + contexto*

### Inventario Estático vs. Dinámico
* **Inventario Estático:** Archivos de texto fijos (`inventory.ini` o `.yml`). Define qué servidores se gestionan de manera manual. Es ideal para laboratorios o entornos pequeños.
* **Inventario Dinámico:** En arquitecturas modernas (Cloud, AWS, Docker), las IPs y servidores cambian constantemente. Un inventario dinámico usa *Inventory Plugins* o scripts que consultan directamente a la API del proveedor en tiempo real para saber qué máquinas existen en ese preciso instante.

### Agrupación Avanzada (Grupos Padre)
Puedes crear grupos que contengan otros grupos usando `:children`.
```ini
[web]
web01 ansible_host=10.10.10.21

[db]
db01 ansible_host=10.10.10.31

[linux:children]
web
db
```
En este caso, `linux` es un grupo padre que incluye a todos los servidores web y de base de datos.

### Patrones para Seleccionar Hosts
Al ejecutar comandos ad-hoc o playbooks, puedes filtrar objetivos:
| Patrón | Descripción |
| :--- | :--- |
| `all` o `*` | Todos los hosts del inventario. |
| `'web'` | Todos los hosts de un grupo. |
| `'web01'` | Un host específico. |
| `'web':'db'` | Múltiples hosts o grupos (**OR** lógico). |
| `'web':&'db'` | Intersección (hosts que están en ambos grupos). |
| `'web':!'db'` | Exclusión (hosts en el grupo web pero NO en el db). |

### Inspeccionar y Validar el Inventario
Si un host no aparece en estos comandos, tu playbook no lo encontrará:
* **Ver estructura visual:** `ansible-inventory -i inventory.ini --graph`
* **Ver datos en JSON:** `ansible-inventory -i inventory.ini --list`

---

## 2. Variables en Ansible

Las variables permiten escribir playbooks genéricos y reutilizables, adaptando su comportamiento (ej. puertos, rutas, usuarios) según el entorno sin cambiar la lógica del código.

Se referencian usando dobles llaves: `{{ nombre_var }}`

### Tipos y Ubicaciones de Variables
Ansible busca variables en diferentes lugares. Para mantener el orden, se recomienda usar directorios especiales:

1. **Directamente en el Playbook:** Bajo la sección `vars:`.
2. **`group_vars/`:** Directorio que contiene archivos YAML (ej. `webservers.yml`) con variables compartidas para **todos** los hosts de ese grupo.
3. **`host_vars/`:** Directorio que contiene archivos YAML (ej. `ubuntu1.yml`) con variables **exclusivas** para un host específico.
4. **Línea de Comandos (`-e` o `--extra-vars`):** Variables pasadas manualmente al ejecutar.

### Precedencia de Variables (Quién gana)
La regla es: **Lo más específico y lo más tardío gana.**
El orden de prioridad (de menor a mayor) es:
`Role Defaults` ➔ `group_vars` ➔ `host_vars` ➔ `playbook vars` ➔ `extra vars (-e)`

> [\!NOTE]
> Las *extra vars* pasadas por línea de comandos tienen la **máxima prioridad absoluta** y se usan para sobrescribir (overrides) manuales rápidos.

---

## 3. Automatización Multi-Servidor

**Principio fundamental:** El inventario define el alcance, pero cada *play* aplica el estado correcto al grupo correcto. Un playbook multi-servidor no instala todo en todos los nodos, sino que separa las responsabilidades.

### Playbook con Varios Plays (`site.yaml`)
En lugar de tener un archivo por cada tipo de servidor, podemos combinarlos en un archivo central:

```yaml
---
# ==========================================
# PLAY 1: Servidores Web
# ==========================================
- name: Configurar servidores web
  hosts: web
  become: true
  tasks:
    - name: Instalar Nginx
      ansible.builtin.apt:
        name: nginx
        state: present

# ==========================================
# PLAY 2: Servidores de Base de Datos
# ==========================================
- name: Desplegar MariaDB
  hosts: db
  become: true
  tasks:
    - name: Instalar MariaDB y cliente Python
      ansible.builtin.apt:
        name: 
          - mariadb-server
          - python3-pymysql
        state: present
        update_cache: true
```

### Validar el despliegue de MariaDB
```bash
# Validar estado del servicio
ansible db -b -m ansible.builtin.command -a "systemctl is-active mariadb"

# Validar puerto en escucha (3306)
ansible db -b -m ansible.builtin.shell -a "ss -lntp | grep 3306"
```

---

## 4. Control de Ejecución: Forks, Serials y Strategies

### Forks (Paralelismo)
Es el número máximo de procesos hijos que Ansible lanza en paralelo. 
* El valor por defecto es **5 hosts a la vez**.
* Cuantos más forks, más rápida será la ejecución, pero consumirá más CPU/RAM en tu nodo de control.

### Serials (Lotes)
Divide la ejecución de un play por lotes o porcentajes. En lugar de actualizar 100 servidores de golpe (lo que tumbaría tu servicio si algo sale mal), puedes indicarle que actualice de a 10 servidores a la vez.

### Strategy: Free
Por defecto, Ansible es **Lineal**: Todos los hosts sincronizan el paso y nadie avanza a la Tarea 2 hasta que el último host termine la Tarea 1.
* **`strategy: free`**: Modifica este comportamiento. Permite que cada host avance de forma independiente sin esperar a los demás. Evita que un servidor lento bloquee a toda la infraestructura.

---

## 5. Handlers y Cambios Reales

### ¿Qué problema resuelve un Handler?
Si tenemos una tarea que modifica la configuración de una base de datos, no queremos reiniciar el servicio de base de datos *cada vez* que se ejecute el playbook, sino **únicamente cuando el archivo de configuración realmente haya cambiado**.

Una tarea **notifica** al handler solo cuando reporta estado `changed`.

### Estructura de un Handler (`notify`)
```yaml
tasks:
  - name: Permitir conexiones externas en MariaDB
    ansible.builtin.lineinfile:
      path: /etc/mysql/mariadb.conf.d/50-server.cnf
      regexp: '^bind-address'
      line: 'bind-address = 0.0.0.0'
    notify: Reiniciar MariaDB   # ← Llama al handler por su nombre exacto

handlers:
  - name: Reiniciar MariaDB     # ← Nombre del handler
    ansible.builtin.service:
      name: mariadb
      state: restarted
```

### Conceptos Avanzados de Handlers
* **`listen`**: Permite que varios manejadores "escuchen" un mismo evento. Una sola notificación dispara múltiples handlers.
* **`meta: flush_handlers`**: Por defecto, los handlers se ejecutan **al final** del play. Si necesitas forzar su ejecución en medio del playbook (ej. porque la siguiente tarea necesita que el servicio ya esté reiniciado), usas este comando.
* **`force_handlers: true`**: Es una directiva a nivel de playbook que asegura que los handlers notificados se ejecuten, **incluso si una tarea posterior falla** y detiene la ejecución general.

---

## 6. Troubleshooting y Errores Básicos

| Síntoma | Causa probable | Revisión / Solución |
| :--- | :--- | :--- |
| **No se seleccionan hosts** | Grupo mal escrito en el playbook o inventario. | Usar `ansible-inventory --graph` y `ansible <grupo> --list-hosts`. |
| **UNREACHABLE** | Problemas de red, IP, usuario o llave SSH. | Revisar variables de conexión (`ansible_host`, `ansible_user`). |
| **MariaDB instalándose en nodos web** | Segmentación (`hosts:`) incorrecta en el playbook. | Separar adecuadamente los plays por grupo en el `site.yaml`. |
| **Handler nunca corre** | La tarea no genera cambios (`ok`) o el nombre del `notify` no coincide. | Verificar ortografía exacta entre `notify` y el `name` del handler. |
| **Handler corre siempre** | La tarea noticadora no es idempotente (siempre reporta `changed`). | Asegurarse de usar módulos declarativos en lugar de `shell` o `command` puros. |

---
