# Symfony and PHP

## Symfony Rules That Matter in Shopware

- Prefer constructor injection and explicit service dependencies.
- Keep services private unless they are meant to be fetched as public entry points.
- Organize business logic into small services with clear boundaries.
- Use service decoration or composition instead of patching third-party code.
- Wrap external HTTP access with Symfony HttpClient-based services that define timeouts and, where appropriate, retry policy.
- Use Messenger for asynchronous work instead of inventing custom background loops.
- Use Monolog channels and structured context without leaking secrets.

Example patterns:

```php
// Bad: runtime service lookup and hidden coupling
final class SyncController
{
    public function __invoke(ContainerInterface $container): Response
    {
        $client = $container->get(MyPspClient::class);
        $client->sync();

        return new Response();
    }
}
```

```php
// Preferred: explicit dependency graph and thin entry point
final class SyncController
{
    public function __construct(private readonly SyncService $syncService)
    {
    }

    public function __invoke(): Response
    {
        $this->syncService->sync();

        return new Response();
    }
}
```

```php
// Preferred: bound both idle time and total duration
final class ProviderClient
{
    public function __construct(private readonly HttpClientInterface $httpClient)
    {
    }

    public function fetchStatus(string $reference): array
    {
        return $this->httpClient->request('GET', '/status/' . $reference, [
            'timeout' => 5,        // idle timeout between chunks
            'max_duration' => 10,  // hard ceiling on the whole request
        ])->toArray();
    }
}
```

Symfony's `timeout` is an **idle** timeout, not a wall-clock bound — a provider that trickles bytes holds the worker indefinitely under `timeout` alone. Always pair it with `max_duration` on request-path calls, where slow providers can exhaust PHP-FPM capacity.

## PHP Baseline

Apply these rules unless the project has a stricter local standard:

- declare strict types in PHP files
- prefer DRY and KISS over defensive ceremony
- use typed parameters, properties, and return types
- model structured domain data explicitly when arrays become ambiguous
- keep public APIs clear about nullability and failure modes
- use exceptions for exceptional flows, not normal branching
- prefer immutable or append-only patterns for state that is replayed or retried
- use parameterized SQL when DAL is not suitable
- avoid hidden global state and runtime service lookups
- avoid redundant normalization, casting, or fallback branches when the contract already guarantees the value

Example patterns:

```php
// Type alone does not establish canonical whitespace or identifier validity
$code = trim($requestDto->getWebhookCode());
```

```php
// Use directly only when validation already guarantees the required canonical value
$code = $requestDto->getWebhookCode();
```

## Shopware-Specific Translation of These Rules

- Symfony service discipline maps directly to Shopware plugin service design.
- HttpClient and Messenger guidance matter most for external APIs, webhooks, imports, and payment providers.
- Logging rules matter most for admin operations, background workers, and payment flows where PII and secrets are easy to leak.
- PHP typing and explicit domain models matter most around DAL payloads, provider adapters, and custom entity state.
- Keep framework examples aligned with Shopware extension points. If a Symfony pattern fights Shopware's route scopes, DAL, or state handlers, choose the Shopware-compatible variant.
- If a safeguard is needed, tie it to a concrete failure mode in the actual Shopware code path instead of adding hypothetical protection everywhere.

## Registered But Inert Code

Registration alone does not demonstrate a defect or meaningful runtime cost. Trace the expected behavior, actual invocation, and observable impact before reporting a correctness/performance finding.

Candidates to inspect:

- **Empty/log-only subscribers** may be placeholders or intentional observability. Report missing required behavior only when a reachable flow depends on it; measure hot-path cost rather than asserting it.
- **Pure-delegation decorators** may preserve an extension seam or BC contract. Cleanup is optional unless they alter behavior or demonstrably add material cost.
- **Unused injected dependencies** are cleanup candidates; lazy services, proxies, and optimized container definitions mean eager construction is not guaranteed. Inspect wiring and profiling before claiming overhead.
- **Wrong event FQCN** can prevent a required invalidation or key extension. Verify the target-version dispatch and show the affected response/write path; see `CategoryLevelLoaderCacheKeyEvent` in [backend guidance](04-plugin-backend.md).

Without demonstrated impact, label the item cleanup or a verification gap, not a confirmed defect.

## 6.7 Runtime And Framework Notes

### Symfony And PHP Versions

- Symfony 7.3 baseline from Shopware 6.7.2.
- Symfony 7.4 from 6.7.7.
- PHP 8.2 minimum; 6.7.15.1 declares support for PHP 8.2, 8.3, 8.4, and 8.5. A CI matrix omission is not a removed runtime constraint.
- Keep generated plugin syntax compatible with the project's declared PHP floor; for an 8.2 floor, do not use 8.3 typed class constants or 8.4 property hooks.
- `php-redis` extension v6.1+ required from 6.7.7.

Sources: [6.7.15.1 package constraints](https://github.com/shopware/shopware/blob/v6.7.15.1/composer.json), [6.7 upgrade guide](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md). Resolve installed Shopware/Symfony packages first; [6.6's Symfony 7 upgrade](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.6.md#symfony-7-upgrade) does not imply it supports all APIs of the 6.7.15.1 Symfony 7.4 baseline.

### Constraints Use Named Arguments

Symfony validator constraint constructors take named arguments instead of options arrays.

```php
// Bad
$constraint = new CustomerEmailUnique(['salesChannelContext' => $context]);

// Preferred
$constraint = new CustomerEmailUnique(salesChannelContext: $context);
```

Source: UPGRADE-6.7.md §6.7.3.0.

### `ResetInterface` For Long-Running Runtimes

FrankenPHP and RoadRunner keep worker processes alive across requests. Services holding request-scoped state must implement `Symfony\Contracts\Service\ResetInterface::reset()` to clear it.

```php
final class RequestContextCache implements ResetInterface
{
    private array $cache = [];

    public function reset(): void
    {
        $this->cache = [];
    }
}
```

Applies to per-request caches, current-context wrappers, per-request idempotency guards, and anything else that must not leak across requests.

Source: release notes 6.7.2.

## Source Anchors

- [Symfony 7.4 HttpClient timeouts](https://symfony.com/doc/7.4/http_client.html#dealing-with-network-timeouts): `timeout` is idle time, `max_duration` bounds the whole exchange.
- [Symfony lazy services](https://symfony.com/doc/7.4/service_container/lazy_services.html): injection is not proof of eager construction.
- [CategoryLevelLoaderCacheKeyEvent dispatch](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Category/Service/CachedDefaultCategoryLevelLoader.php): prove which key the listener must extend.
