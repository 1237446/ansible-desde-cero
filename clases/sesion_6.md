# 🚀 Ansible desde Cero: Automatiza Linux y Servidores

**Instructor:** Cristian Adrian Diaz Garcia  
**Fecha:** 22 de agosto de 2026  
**Evento:** Cursos PIT - 10ma Edición (OTI UNI - Transformación Digital)

---

## 📑 Índice
1. [Cifrado de Secretos con Ansible Vault](#1-cifrado-de-secretos-con-ansible-vault)
2. [Hardening SSH y Cortafuegos UFW](#2-hardening-ssh-y-cortafuegos-ufw)
3. [Protección con Fail2Ban](#3-protección-con-fail2ban)
4. [Backups Automatizados con Cron](#4-backups-automatizados-con-cron)
5. [Arquitectura del Proyecto Final](#5-arquitectura-del-proyecto-final)
6. [Pipeline de Ejecución y Validación](#6-pipeline-de-ejecución-y-validación)

---

## 1. Cifrado de Secretos con Ansible Vault

Contraseñas, tokens y claves SSH privadas **nunca** deben almacenarse en texto plano en un repositorio. Ansible Vault cifra archivos o variables individuales utilizando el estándar **AES-256**. El contenido solo se descifra en memoria temporalmente durante la ejecución del playbook.

### Comandos Esenciales
* `ansible-vault create archivo.yml`: Crear un archivo cifrado desde cero.
* `ansible-vault encrypt archivo.yml`: Cifrar un archivo existente.
* `ansible-vault view archivo.yml`: Ver contenido de forma segura.
* `ansible-vault edit archivo.yml`: Editar el archivo en el editor de terminal.
* `ansible-vault decrypt archivo.yml`: Quitar el cifrado permanentemente (¡Evitar en producción!).

### El Patrón Profesional: Variables Separadas
Red Hat recomienda separar las variables en dos archivos. En `group_vars/all/`:
1. `vars.yml`: Archivo en texto plano. Define las referencias públicas.
   ```yaml
   db_user: "app_user"
   db_password: "{{ vault_db_password }}" # Apunta al secreto
   ```
2. `vault.yml`: Archivo **cifrado**. Almacena los valores reales prefijados.
   ```yaml
   vault_db_password: "P@ssw0rd_Secreta!"
   ```

### Variables Cifradas *Inline*
Útil cuando tienes un solo secreto en medio de un archivo grande:
`ansible-vault encrypt_string 'password' --name 'db_password'`
Esto genera un gran bloque `$ANSIBLE_VAULT;...` que puedes pegar directo en tus YAML.

### Buenas Prácticas de Vault
* **Vault IDs:** Usa `--vault-id dev@prompt` para manejar múltiples entornos con claves separadas.
* **Proteger `.vault_pass`:** Usa archivos estáticos para la clave con permisos `chmod 600`, y **siempre** añádelos a tu `.gitignore` para no filtrarlos por accidente a Git.
* **Ocultar Logs:** Usa `no_log: yes` en tareas sensibles (ej. módulos mysql) para que las claves no aparezcan en la consola.

---

## 2. Hardening SSH y Cortafuegos UFW

### Hardening SSH (Orden Seguro de Aplicación)
Cerrar el acceso SSH por contraseña mejora radicalmente la seguridad, pero debes tener cuidado de no dejarte fuera a ti mismo (*Lockout*).
1. Configurar usuario administrativo e instalar tu llave pública (`authorized_key`).
2. **Validar conexión en otra terminal.**
3. Desactivar `PermitRootLogin` y `PasswordAuthentication` vía Template.
4. Validar configuración con `/usr/sbin/sshd -t` antes de recargar.

### Rol de Seguridad: UFW
Asegúrate de permitir el acceso SSH antes de habilitar una política restrictiva general.
```yaml
- name: Permitir puertos autorizados
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
  loop: ['22', '80', '443']

- name: Activar UFW con politica deny
  community.general.ufw:
    state: enabled
    policy: deny
    direction: incoming
```

---

## 3. Protección con Fail2Ban

Fail2Ban analiza logs (como `/var/log/auth.log`) para detectar intentos repetidos de autenticación fallida. Tras varios intentos (ej. `maxretry=3`), aplica baneos temporales usando el cortafuegos para mitigar ataques de fuerza bruta. *Es un gran complemento, pero no reemplaza la seguridad criptográfica de las llaves SSH.*

```yaml
- name: Configurar jail SSH
  ansible.builtin.template:
    src: jail.local.j2
    dest: /etc/fail2ban/jail.local
  notify: Reiniciar fail2ban
```

---

## 4. Backups Automatizados con Cron

Automatizar la base de datos requiere copias de respaldo consistentes e independientes.

**Ejemplo de implementación:**
1. Crear directorio con permisos estrictos (`mode: '0700'`).
2. Proveer un script Bash a través de `template` inyectando contraseñas del Vault.
3. Usar el módulo `cron` de Ansible para programar la tarea:
   ```yaml
   - name: Programar backup diario
     ansible.builtin.cron:
       name: backup_mariadb
       minute: '0'
       hour: '2'
       job: /usr/local/sbin/backup_mariadb
   ```
4. Usar `cron` para limpieza inteligente (ej. retención de 7 días usando `find ... -mtime +7 -delete`).

---

## 5. Arquitectura del Proyecto Final

El objetivo final consolida todo lo aprendido en una infraestructura real y observable:

**Estructura del Repositorio:**
```text
ansible-final/
├── ansible.cfg
├── inventory.ini
├── requirements.yml
├── site.yml
├── group_vars/all/ (vars.yml y vault.yml cifrado)
└── roles/
    ├── common/       (usuarios, repositorios)
    ├── security/     (UFW, SSH Keys, Fail2Ban)
    ├── webserver/    (Nginx)
    ├── database/     (MariaDB)
    ├── backup/       (Scripts cron)
    └── node_exporter/(Monitoreo)
```

**Orquestación Estratégica (`site.yml`):**
Primero aplicamos acceso y seguridad a `hosts: linux`. Después derivamos lógica específica por grupo (`hosts: web` o `hosts: db`).

---

## 6. Pipeline de Ejecución y Validación

Un despliegue profesional no se hace "a ciegas". Sigue este pipeline de ejecución:

1. **Dependencias:** `ansible-galaxy install -r requirements.yml`
2. **Revisión Red:** `ansible linux -i inventory.ini -m ping`
3. **Validación Sintaxis:** `ansible-playbook -i inventory.ini site.yml --syntax-check`
4. **Modo Simulación (Dry-Run):** `ansible-playbook -i inventory.ini site.yml --check --diff --ask-vault-pass`
5. **Ejecución Real:** `ansible-playbook -i inventory.ini site.yml --ask-vault-pass | tee despliegue.log`

### Matriz de Validación
| Componente | Prueba | Resultado esperado |
| :--- | :--- | :--- |
| **SSH** | Nueva conexión con llave | Acceso exitoso; root y contraseñas deshabilitados. |
| **UFW** | `ufw status` | Solo puertos definidos (22, 80, etc.) abiertos. |
| **Nginx** | Petición HTTP | Código 200 y contenido visible. |
| **Fail2Ban** | `fail2ban-client status sshd` | Jail habilitada y operativa. |
| **Node Exporter**| `/metrics` en puerto 9100 | Métricas listas para Prometheus. |

### Comprobación de la Idempotencia
Si lanzas el mismo comando inmediatamente después de que terminó correctamente, el resultado (RECAP) debe ser estrictamente **`changed=0`**. Cualquier número mayor a cero significa que un módulo no es declarativo y requiere arreglos.

---

*Presentación creada por Cristian Adrian Diaz Garcia. ¡Gracias por participar y felicitaciones por completar el curso!*
