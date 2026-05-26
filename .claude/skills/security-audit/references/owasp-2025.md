# OWASP Checklists 2025-2026
<!-- Source: agamm/claude-code-owasp — extracted checklists only -->

---

## OWASP Top 10:2025

| # | Vulnerability | Key Prevention |
|---|---------------|----------------|
| A01 | Broken Access Control | Deny by default, enforce server-side, verify ownership |
| A02 | Security Misconfiguration | Harden configs, disable defaults, minimize features |
| A03 | Supply Chain Failures | Lock versions, verify integrity, audit dependencies |
| A04 | Cryptographic Failures | TLS 1.2+, AES-256-GCM, Argon2/bcrypt for passwords |
| A05 | Injection | Parameterized queries, input validation, safe APIs |
| A06 | Insecure Design | Threat model, rate limit, design security controls |
| A07 | Auth Failures | MFA, check breached passwords, secure sessions |
| A08 | Integrity Failures | Sign packages, SRI for CDN, safe serialization |
| A09 | Logging Failures | Log security events, structured format, alerting |
| A10 | Exception Handling | Fail-closed, hide internals, log with context |

### Security Code Review Checklist

**Input Handling**
- [ ] All user input validated server-side
- [ ] Using parameterized queries (not string concatenation)
- [ ] Input length limits enforced
- [ ] Allowlist validation preferred over denylist

**Authentication & Sessions**
- [ ] Passwords hashed with Argon2/bcrypt (not MD5/SHA1)
- [ ] Session tokens have sufficient entropy (128+ bits)
- [ ] Sessions invalidated on logout
- [ ] MFA available for sensitive operations

**Access Control**
- [ ] Check for framework-level auth middleware before flagging missing per-route auth
- [ ] Authorization checked on every request
- [ ] Using object references user cannot manipulate
- [ ] Deny by default policy
- [ ] Privilege escalation paths reviewed

**Data Protection**
- [ ] Sensitive data encrypted at rest
- [ ] TLS for all data in transit
- [ ] No sensitive data in URLs/logs
- [ ] Secrets in environment/vault (not code)

**Error Handling**
- [ ] No stack traces exposed to users
- [ ] Fail-closed on errors (deny, not allow)
- [ ] All exceptions logged with context
- [ ] Consistent error responses (no enumeration)

---

## OWASP LLM Top 10:2025

| # | Risk | Key Mitigation |
|---|------|----------------|
| LLM01 | Prompt Injection | Separate trusted instructions from untrusted data, filter outputs, isolate privileges |
| LLM02 | Sensitive Information Disclosure | Sanitize training/RAG data, strip PII from context, restrict retrieval per user |
| LLM03 | Supply Chain | Verify model provenance and signatures, vet third-party hubs, lock versions |
| LLM04 | Data and Model Poisoning | Validate training/fine-tuning sources, anomaly-detect on ingestion |
| LLM05 | Improper Output Handling | Treat all LLM output as untrusted — validate, escape, or sandbox before passing downstream |
| LLM06 | Excessive Agency | Minimize tools and permissions, require human approval for destructive actions |
| LLM07 | System Prompt Leakage | Never put secrets/keys/auth logic in system prompt; assume it's extractable |
| LLM08 | Vector and Embedding Weaknesses | Tenant-isolate vector stores, access-control on retrieval, sign/hash chunks |
| LLM09 | Misinformation | Cite sources, surface confidence, require grounding for high-stakes answers |
| LLM10 | Unbounded Consumption | Rate-limit per user/key, cap tokens and tool calls, monitor cost, hard timeouts |

### LLM Application Security Checklist

- [ ] User input never blindly concatenated into system prompt — use clear delimiters or structured roles
- [ ] LLM output treated as untrusted before reaching tool, DOM, shell, SQL, or `eval`
- [ ] Tool/function-calling surface is minimal and least-privilege
- [ ] Destructive or external-effect tools require explicit human approval
- [ ] System prompt contains no secrets, keys, or authorization rules
- [ ] RAG sources trusted, signed, or quarantined by trust level (defends indirect prompt injection)
- [ ] Per-user token / request / cost budgets enforced
- [ ] Hard timeouts on completions and tool calls
- [ ] PII and customer data redacted before being sent to the model or logged
- [ ] Model, embedding model, and adapter versions pinned and verifiable

---

## OWASP Agentic AI Top 10:2026 (ASI01-ASI10)

| ID | Risk | Mitigation |
|----|------|------------|
| ASI01 | Goal Hijack | Input sanitization, goal boundaries, behavioral monitoring |
| ASI02 | Tool Misuse | Least privilege, fine-grained permissions, validate I/O |
| ASI03 | Identity & Privilege Abuse | Short-lived scoped tokens, identity verification |
| ASI04 | Supply Chain | Verify signatures, sandbox, allowlist plugins/MCP servers |
| ASI05 | Code Execution | Sandbox execution, static analysis, human approval |
| ASI06 | Memory Poisoning | Validate stored content, segment by trust level |
| ASI07 | Insecure Inter-Agent Comms | Authenticate, encrypt, verify message integrity |
| ASI08 | Cascading Failures | Circuit breakers, graceful degradation, isolation |
| ASI09 | Human-Agent Trust Exploitation | Label AI content, user education, verification steps |
| ASI10 | Rogue Agents | Behavior monitoring, kill switches, anomaly detection |

### Agent Security Checklist

- [ ] All agent inputs sanitized and validated
- [ ] Tools operate with minimum required permissions
- [ ] Credentials are short-lived and scoped
- [ ] Third-party plugins verified and sandboxed
- [ ] Code execution happens in isolated environments
- [ ] Agent communications authenticated and encrypted
- [ ] Circuit breakers between agent components
- [ ] Human approval for sensitive operations
- [ ] Behavior monitoring for anomaly detection
- [ ] Kill switch available for agent systems

---

## Bigtoone / bt-engine Specific

Para Lambda Node.js con DynamoDB + Lambda Function URL:

**Injection en Lambda**
- [ ] Path params / query string validados con zod antes de tocar DynamoDB
- [ ] `PK`/`SK` construidos con valores allowlisteados, nunca interpolación directa de `event.body`

**Logging (A09 + LLM09)**
- [ ] pino no loguea `Authorization`, `x-api-key`, `client_token`, campos PCI
- [ ] Lambda: `pino-lambda` redacta headers sensibles automáticamente

**Secretos**
- [ ] Ningún secret en `process.env` de Serverless.yml en texto plano — siempre SSM / Secrets Manager
- [ ] `client_token` de Revo nunca en logs ni DynamoDB sin cifrar

**Webhooks (R-SEC-1 a R-SEC-5)**
- [ ] Firma validada ANTES de procesar cualquier payload
- [ ] Raw body preservado como Buffer antes de JSON.parse
- [ ] `crypto.timingSafeEqual` para comparar firmas
- [ ] Respuesta 401 (no 403) en firma inválida
- [ ] Payload no validado no se loguea nunca

**Agentic (ASI relevantes para bt-engine)**
- [ ] Orchestrator valida `intent_class` antes de delegar a subagente
- [ ] Subagentes no tienen permisos de escritura a DynamoDB sin pasar por Orchestrator
- [ ] Cada lambda loguea su `session_id` para trazabilidad cruzada
