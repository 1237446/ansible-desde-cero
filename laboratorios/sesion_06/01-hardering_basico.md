# Laboratorio 01: Hardening Básico de Servidores (Firewalls y Fail2ban)

En este laboratorio integraremos todo lo aprendido (Roles, Variables de Grupo, Condicionales y Plantillas Jinja2) para aplicar una capa de seguridad básica (**hardening**) a nuestra infraestructura.

Protegeremos nuestros servidores instalando y configurando un cortafuegos (UFW para Ubuntu y Firewalld para Rocky Linux), y desplegaremos **Fail2ban** para bloquear automáticamente las direcciones IP de atacantes que intenten adivinar nuestras contraseñas por fuerza bruta.

---

## 1. Objetivos del Laboratorio

* Utilizar **Group Vars** para definir configuraciones globales (como el puerto SSH).
* Crear un rol `firewall` que use condicionales (`when`) para aplicar UFW en Debian/Ubuntu y Firewalld en RedHat/Rocky.
* Crear un rol `fail2ban` que utilice plantillas Jinja2 dinámicas para adaptarse a las diferencias de los sistemas operativos.
* Orquestar la seguridad en un entorno heterogéneo desde un Playbook maestro.

> **Requisito previo:** Asegúrate de tener instaladas las colecciones necesarias para gestionar los firewalls ejecutando:
> `ansible-galaxy collection install community.general ansible.posix`

---

## 2. Paso 1: Configurar Variables Globales (`group_vars`)

En lugar de escribir el puerto SSH a mano en cada archivo, lo definiremos globalmente. Así, si mañana decides cambiar el puerto SSH por seguridad, solo lo cambias en un lugar.

Crea la carpeta `group_vars` en la raíz de tu proyecto y dentro crea el archivo `all.yml` (que aplica a todos los servidores):

```yaml
# group_vars/all.yml
---
# Puerto SSH permitido en el firewall y protegido por Fail2ban
puerto_ssh_global: "22"

```

---

## 3. Paso 2: Inicializar los Roles

Crea la estructura base para los dos roles que nos encargarán de la seguridad:

```bash
mkdir -p roles
cd roles
ansible-galaxy role init firewall
ansible-galaxy role init fail2ban
cd ..

```

---

## 4. Paso 3: Desarrollar el Rol de Firewall (Multi-OS)

Este rol debe ser inteligente. Detectará qué sistema operativo está ejecutando y llamará al archivo de tareas correspondiente.

### A. Archivo principal: `roles/firewall/tasks/main.yml`

```yaml
---
- name: Configurar UFW para familia Debian (Ubuntu)
  ansible.builtin.include_tasks: ufw.yml
  when: ansible_facts['os_family'] == 'Debian'

- name: Configurar Firewalld para familia RedHat (Rocky)
  ansible.builtin.include_tasks: firewalld.yml
  when: ansible_facts['os_family'] == 'RedHat'

```

### B. Tareas para Ubuntu: `roles/firewall/tasks/ufw.yml`

```yaml
---
- name: Instalar UFW
  ansible.builtin.apt:
    name: ufw
    state: present

- name: Permitir trafico SSH
  community.general.ufw:
    rule: allow
    port: "{{ puerto_ssh_global }}"
    proto: tcp

- name: Habilitar UFW y denegar trafico entrante por defecto
  community.general.ufw:
    state: enabled
    default: deny

```

### C. Tareas para Rocky: `roles/firewall/tasks/firewalld.yml`

```yaml
---
- name: Instalar Firewalld
  ansible.builtin.dnf:
    name: firewalld
    state: present

- name: Asegurar que el servicio Firewalld este corriendo
  ansible.builtin.service:
    name: firewalld
    state: started
    enabled: true

- name: Permitir trafico SSH
  ansible.posix.firewalld:
    port: "{{ puerto_ssh_global }}/tcp"
    permanent: true
    state: enabled
    immediate: true

```

---

## 5. Paso 4: Desarrollar el Rol de Fail2ban

Fail2ban lee los registros del sistema y bloquea las IPs sospechosas usando el firewall. El reto aquí es que Ubuntu guarda los registros de autenticación en `/var/log/auth.log`, mientras que Rocky lo hace en `/var/log/secure`. Resolveremos esto con Jinja2.

### A. Tareas de Fail2ban: `roles/fail2ban/tasks/main.yml`

```yaml
---
- name: Instalar Fail2ban (Ubuntu)
  ansible.builtin.apt:
    name: fail2ban
    state: present
  when: ansible_facts['os_family'] == 'Debian'

- name: Instalar EPEL y Fail2ban (Rocky)
  ansible.builtin.dnf:
    name: 
      - epel-release
      - fail2ban
    state: present
  when: ansible_facts['os_family'] == 'RedHat'

- name: Desplegar configuracion de Jail local
  ansible.builtin.template:
    src: jail.local.j2
    dest: /etc/fail2ban/jail.local
  notify: reiniciar fail2ban

- name: Iniciar y habilitar Fail2ban
  ansible.builtin.service:
    name: fail2ban
    state: started
    enabled: true

```

### B. Plantilla Dinámica: `roles/fail2ban/templates/jail.local.j2`

*Fíjate cómo usamos una condición `if/else` directamente dentro de la plantilla para asignar la ruta correcta del log.*

```ini
[DEFAULT]
# Bloquear a los atacantes por 1 hora (3600 segundos)
bantime  = 3600
# Tienen 3 intentos fallidos antes de ser bloqueados
maxretry = 3

[sshd]
enabled = true
port    = {{ puerto_ssh_global }}
filter  = sshd
# Logica condicional para la ruta del archivo de logs
logpath = {% if ansible_facts['os_family'] == 'RedHat' %}/var/log/secure{% else %}/var/log/auth.log{% endif %}
backend = auto

```

### C. Handler: `roles/fail2ban/handlers/main.yml`

```yaml
---
- name: reiniciar fail2ban
  ansible.builtin.service:
    name: fail2ban
    state: restarted

```

---

## 6. Paso 5: El Playbook Maestro (`site-hardening.yml`)

Tu orquestador principal ahora es extremadamente simple. Ambos roles deben aplicarse a todos los servidores, ya que la lógica interna (los `when`) se encarga de separar qué se ejecuta en dónde.

```yaml
---
- name: Hardening Basico de Servidores
  hosts: all
  become: true
  gather_facts: true # Vital para detectar el OS en los roles

  roles:
    - role: firewall
    - role: fail2ban

```

---

## 7. Ejecución y Validación

**1. Ejecuta el Playbook:**

```bash
ansible-playbook -i inventory.ini site-hardening.yml

```

**2. Verifica el Firewall:**

* En Ubuntu: `ansible ubuntu -i inventory.ini -b -m command -a "ufw status"`
* En Rocky: `ansible rocky -i inventory.ini -b -m command -a "firewall-cmd --list-all"`

**3. Verifica Fail2ban:**
Puedes comprobar el estado de la jaula SSH para ver cuántos intentos fallidos ha registrado o si ya ha bloqueado alguna IP (probablemente veas bloqueos rápidos si tus servidores están expuestos a internet):

```bash
ansible all -i inventory.ini -b -m command -a "fail2ban-client status sshd"

```
