# Cómo poner el enlace de los banners en la app

Esta guía es para el equipo que sube banners y marcas en el CMS.

---

## ¿Qué campo hay que llenar?

En el CMS, en el banner o marca de **App XL Store Inicio**, busca el campo:

**linkContenido**

Ahí escribes a dónde debe llevar cuando alguien toque la imagen en la app.

---

## Hay 3 opciones (elige solo una)

### Opción 1 — Llevar a UN producto

Escribe:

```
producto|ID_DEL_PRODUCTO
```

**Ejemplo:**
```
producto|12345
```

- Después del `|` va el **número o código del producto**.
- Pregunta a alguien de XL Store cuál es el ID correcto si no lo sabes.
- La persona verá la ficha de ese producto al tocar el banner.

---

### Opción 2 — Mostrar varios productos (búsqueda por texto)

Escribe:

```
buscar|LO_QUE_QUIERES_BUSCAR
```

**Ejemplos:**
```
buscar|laptop hp
buscar|monitor dell
```

---

### Opción 2b — Mostrar productos de una marca (por ID)

Escribe:

```
marca|ID_DE_LA_MARCA
```

**Ejemplo:**
```
marca|123
```

- Usa el **ID de marca** de XL Store (no el nombre).
- La app filtra por `id_marca` en el buscador (igual que con sesión iniciada).

También existen `categoria|ID` y `subcategoria|ID` con el mismo formato.

---

### Opción 3 — Abrir una página de internet

Escribe la dirección completa de la página:

```
https://www.exel.com.mx/tu-pagina
```

- Tiene que empezar con `https://` o `http://`.
- Se abre la página dentro de la app.

---

### Opción 4 — No hacer nada al tocar

Deja el campo **vacío**.

El banner se ve, pero **no pasa nada** si lo tocan.

---

## Reglas fáciles de recordar

1. Siempre usa el símbolo **|** (pipe) entre la palabra y el dato.  
   Ejemplo: `producto|12345` ✅  
   Mal: `producto 12345` ❌

2. Las palabras `producto` y `buscar` pueden ir en mayúsculas o minúsculas. Da igual.

3. Si escribes mal, el banner **no funcionará** al tocarlo.

---

## Ejemplos listos para copiar

| Quiero que pase esto… | Escribo esto en linkContenido |
|-----------------------|-------------------------------|
| Ver el producto 12345 | `producto\|12345` |
| Ver laptops HP | `buscar\|laptop hp` |
| Ver monitores Dell | `buscar\|monitor dell` |
| Abrir una promo en la web | `https://www.exel.com.mx/promo` |
| Solo mostrar imagen | *(dejar vacío)* |

---

## Antes de publicar, revisa esto

- [ ] ¿Usé `producto|`, `buscar|` o una dirección `https://`?
- [ ] ¿Puse el `|` en el medio?
- [ ] Si es producto, ¿el ID es el correcto?
- [ ] Si es búsqueda, ¿probé esas palabras en XL Store y salen productos?

---

## ¿Necesitas algo más?

Por ahora solo existen estas 3 acciones: **producto**, **buscar** y **página web**.

Si más adelante quieren otro tipo de enlace, hay que pedírselo al equipo de la app.
