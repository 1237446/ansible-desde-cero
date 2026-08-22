# Laboratorio 00: Protegiendo Secretos con Ansible Vault

Cuando automatizamos infraestructura, inevitablemente tenemos que manejar datos sensibles: contraseñas de bases de datos, tokens de APIs, claves SSH o certificados. **Nunca debes guardar estos datos en texto plano**, especialmente si vas a subir tu código a un repositorio como GitHub o GitLab.

**Ansible Vault** es la herramienta nativa que te permite cifrar (encriptar) archivos o variables específicas utilizando el algoritmo AES256, garantizando que tus secretos estén seguros.

---

## 1. Objetivos del Laboratorio

* Crear archivos cifrados desde cero.
* Cifrar archivos de texto plano ya existentes.
* Visualizar y editar archivos protegidos sin descifrarlos permanentemente.
* Ejecutar un Playbook que consuma variables cifradas.
* Automatizar la inyección de la contraseña de Vault para entornos de Integración Continua (CI/CD).

---

## 2. Ejercicio A: Crear un archivo cifrado desde cero

La forma más directa de manejar secretos es crear un archivo que nazca ya cifrado.

1. En tu terminal, ejecuta el comando de creación:
```bash
ansible-vault create credenciales.yml

```


2. El sistema te pedirá que ingreses una nueva contraseña para la bóveda (Vault password) y que la confirmes. **(Usa algo fácil para este laboratorio, como `ansible123`).**
3. Inmediatamente se abrirá tu editor de texto por defecto (usualmente `vi` o `nano`). Escribe el siguiente contenido:
```yaml
---
db_usuario: "admin_db"
db_password: "SuperPasswordSeguro99!"
api_token: "xyz-123-token-secreto"

```


4. Guarda y cierra el archivo.
5. **Prueba de seguridad:** Intenta leer el archivo directamente con el comando `cat credenciales.yml`. Verás que el contenido es ilegible y comienza con una cabecera de cifrado:
```text
$ANSIBLE_VAULT;1.1;AES256
66353963383036666162353163353434653531383733353066373738363765363435343431613133
...

```



---

## 3. Ejercicio B: Manipulando archivos cifrados

Una vez que un archivo está cifrado, usar comandos tradicionales como `cat` o `nano` ya no sirve. Ansible proporciona comandos específicos para interactuar con ellos.

* **Para ver el contenido (solo lectura):**
```bash
ansible-vault view credenciales.yml

```


*(Te pedirá la contraseña y te mostrará el texto en pantalla).*
* **Para editar el contenido:**
```bash
ansible-vault edit credenciales.yml

```


*(Te pedirá la contraseña, lo descifrará temporalmente en memoria, abrirá tu editor y lo volverá a cifrar al guardar).*
* **Para cifrar un archivo existente:**
Si ya tenías un archivo llamado `variables.yml` en texto plano, puedes cifrarlo con:
```bash
ansible-vault encrypt variables.yml

```



---

## 4. Ejercicio C: Usar secretos en un Playbook

Ahora vamos a consumir las variables de nuestro archivo cifrado dentro de un Playbook.

### 1. Crea el archivo `site-seguro.yml`

Fíjate en la directiva `vars_files`, ahí es donde le decimos a Ansible que cargue nuestro archivo de secretos.

```yaml
---
- name: Despliegue con Boveda Segura
  hosts: localhost # Lo ejecutamos localmente para probar rápido
  gather_facts: false

  # Importamos el archivo cifrado
  vars_files:
    - credenciales.yml

  tasks:
    - name: Simular la conexion a la base de datos
      ansible.builtin.debug:
        msg: "Conectando a la DB con el usuario '{{ db_usuario }}' y la clave '{{ db_password }}'"

```

### 2. Intento de ejecución fallido

Ejecuta el playbook de forma normal:

```bash
ansible-playbook site-seguro.yml

```

**Resultado:** Ansible arrojará un error `ERROR! Attempting to decrypt but no vault secrets found`. Al ver un archivo cifrado, no sabe cómo abrirlo porque no le diste la llave.

### 3. Ejecución exitosa interactiva

Añade el parámetro `--ask-vault-pass` para que Ansible te pregunte la contraseña de la bóveda antes de arrancar.

```bash
ansible-playbook site-seguro.yml --ask-vault-pass

```

*(Ingresa tu contraseña `ansible123` y verás cómo el Playbook se ejecuta e imprime tus variables secretas).*

---

## 5. Ejercicio D: Automatización (El archivo de contraseña)

Escribir `--ask-vault-pass` a mano está bien para tu laptop, pero si ejecutas Ansible desde un servidor automático (como Jenkins o GitLab CI), no habrá un humano para tipear la contraseña. Para esto, usamos un archivo de llave.

1. **Crea un archivo de texto oculto** llamado `.vault_pass.txt` y escribe tu contraseña dentro de él:
```bash
echo "ansible123" > .vault_pass.txt

```


> **⚠️ REGLA DE ORO:** Este archivo **NUNCA** debe subirse a Git. Si usas repositorios, debes agregarlo inmediatamente a tu archivo `.gitignore`.


2. **Ejecuta el playbook leyendo el archivo:**
```bash
ansible-playbook site-seguro.yml --vault-password-file .vault_pass.txt

```

## 6. Ejercicio E: Múltiples entornos con Vault IDs (`--vault-id`)

En este escenario, simularemos que tenemos dos entornos separados. Crearemos dos contraseñas distintas, cifraremos un archivo diferente para cada entorno y ejecutaremos un Playbook que elija la llave correcta dinámicamente.

### 1. Crear los archivos de contraseñas (Llaves)

Crea dos archivos de texto ocultos, uno para desarrollo y otro para producción, cada uno con una contraseña diferente:

```bash
echo "clave_desarrollo_123" > .vault_dev.txt
echo "clave_produccion_999" > .vault_prod.txt

```

### 2. Crear los archivos de variables en texto plano

Primero, crearemos los archivos con las variables normales (sin cifrar aún):

```bash
echo "db_entorno: Base de Datos de DESARROLLO" > cred_dev.yml
echo "db_entorno: Base de Datos de PRODUCCION" > cred_prod.yml

```

### 3. Cifrar cada archivo con su respectivo Vault ID

Ahora le diremos a Ansible que cifre cada archivo usando su llave correspondiente. La sintaxis del Vault ID es `--vault-id etiqueta@ruta_del_archivo`.

```bash
# Cifrar el archivo de desarrollo con su etiqueta 'dev'
ansible-vault encrypt --vault-id dev@.vault_dev.txt cred_dev.yml

# Cifrar el archivo de producción con su etiqueta 'prod'
ansible-vault encrypt --vault-id prod@.vault_prod.txt cred_prod.yml

```

### 4. Crear el Playbook Multi-Entorno (`site-multi.yml`)

Este Playbook utilizará una variable externa (`{{ entorno }}`) para decidir qué archivo cargar.

```yaml
---
- name: Despliegue con Vault IDs
  hosts: localhost
  gather_facts: false

  # Carga el archivo dinámicamente basado en la variable 'entorno'
  vars_files:
    - "cred_{{ entorno }}.yml"

  tasks:
    - name: Verificar la conexion
      ansible.builtin.debug:
        msg: "Exito! Conectado a la -> {{ db_entorno }}"

```

### 5. Pruebas de Ejecución

Ahora ejecutaremos el Playbook pasándole tanto la variable del entorno como el Vault ID correspondiente para que pueda descifrar el archivo.

**A. Desplegar en Desarrollo:**

```bash
ansible-playbook site-multi.yml -e "entorno=dev" --vault-id dev@.vault_dev.txt

```

*(Verás que el mensaje imprime "Base de Datos de DESARROLLO").*

**B. Desplegar en Producción:**

```bash
ansible-playbook site-multi.yml -e "entorno=prod" --vault-id prod@.vault_prod.txt

```

*(Verás que el mensaje imprime "Base de Datos de PRODUCCION").*

> **Dato Pro:** Si tienes un playbook que incluye archivos de *ambos* entornos al mismo tiempo, puedes pasarle múltiples Vault IDs en el mismo comando:
> `ansible-playbook site-multi.yml --vault-id dev@.vault_dev.txt --vault-id prod@.vault_prod.txt` y Ansible probará qué llave funciona para cada archivo automáticamente.
