---
id: INTEGRATION-002
title: No mocking of the system under test or its primary collaborators
group: integration
enforce: must-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
scoped-review: include
---

## No mocking of the system under test or its primary collaborators

**Scope**: all | **Enforce**: Must fix

Integration tests exist to exercise wired-up code. Mocking the SUT or a primary collaborator turns the test into a fake unit test that pays the integration cost without buying integration coverage. Mocks are allowed only at true external boundaries: outbound HTTP, mail dispatch, the system clock, randomness sources, third-party SDKs, and other I/O the test does not own.

### Detection

1. Find every `createMock(`, `createStub(`, `createPartialMock(`, `$this->getMockBuilder(` call.
2. For each, resolve the mocked class.
3. Flag if the mocked class is:
   - In the resolved source set (see `phpunit-integration-test-reviewing/SKILL.md` Phase 2 step 1 — every `.php` file directly inside the `src/` directory the test's path mirrors), or
   - A direct constructor dependency of any class in the resolved source set (read the source class to determine).
4. Allow if the mocked class is one of:
   - `Symfony\Contracts\HttpClient\HttpClientInterface` / Guzzle / curl wrappers
   - `Symfony\Component\Mailer\MailerInterface` and Shopware mail dispatch interfaces
   - `Psr\Clock\ClockInterface` / Shopware clock abstractions
   - Anything implementing a boundary interface the project uses for I/O
5. When in doubt, prefer the real service from the container.

```php
// INCORRECT - mocks a primary collaborator in the resolved source set
class OrderIndexerTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testRebuild(): void
    {
        $repository = $this->createMock(EntityRepository::class);
        $indexer = new OrderIndexer($repository);
        // ...
    }
}
```

### Fix

```php
// CORRECT - uses the wired-up collaborator
class OrderIndexerTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testRebuild(): void
    {
        $indexer = static::getContainer()->get(OrderIndexer::class);
        // ...
    }
}
```

### Cross-reference

If the test does not need real DAL, real persistence, or real DI wiring to make its assertion meaningful, the test itself is likely misplaced. See `INTEGRATION-008` and consider running the `phpunit-integration-to-unit-migrating` skill.
