---
tags: [research, api-profile, template]
created: 2026-05-25
extraído-de: agents/03_agent_research.md §5
---

# API Profile Template — Schema de salida de Research

#research #api-profile #template

[[index]] [[03_agent_research]]

Schema completo para documentar nuevas plataformas.
Extraído de `agents/03_agent_research.md §5` para reducir peso del agente.

---

## Uso

Para plataformas no precargadas en la vault (sin perfil existente en `knowledge-base/platforms/`),
generar este esquema completo.

**Regla crítica:** ningún campo puede quedar vacío.
Si no se encuentra el dato, el campo dice:
```
"no documentado — aplicar estrategia defensiva"
```
Eso le dice al Developer que debe asumir el peor caso.
Un campo vacío le dice nada, y asumirá algo incorrecto.

---

## Schema completo del API_PROFILE

```json
{
  "platform": "NombrePlataforma",
  "version": "vX.Y — [oficial] | [inferido]",
  "last_researched": "fecha",
  "confidence": "high | medium | low",
  "auth": {
    "method": "",
    "detail": "",
    "source": "[oficial|comunidad|confirmado en producción|inferido]"
  },
  "base_url": "",
  "pagination": {
    "type": "limit/offset | cursor | page | Link header | no documentado — aplicar estrategia defensiva",
    "params": {},
    "max_page_size": 0,
    "source": ""
  },
  "date_format": {
    "format": "",
    "timezone": "",
    "source": ""
  },
  "rate_limits": {
    "requests_per_minute": "N | no documentado — aplicar estrategia defensiva",
    "on_429": "comportamiento observado | no documentado — aplicar estrategia defensiva",
    "source": ""
  },
  "webhooks": {
    "supported": true,
    "events_available": [],
    "validation_method": "",
    "source": ""
  },
  "relevant_endpoints": [
    {
      "name": "",
      "method": "",
      "path": "",
      "required_params": [],
      "response_shape": {},
      "error_codes": {},
      "source": ""
    }
  ],
  "gotchas": [
    {
      "issue": "",
      "impact": "",
      "source": "[oficial|comunidad|confirmado en producción|inferido]"
    }
  ],
  "payload_from_user": {
    "provided": false,
    "content": null,
    "discrepancies_with_docs": []
  }
}
```

---

## Marcadores de confianza

Cada dato lleva uno de estos marcadores:

| Marcador | Significado |
|---------|-------------|
| `[oficial]` | Documentación oficial de la plataforma, versión específica |
| `[comunidad]` | Issues, foros, Stack Overflow, librerías existentes |
| `[confirmado en producción]` | Validado en proyectos reales de Bigtoone |
| `[inferido]` | Deducido de comportamiento observado, sin fuente directa |

Un dato marcado como `[inferido]` que llega al Developer
es mejor que un dato sin marcar que parece oficial pero no lo es.
El marcador le permite al Developer ser más defensivo con ese dato.

---

## Plataformas precargadas (no usar este template)

Estas plataformas tienen perfil completo en la vault:

| Plataforma | Nodo vault | Confianza | Última validación |
|---|---|---|---|
| PrestaShop 1.7.x | `[[prestashop]]` | high — producción | 2026-05-15 |
| Holded v1/v2 | `[[holded]]` | high — producción | 2026-05-20 |

Para plataformas en esta tabla: cargar el perfil existente como base.
Verificar solo si la versión del cliente difiere de la documentada.

---

## Output del Research

```json
{
  "status": "done | partial | blocked",
  "platforms_researched": ["PrestaShop", "Holded"],
  "api_profiles": {
    "PrestaShop": { },
    "Holded": { }
  },
  "unknowns_resolved": ["lista de unknowns que se resolvieron"],
  "unknowns_remaining": ["lista de unknowns que no se pudieron resolver"],
  "unknowns_remaining_strategy": "para cada uno: qué hacer si Developer los encuentra",
  "payloads_validated": false,
  "payload_discrepancies": [],
  "ready_for_developer": true
}
```

`ready_for_developer: true` requiere:
- Autenticación documentada para todas las plataformas — sin excepción
- Endpoints del happy path documentados para todas las plataformas — sin excepción
- Cero unknowns de prioridad 1 sin resolver

---

*Extraído de agents/03_agent_research.md §5 — 2026-05-25*
*Ver agente reducido en [[03_agent_research]] tras refactorización COMMIT 4*
