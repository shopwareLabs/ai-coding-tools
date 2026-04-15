# Fail Hard Rules

**CRITICAL**: Hard failure is the default. Graceful degradation is silent failure — callers cannot distinguish a degraded result from a correct one, so corrupted state propagates unnoticed and poisons everything downstream. Applies to architecture, implementation, default parameters, and error handling, in every language and framework.

## Decision Test — run before writing any error handling, recovery path, or default value

> **"If this code path executes and produces output, am I 100% sure that output is correct?"**

- Yes → proceed
- No → **throw**. Never return a "best guess" result.

## MUST Fail Hard

```
Missing required input      → throw, never substitute defaults
Invalid state               → throw, never "best effort" recover
Unexpected type             → throw, never coerce
External dependency down    → throw, never return stale/empty/fake data
Validation failure          → reject, never sanitize and proceed
```

## BANNED Patterns

```
WRONG:   try { real() } catch { fallback() }
CORRECT: let it throw  (unless fallback is a documented equivalent path)

WRONG:   $requiredId ?? 'default-id'
CORRECT: $requiredId ?? throw new InvalidArgumentException(...)

WRONG:   catch (Exception $e) { return []; }       // indistinguishable from valid empty
CORRECT: catch (Exception $e) { throw $e; }

WRONG:   catch (Exception $e) { $logger->error($e); return; }   // silent to caller
CORRECT: catch (Exception $e) { $logger->error($e); throw; }
```

Empty collection / null / zero returns on error paths are BANNED: they look like valid empty results.

## Default Parameters

- Required data → **NO default**. Caller MUST supply it.
- ALLOWED only for truly optional behavior tuning (pagination limit, timeout)
- NEVER default a correctness-affecting parameter: validation mode, security policy, identity, tenant scope

## Architecture

```
Circuit breaker        → ACCEPTABLE    (fails hard after policy runs out)
Retry with backoff     → ACCEPTABLE    (fails hard after attempts exhausted)
Timeout                → ACCEPTABLE    (fails hard at deadline)
Bulkhead isolation     → ACCEPTABLE    (failure stays visible in its domain)
"Degraded mode"        → NOT ACCEPTABLE (silently changes outputs)
```

## Allowed Exceptions (narrow, explicit)

Degradation is ALLOWED only when **ALL** of the following hold:

1. **Business criticality** → enclosing flow cannot tolerate hard failure (checkout, payment capture, safety-critical control loop)
2. **Secured alternative** → fallback produces equivalent results OR degradation is loudly communicated to user / operator / caller
3. **Documented** → trade-off written at the call site AND in architecture notes
4. **Narrow blast radius** → degradation does not poison data feeding other systems

**Second gate**: if the degraded path would produce invalid data (disabled validation, disabled fraud detection, skipped authorization), hard failure is STILL preferred. Corrupted checkout data is worse than a failed checkout.

## Red Flags

Stop and reconsider if you catch yourself thinking:

| Thought                              | Reality                                         |
|--------------------------------------|-------------------------------------------------|
| "Let's be defensive here"            | Defensive code hides the bug you should see    |
| "We'll return empty if it fails"     | Caller cannot distinguish empty from broken    |
| "Add a sensible default"             | Defaults for required inputs mask mistakes     |
| "Graceful degradation improves UX"   | Wrong answers are worse UX than clear errors   |
| "Just log and continue"              | Logs are not a substitute for failing loudly   |
| "It's fine, the caller can check"    | Callers do not check. Make it impossible.     |
| "We can always add validation later" | The invalid data is already in the database   |
