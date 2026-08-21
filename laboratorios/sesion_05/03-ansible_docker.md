

# Laboratorio 3: Gestión del Ciclo de Vida de Docker con Ansible

Este laboratorio asume que estás trabajando en un entorno moderno (como contenedores DinD con `systemd`) donde el motor de Docker ya está instalado y corriendo. Por lo tanto, nos enfocaremos estrictamente en la **gestión operativa**: solucionar problemas de compatibilidad del motor, utilizar Ansible para hablar con la API de Docker, crear contenedores, persistir datos con volúmenes y orquestar stacks completos con Docker Compose.

---

## 1. Objetivos del Laboratorio

* Aplicar un parche de compatibilidad (*workaround*) para entornos que no soportan el sistema de archivos `overlayfs`.
* Preparar los nodos instalando el SDK de Python (`python3-docker`), requisito indispensable para que Ansible se comunique con Docker.
* Utilizar un enfoque declarativo para levantar contenedores aislados.
* Crear y adjuntar volúmenes persistentes para evitar la pérdida de datos.
* Desplegar y orquestar múltiples servicios utilizando `docker_compose_v2`.
* Limpiar el entorno destruyendo los recursos de forma automatizada.

> [\!NOTE]
> Asegúrate de tener instalada la colección en tu máquina de control ejecutando `ansible-galaxy collection install community.docker` antes de comenzar.

---



## 2. Preparación del Entorno (Nodos con Docker-in-Docker / DinD)

Dado que tus nodos de Ansible se ejecutarán como contenedores y a su vez alojarán otros contenedores (Nginx Proxy Manager y MariaDB), necesitamos preparar una imagen personalizada y configurar correctamente los privilegios.

### Paso A: Crear el Dockerfile para los nodos (`Dockerfile.ubuntu-dind`)

Crea este archivo en la raíz de tu entorno (donde tienes tu `docker-compose.yml`). Esta imagen instala el servicio de Docker dentro de la imagen base de Ansible:

```dockerfile
FROM geerlingguy/docker-ubuntu2404-ansible:latest

# Instalar OpenSSH Server, Sudo, Docker y utilidades
RUN apt-get update && \
    apt-get install -y openssh-server sudo docker.io containerd iptables && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Crear usuario 'ansible', asignar contraseña y grupos (sudo y docker)
RUN useradd -m -s /bin/bash -u 1001 ansible && \
    echo 'ansible:password' | chpasswd && \
    usermod -aG sudo,docker ansible

# Configurar sudoers sin contraseña para ansible (opcional pero recomendado para automatización)
RUN echo 'ansible ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Preparar directorio .ssh e inyectar la clave pública con permisos estrictos
RUN mkdir -p /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh

COPY --chown=ansible:ansible id_rsa.pub /home/ansible/.ssh/authorized_keys

RUN chmod 600 /home/ansible/.ssh/authorized_keys && \
    chown -R ansible:ansible /home/ansible/.ssh

# Configurar runtime de SSH y habilitar servicios en systemd
RUN mkdir -p /var/run/sshd && \
    systemctl enable ssh && \
    systemctl enable docker

EXPOSE 22

CMD ["/lib/systemd/systemd"]

```

### Paso B: Configurar el Docker Compose (En tu máquina host)

Asegúrate de que tu archivo `docker-compose.yml` construya usando el nuevo Dockerfile, declare el nodo con privilegios elevados (`privileged: true`) y mapee los `cgroups`:

```yaml
  ubuntu-node1:
    build:
      context: .
      dockerfile: Dockerfile.ubuntu-dind
    container_name: ubuntu-node1
    privileged: true
    cgroup: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - ubuntu-node1-docker:/var/lib/docker
    ports:
      - "8080:80"
      - "8081:81"
      - "8082:443"
    networks:
      - lab-net

volumes:
  ubuntu-node1-docker:

```

### Paso C: Ajustar el Storage Driver (Dentro del Nodo)

Una vez que levantes tu entorno con `docker compose up -d`, ingresa al nodo. Incluso con el modo privilegiado activo, el driver de almacenamiento `overlay2` anidado puede fallar. Aplica esta solución dentro del contenedor `ubuntu-node1`:

1. Crea o edita el archivo `/etc/docker/daemon.json` en tu nodo de prueba:
```json
{
  "storage-driver": "vfs"
}

```


2. Reinicia el servicio de Docker en el nodo para aplicar el cambio:
```bash
sudo systemctl restart docker

```



---






## 3. Ejercicio A: Troubleshooting de Storage Drivers (*Workaround*)

A veces, al interactuar con Docker, falla con el error `overlay ... invalid argument`. Esto es común en ciertos VPS (como OpenVZ o LXC), entornos anidados (DinD) o kernels antiguos que no soportan bien `overlayfs`. Este ejercicio aplica un *workaround* forzando el uso del driver `vfs` para garantizar que el resto del laboratorio funcione sin problemas.

### Crea el Playbook (`test-docker-fix.yml`)

```yaml
---
- name: Workaround para error de overlayfs (Invalid Argument)
  hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Parar el servicio de Docker antes de reconfigurar
      ansible.builtin.service:
        name: docker
        state: stopped

    - name: Configurar daemon de Docker con vfs y snapshotter desactivado
      ansible.builtin.copy:
        dest: /etc/docker/daemon.json
        mode: '0644'
        content: |
          {
            "storage-driver": "vfs",
            "features": {
              "containerd-snapshotter": false
            }
          }

    - name: Limpiar snapshotter overlayfs heredado si existe
      ansible.builtin.file:
        path: /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs
        state: absent
      failed_when: false

    - name: Arrancar Docker con la nueva configuración vfs
      ansible.builtin.service:
        name: docker
        state: started

    - name: Verificar hello-world tras aplicar el parche
      ansible.builtin.command: docker run --rm hello-world
      register: hello_after_fix
      changed_when: false

    - name: Mostrar resultado de validación
      ansible.builtin.debug:
        var: hello_after_fix.stdout_lines

```

> [\!TIP]
> El driver `vfs` funciona para salir del paso en laboratorios, pero penaliza el rendimiento y el consumo de disco. En producción real, lo recomendable es utilizar `overlay2` sobre un host totalmente compatible.

### Prueba Práctica

Ejecuta `ansible-playbook test-docker-fix.yml`. Si el test de `hello-world` devuelve el mensaje de bienvenida de Docker, tu entorno está listo.

---

## 4. Ejercicio B: Levantar un contenedor (Crear e Iniciar)

El módulo `docker_container` reemplaza la necesidad de escribir largos comandos imperativos (`docker run`). Solo debes declarar cómo quieres que sea el contenedor final. En este playbook incluimos la instalación del SDK de Python, vital para que Ansible pueda ejecutar las siguientes tareas.

### Crea el Playbook (`test-docker-run.yml`)

```yaml
---
- hosts: all
  become: true
  gather_facts: true

  tasks:
    - name: Paso 1 - Instalar SDK de Python para Docker (Ubuntu/Debian)
      ansible.builtin.apt:
        name: python3-docker
        state: present
        update_cache: yes

    - name: Paso 2 - Levantar un contenedor web Nginx
      community.docker.docker_container:
        name: servidor_web_aislado
        image: nginx:alpine
        state: started
        restart_policy: always
        published_ports:
          - "8080:80"

```

### Prueba Práctica

Ejecuta `ansible-playbook test-docker-run.yml`. Ansible descargará la imagen y levantará el contenedor mapeando el puerto 8080.

---

## 5. Ejercicio C: Manejo de Volúmenes Persistentes

Para guardar datos reales, usaremos `docker_volume` para crear almacenamiento persistente y lo montaremos en un nuevo contenedor de Apache.

### Crea el Playbook (`test-docker-volume.yml`)

```yaml
---
- hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Paso 1 - Crear un volumen persistente
      community.docker.docker_volume:
        name: datos_web_persistentes
        state: present

    - name: Paso 2 - Levantar contenedor Apache usando el volumen
      community.docker.docker_container:
        name: servidor_con_volumen
        image: httpd:alpine
        state: started
        volumes:
          - "datos_web_persistentes:/usr/local/apache2/htdocs/"
        published_ports:
          - "8081:80"

```

### Prueba Práctica

Ejecuta `ansible-playbook test-docker-volume.yml`. Conéctate por SSH a tu nodo y verifica con `docker volume ls` que el almacenamiento fue creado correctamente.

---

## 6. Ejercicio D: Orquestación con Docker Compose

Para proyectos de múltiples componentes, lo ideal es transferir un archivo `docker-compose.yml`. Ansible copiará la configuración al nodo y usará el plugin interno de Compose para levantarlo.

### Instalacion del plugin Docker Compose
```
ansible all -i -m apt -a "name=docker-compose-v2 state=present update_cache=yes" -b
```

### Crea el Playbook (`test-docker-compose.yml`)

```yaml
---
- hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Paso 1 - Crear directorio para el proyecto Compose
      ansible.builtin.file:
        path: /opt/mi_stack_redis
        state: directory

    - name: Paso 2 - Escribir el archivo docker-compose.yml
      ansible.builtin.copy:
        dest: /opt/mi_stack_redis/docker-compose.yml
        content: |
          services:
            redis_cache:
              image: redis:alpine
              ports:
                - "6379:6379"

    - name: Paso 3 - Levantar el stack completo con Compose
      community.docker.docker_compose_v2:
        project_src: /opt/mi_stack_redis
        state: present

```

### Prueba Práctica

Ejecuta `ansible-playbook test-docker-compose.yml`. Esto es exactamente igual a entrar al servidor, navegar a la carpeta y ejecutar `docker compose up -d`.

---

## 7. Ejercicio E: Parar, Borrar y Limpiar (Destrucción)

En Ansible, no tienes que usar comandos explícitos de borrado. Simplemente cambias tu declaración de estado a `absent` y Ansible se encarga de detener los procesos y limpiar la infraestructura.

### Crea el Playbook (`test-docker-clean.yml`)

```yaml
---
- hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Paso 1 - Destruir contenedores individuales
      community.docker.docker_container:
        name: "{{ item }}"
        state: absent # Obliga a detener y borrar
      loop:
        - servidor_web_aislado
        - servidor_con_volumen

    - name: Paso 2 - Borrar el volumen persistente
      community.docker.docker_volume:
        name: datos_web_persistentes
        state: absent

    - name: Paso 3 - Destruir el stack de Compose
      community.docker.docker_compose_v2:
        project_src: /opt/mi_stack_redis
        state: absent

```

### Prueba Práctica

Ejecuta `ansible-playbook test-docker-clean.yml`. Verás en tu consola cómo Ansible destruye sistemáticamente uno por uno los recursos creados en los ejercicios B, C y D, dejando tu motor de Docker completamente limpio.
**Ejecución:** Ejecuta `ansible-playbook test-docker-clean.yml`. Ansible enviará las señales de parada (`SIGTERM`), destruirá los contenedores especificados y dejará tu entorno limpio.
