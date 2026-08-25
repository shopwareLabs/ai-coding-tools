# Integration Test Template

Single template with a base block plus one conditional section per integration pattern. The generator selects exactly one pattern section based on source analysis. All sections are calibrated against recently added high-quality tests in `shopware/shopware`.

## Base block (always included)

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Integration\{Area}\{SubNamespace};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\Context;
{CONDITIONAL_IMPORTS}
use {SourceFullClassName};

/**
 * @internal
 */
{CONDITIONAL_GROUP_ATTRIBUTE}
#[CoversClass({SourceClassName}::class)]
class {SourceClassName}Test extends TestCase
{
    {CONDITIONAL_TRAITS}

    {CONDITIONAL_PROPERTIES}

    protected function setUp(): void
    {
        {CONDITIONAL_SETUP}
    }

    {CONDITIONAL_TEARDOWN}

    {CONDITIONAL_TEST_METHODS}

    {CONDITIONAL_HELPER_METHODS}
}
```

> [!NOTE]
> The template does NOT add `#[Depends]` anywhere (INTEGRATION-005). Each generated test method must be independent.
> It also does NOT add `#[Package]` (CONV-015): a source-ownership annotation has no meaning on a test class. Do not copy it from the SUT even though many existing Shopware tests carry it.

## Conditional: `controller` pattern

Include when the source extends `AbstractController` or an `Abstract*Route`, or has `#[Route]` methods.

### Additional imports

```php
use PHPUnit\Framework\Attributes\Group;
use Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour;
use Shopware\Core\Framework\Test\TestCaseBase\SalesChannelApiTestBehaviour;
use Shopware\Core\Test\Stub\Framework\IdsCollection;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Component\HttpFoundation\Request;
```

> [!NOTE]
> Swap `SalesChannelApiTestBehaviour` for `AdminApiTestBehaviour` (admin API) or `StorefrontControllerTestBehaviour` (storefront). Add `MailTemplateTestBehaviour` when the route dispatches mail.

### Group attribute

```php
#[Group('store-api')]
```

(Use `'admin-api'` or `'storefront'` for the other channels.)

### Traits

```php
use IntegrationTestBehaviour;
use SalesChannelApiTestBehaviour;
```

### Properties

```php
private KernelBrowser $browser;

private IdsCollection $ids;
```

### setUp

```php
$this->ids = new IdsCollection();

$this->browser = $this->createCustomSalesChannelBrowser([
    'id' => $this->ids->create('sales-channel'),
]);
```

### Test method

```php
public function test{Method}{Condition}{ExpectedResult}(): void
{
    // TODO: arrange any required fixtures via static::getContainer()->get('<entity>.repository')->create(...)

    $this->browser->request(
        Request::METHOD_{HTTP_METHOD},
        '/store-api/{route_path}',
        {REQUEST_PAYLOAD}
    );

    $response = $this->browser->getResponse();
    static::assertSame({EXPECTED_STATUS}, $response->getStatusCode(), (string) $response->getContent());

    $body = json_decode((string) $response->getContent(), true, 512, \JSON_THROW_ON_ERROR);
    // TODO: assert response body shape AND any persisted side effects through DAL
    static::assertArrayHasKey('{expected_key}', $body);
}
```

### Mail-dispatching variant

Add `use MailTemplateTestBehaviour;` and observe the dispatched mail via an event listener:

```php
public function test{Method}DispatchesMail(): void
{
    $eventDispatcher = static::getContainer()->get('event_dispatcher');

    $mailSent = false;
    $listener = static function (\Shopware\Core\Content\MailTemplate\Service\Event\MailSentEvent $event) use (&$mailSent): void {
        $mailSent = true;
        static::assertSame('{Expected mail subject}', $event->getSubject());
    };
    $this->addEventListener($eventDispatcher, \Shopware\Core\Content\MailTemplate\Service\Event\MailSentEvent::class, $listener);

    $this->browser->request(Request::METHOD_POST, '/store-api/{route_path}', {REQUEST_PAYLOAD});

    static::assertSame(200, $this->browser->getResponse()->getStatusCode());
    static::assertTrue($mailSent);

    $eventDispatcher->removeListener(\Shopware\Core\Content\MailTemplate\Service\Event\MailSentEvent::class, $listener);
}
```

## Conditional: `scheduled-task` pattern

Include when the source extends `ScheduledTaskHandler`. The handler is invoked directly via `run()`; the bus is not traversed.

### Additional imports

```php
use Doctrine\DBAL\Connection;
use Shopware\Core\Framework\Test\TestCaseBase\DatabaseTransactionBehaviour;
use Shopware\Core\Framework\Test\TestCaseBase\KernelTestBehaviour;
use Shopware\Core\Framework\Uuid\Uuid;
use Shopware\Core\Test\Stub\Framework\IdsCollection;
```

### Traits

```php
use DatabaseTransactionBehaviour;
use KernelTestBehaviour;
```

### Properties

```php
private {SourceClassName} $handler;

private Connection $connection;

private IdsCollection $ids;
```

### setUp

```php
parent::setUp();
$this->handler = static::getContainer()->get({SourceClassName}::class);
$this->connection = static::getContainer()->get(Connection::class);
$this->ids = new IdsCollection();
```

### Test method

```php
public function test{ExpectedBehavior}(): void
{
    // TODO: arrange prerequisite rows via $this->connection->insert(...) or DAL fixtures

    $this->handler->run();

    $count = $this->connection->fetchOne(
        'SELECT COUNT(*) FROM {table} WHERE {predicate}',
        [{params}]
    );
    static::assertSame('{expected_count}', (string) $count);
}
```

## Conditional: `message-handler` pattern

Include when the source has `#[AsMessageHandler]` on `__invoke()` and the parameter is a domain message (NOT a `ScheduledTask`). For most handlers, invoke directly rather than dispatching through the bus.

### Additional imports

```php
use Shopware\Core\Framework\DataAbstractionLayer\EntityRepository;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour;
use Shopware\Core\Framework\Uuid\Uuid;
```

### Traits

```php
use IntegrationTestBehaviour;
```

### Properties

```php
private {SourceClassName} $handler;

/**
 * @var EntityRepository<{Entity}Collection>
 */
private EntityRepository $repository;
```

### setUp

```php
$this->handler = static::getContainer()->get({SourceClassName}::class);
$this->repository = static::getContainer()->get('{entity}.repository');
```

### Test method (direct invocation)

```php
public function testHandlerProcessesMessage(): void
{
    $context = Context::createDefaultContext();
    $id = Uuid::randomHex();
    // TODO: arrange prerequisite state via DAL so the message has something to operate on

    ($this->handler)(new {MessageClass}({CONSTRUCTOR_ARGS}));

    $entity = $this->repository->search(new Criteria([$id]), $context)->first();
    static::assertNotNull($entity); // precondition — NOT the behavior under test
    // Required: assert the handler-produced state. assertNotNull alone proves nothing about the handler.
    static::assertSame('{expected_value}', $entity->get{Field}());
}
```

> [!NOTE]
> If the test must traverse the real bus (e.g., to verify middleware or transport routing), replace the direct invocation with `static::getContainer()->get('messenger.bus.test_shopware')->dispatch(new {MessageClass}(...))`. This is the minority case. `messenger.bus.test_shopware` is the test-environment bus id — a `TraceableMessageBus` decorating the application bus, and the id `QueueTestBehaviour` uses.

## Conditional: `indexer` pattern

Include when the source extends `EntityIndexer`. The realtime flow (`update($event)`) is the dominant pattern; reserve `iterate()` → `handle()` for backfill-specific tests.

### Additional imports

```php
use Shopware\Core\Framework\DataAbstractionLayer\EntityRepository;
use Shopware\Core\Framework\DataAbstractionLayer\Indexing\EntityIndexingMessage;
use Shopware\Core\Framework\Test\TestCaseBase\DatabaseTransactionBehaviour;
use Shopware\Core\Framework\Test\TestCaseBase\KernelTestBehaviour;
use Shopware\Core\Framework\Uuid\Uuid;
```

### Traits

```php
use DatabaseTransactionBehaviour;
use KernelTestBehaviour;
```

### Properties

```php
private {IndexerClass} $indexer;

/**
 * @var EntityRepository<{Entity}Collection>
 */
private EntityRepository $repository;
```

### setUp

```php
parent::setUp();
$this->indexer = static::getContainer()->get({IndexerClass}::class);
$this->repository = static::getContainer()->get('{entity}.repository');
```

### Test method (realtime flow)

```php
public function testUpdateQueues{Entity}IdsForReindexing(): void
{
    $context = Context::createDefaultContext();
    $id = Uuid::randomHex();
    // TODO: arrange the entity via $this->repository->create(...) so the update event references something concrete

    $event = $this->repository->update([
        ['id' => $id, '{field}' => '{new_value}'],
    ], $context);

    $message = $this->indexer->update($event);

    static::assertInstanceOf(EntityIndexingMessage::class, $message);
    $ids = $message->getData();
    static::assertIsArray($ids);
    static::assertContains($id, $ids);
}
```

## Conditional: `dal-flow` pattern

Include when the SUT writes through DAL and the assertion verifies persisted state.

### Additional imports

```php
use Shopware\Core\Framework\DataAbstractionLayer\EntityRepository;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour;
use Shopware\Core\Framework\Uuid\Uuid;
```

### Traits

```php
use IntegrationTestBehaviour;
```

### Properties

```php
private {SourceClassName} $sut;

/**
 * @var EntityRepository<{Entity}Collection>
 */
private EntityRepository $repository;

private Context $context;
```

### setUp

```php
$this->context = Context::createDefaultContext();
$this->sut = static::getContainer()->get({SourceClassName}::class);
$this->repository = static::getContainer()->get('{entity}.repository');
```

### Test method

```php
public function test{Method}PersistsExpectedState(): void
{
    $id = Uuid::randomHex();
    // TODO: arrange prerequisites via $this->repository->create(...) — never markTestSkipped (INTEGRATION-006)

    $this->sut->{methodName}({METHOD_ARGS}, $this->context);

    $entity = $this->repository->search(new Criteria([$id]), $this->context)->first();
    static::assertNotNull($entity); // precondition — NOT the behavior under test
    // Required: assert the persisted fields. assertNotNull alone does not verify the write.
    static::assertSame('{expected_value}', $entity->get{Field}());
}
```

## Conditional: `multi-service` pattern

Include when the SUT coordinates ≥ 2 stateful collaborators.

### Additional imports

```php
use Shopware\Core\Framework\DataAbstractionLayer\EntityRepository;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour;
use Shopware\Core\Framework\Uuid\Uuid;
use Shopware\Core\System\SystemConfig\SystemConfigService;
use Symfony\Contracts\EventDispatcher\EventDispatcherInterface;
```

### Traits

```php
use IntegrationTestBehaviour;
```

> [!NOTE]
> Add domain behaviour traits per the SUT's dependencies: `AppSystemTestBehaviour` and `GuzzleTestClientBehaviour` for App-system tests, `MailTemplateTestBehaviour` when mail is dispatched, etc.

### Properties

```php
private {SourceClassName} $sut;

/**
 * @var EntityRepository<{Entity}Collection>
 */
private EntityRepository $repository;

private SystemConfigService $systemConfig;

private EventDispatcherInterface $dispatcher;

private Context $context;
```

### setUp

```php
$this->context = Context::createDefaultContext();
$this->sut = static::getContainer()->get({SourceClassName}::class);
$this->repository = static::getContainer()->get('{entity}.repository');
$this->systemConfig = static::getContainer()->get(SystemConfigService::class);
$this->dispatcher = static::getContainer()->get('event_dispatcher');
```

### Test method

```php
public function test{Method}CoordinatesCollaborators(): void
{
    $id = Uuid::randomHex();
    // TODO: configure inputs across the collaborators (DAL fixtures keyed on $id, SystemConfig keys, listener registration)

    $eventObserved = false;
    $listener = static function ({EventClass} $event) use (&$eventObserved): void {
        $eventObserved = true;
    };
    $this->addEventListener($this->dispatcher, {EventClass}::class, $listener);

    try {
        $this->sut->{methodName}({METHOD_ARGS}, $this->context);

        static::assertTrue($eventObserved, '{EventClass} was not dispatched');

        // Filter by the arranged id — an unfiltered new Criteria() can pass on unrelated pre-existing rows.
        $entity = $this->repository->search(new Criteria([$id]), $this->context)->first();
        static::assertNotNull($entity); // precondition — NOT the behavior under test
        // Required: assert state across at least one more collaborator (cache, persisted field, row count).
        static::assertSame('{expected_value}', $entity->get{Field}());
    } finally {
        $this->dispatcher->removeListener({EventClass}::class, $listener);
    }
}
```

## Conditional: non-transactional cleanup

Include when the test performs DDL, filesystem writes, or cache writes (INTEGRATION-003).

### Properties addition

```php
private Connection $connection;
```

### setUp addition

```php
$this->connection = static::getContainer()->get(Connection::class);
```

### tearDown

```php
protected function tearDown(): void
{
    // Clean up any DDL the test may have created
    $this->connection->executeStatement('DROP TABLE IF EXISTS `{temp_table}`');
    // Or: clean up filesystem, cache keys, etc.
    parent::tearDown();
}
```

## Placeholder Reference

| Placeholder | Source |
|-------------|--------|
| `{Area}` | From namespace: `Core`, `Administration`, `Storefront`, `Elasticsearch` |
| `{SubNamespace}` | Mirror of source class subnamespace (everything after the area segment) |
| `{SourceFullClassName}` | Full qualified class name from source |
| `{SourceClassName}` | Short class name |
| `{IndexerClass}` | Short class name when the SUT is the indexer itself |
| `{Method}` | Public method under test (PascalCased for test method name) |
| `{methodName}` | Public method under test (camelCased for invocation) |
| `{Condition}` | Test scenario name fragment |
| `{ExpectedResult}` / `{ExpectedBehavior}` | Test outcome name fragment |
| `{HTTP_METHOD}` | `GET`, `POST`, `PATCH`, `DELETE` — from the `#[Route]` attribute |
| `{route_path}` | Route path from `#[Route]` |
| `{REQUEST_PAYLOAD}` | JSON payload + headers for the request |
| `{EXPECTED_STATUS}` | Expected HTTP status code |
| `{expected_key}` | Top-level key the response body must contain |
| `{MessageClass}` | Message class the handler accepts |
| `{CONSTRUCTOR_ARGS}` | Message constructor arguments |
| `{METHOD_ARGS}` | Arguments to the SUT method |
| `{Entity}` | Entity name (PascalCase, e.g., `Product`) |
| `{entity}` | Entity name (snake_case, e.g., `product`) |
| `{field}`, `{new_value}` | Field name and new value used to trigger the indexer update event |
| `{table}`, `{predicate}`, `{params}`, `{expected_count}` | SQL fragments for scheduled-task assertions |
| `{EventClass}` | Event class dispatched by the SUT |
| `{temp_table}` | Name of a temporary table created via DDL |
