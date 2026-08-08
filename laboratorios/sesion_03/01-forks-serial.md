# Laboratorio 00: Forks y serials

Este laboratorio tiene como objetivo principal comprender el funcionamiento de la concurrencia y la ejecución por lotes en Ansible mediante el uso de las directivas serial y el parámetro de control forks.

---

## 1. Objetivos del Laboratorio

* Levantar contenedores de prueba que servirán como nodos de infraestructura simulada.
* Limitar la ejecución de los playbooks utilizando estrategias de lotes (serial) y control de paralelismo por tareas (forks). 


---

## 2. Pasos para montar el laboratorio de prueba:

### 1. Levanta tu infraestructura con Docker Compose:

```bash
docker compose up -d 
```

### 2. Crea un Playbook de prueba (`test-serial.yml`)

Este playbook simulará un retraso (`pause`) para que puedas observar claramente cómo se procesan los servidores en bloques.

```yaml
---
- hosts: webservers
  # Serial define cuántos servidores procesan TODO el playbook a la vez
  serial: 2 
  
  tasks:
    - name: Tarea simulada con pausa
      ansible.builtin.pause:
        seconds: 5
      
    - name: Mostrar mensaje en cada host
      ansible.builtin.debug:
        msg: "Servidor {{ inventory_hostname }} procesado con éxito."

```

### 3. Ejecuta y compara

* **Prueba con Serial:**
Ejecuta el playbook:
```bash
ansible-playbook -i inventory.py test-serial.yml
```


**Qué verás en pantalla:** Verás que Ansible primero ejecuta la pausa y el mensaje **únicamente en 2 contenedores** (ej. `web1` y `web2`). Una vez que ambos terminan, Ansible pasa al siguiente lote (`web3` y `web4`). Eso es el **serial**.
* **Prueba alterando los Forks (`-f`):**
Puedes jugar con el parámetro de forks desde la terminal o limitarlo:
```bash
ansible-playbook -i inventory.py test-serial.yml -f 1
```


Si pones `-f 1`, aunque tu `serial` sea de 2 servidores, Ansible se verá obligado a procesar de a **1 solo contenedor a la vez** dentro de ese lote, porque los *forks* mandan sobre el límite de procesos paralelos simultáneos.
