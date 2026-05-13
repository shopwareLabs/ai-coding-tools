# Refactoring Patterns

Patterns observed in Shopware's integration→unit migration PRs (shopware/shopware #16704, #16742, #16754, #16759, #16769). Apply the pattern that matches the SUT's shape.

## Pattern 1 — Container-fetched factory or stateless service

The integration test fetches a factory/service from the container and calls a method on it. The factory's collaborators are constructable.

**Before** (`tests/integration/...`):
```php
class ActionButtonResponseFactoryTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testBuildsNotificationResponse(): void
    {
        $factory = static::getContainer()->get(ActionButtonResponseFactory::class);
        $response = $factory->build(['type' => 'notification', 'status' => 'success']);

        static::assertSame(200, $response->getStatusCode());
        static::assertSame('notification', $response->getActionType());
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(ActionButtonResponseFactory::class)]
class ActionButtonResponseFactoryTest extends TestCase
{
    public function testBuildsNotificationResponse(): void
    {
        $factory = new ActionButtonResponseFactory([
            new NotificationResponseFactory(),
            new OpenModalResponseFactory(),
            // ... other response factories the SUT iterates
        ]);

        $response = $factory->build(['type' => 'notification', 'status' => 'success']);

        static::assertSame(200, $response->getStatusCode());
        static::assertSame('notification', $response->getActionType());
    }
}
```

Source: PR #16742, `ActionButtonResponseFactoryTest`.

## Pattern 2 — CompilerPass under test

The integration test exercises a Symfony compiler pass that transforms service definitions.

**Before** (`tests/integration/...`):
```php
class TwigEnvironmentCompilerPassTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testRegistersTemplateLoaders(): void
    {
        $twig = static::getContainer()->get('twig');
        static::assertContainsOnlyInstancesOf(BundleHierarchyLoader::class, $twig->getLoader()->getLoaders());
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(TwigEnvironmentCompilerPass::class)]
class TwigEnvironmentCompilerPassTest extends TestCase
{
    public function testRegistersTemplateLoaders(): void
    {
        $container = new ContainerBuilder();
        $container->register('twig.loader.bundle_hierarchy', BundleHierarchyLoader::class);
        $container->register('twig.loader', ChainLoader::class)->setPublic(true);
        // ... minimal definitions the pass operates on

        (new TwigEnvironmentCompilerPass())->process($container);

        $loaderDef = $container->getDefinition('twig.loader');
        static::assertSame(BundleHierarchyLoader::class, $loaderDef->getArgument(0)[0]->getClass());
    }
}
```

Source: PR #16742, `TwigEnvironmentCompilerPassTest`. The unit version asserts on `Definition` objects rather than booting a real Twig environment.

## Pattern 3 — Event subscriber

The integration test relies on the real `EventDispatcher` to deliver events.

**Before** (`tests/integration/...`):
```php
class AppFlowActionLoadedSubscriberTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testDecoratesFlowActionEntity(): void
    {
        $event = new EntityLoadedEvent(/* ... */);
        static::getContainer()->get(EventDispatcherInterface::class)->dispatch($event);

        $entity = $event->getEntities()[0];
        static::assertSame('decorated', $entity->getCustomFields()['x']);
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(AppFlowActionLoadedSubscriber::class)]
class AppFlowActionLoadedSubscriberTest extends TestCase
{
    public function testDecoratesFlowActionEntity(): void
    {
        $subscriber = new AppFlowActionLoadedSubscriber(/* mocked boundary deps */);
        $event = new EntityLoadedEvent(/* ... */);

        $subscriber->unserialize($event);  // invoke the handler directly

        $entity = $event->getEntities()[0];
        static::assertSame('decorated', $entity->getCustomFields()['x']);
    }
}
```

Source: PR #16754, `AppFlowActionLoadedSubscriberTest`.

## Pattern 4 — XML / JSON parser

The integration test parses fixture files relative to the kernel project dir.

**Before** (`tests/integration/...`):
```php
class CmsExtensionsTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testParsesValidCmsExtensions(): void
    {
        $kernel = static::getContainer()->get('kernel');
        $extensions = CmsExtensions::createFromXmlFile($kernel->getProjectDir() . '/tests/integration/.../_fixtures/valid/cmsExtensionsWithBlocks.xml');

        static::assertCount(2, $extensions->getBlocks()->getBlocks());
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(CmsExtensions::class)]
class CmsExtensionsTest extends TestCase
{
    public function testParsesValidCmsExtensions(): void
    {
        $extensions = CmsExtensions::createFromXmlFile(__DIR__ . '/../_fixtures/Resources/cmsExtensionsWithBlocks.xml');

        static::assertCount(2, $extensions->getBlocks()->getBlocks());
    }
}
```

Move the fixture file from `tests/integration/.../_fixtures/valid/` to `tests/unit/.../.../_fixtures/Resources/`. Use `__DIR__` relative paths in the unit test. Source: PR #16704.

## Pattern 5 — Constraint-only rule validation

The integration test creates an invalid `rule_condition` row via DAL only to assert the Symfony Validator's constraint violation.

**Before** (`tests/integration/...`):
```php
class CartAmountRuleTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testRejectsEmptyAmount(): void
    {
        try {
            $this->ruleConditionRepository->create([
                ['type' => CartAmountRule::class, 'value' => ['amount' => '']],
            ], $this->context);
            static::fail('expected WriteException');
        } catch (WriteException $e) {
            $violations = $e->getExceptions();
            static::assertCount(1, $violations);
            static::assertSame('NotBlank', $violations[0]->getViolations()[0]->getCode());
        }
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(CartAmountRule::class)]
class CartAmountRuleTest extends TestCase
{
    public function testRejectsEmptyAmount(): void
    {
        $rule = new CartAmountRule();
        $rule->assign(['amount' => '']);

        $validator = Validation::createValidatorBuilder()->getValidator();
        $violations = $validator->validate($rule->getAmount(), $rule->getConstraints()['amount']);

        static::assertCount(1, $violations);
        static::assertSame('NotBlank', $violations[0]->getCode());
    }
}
```

Source: PR #16769.

## Pattern 6 — DAL materializer

The integration test creates an entity via DAL only to read it back and call a pure method.

**Before** (`tests/integration/...`):
```php
class DateFieldSerializerTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testEncodesDate(): void
    {
        $this->productRepository->create([
            ['id' => $id = Uuid::randomHex(), 'name' => 'foo', 'releaseDate' => '2025-01-15', /* ... */],
        ], $this->context);

        $product = $this->productRepository->search(new Criteria([$id]), $this->context)->first();

        static::assertSame('2025-01-15', $product->getReleaseDate()->format('Y-m-d'));
    }
}
```

**After** (`tests/unit/...`):
```php
#[CoversClass(DateFieldSerializer::class)]
class DateFieldSerializerTest extends TestCase
{
    public function testEncodesDate(): void
    {
        $serializer = new DateFieldSerializer(
            new DefinitionInstanceRegistry(/* ... */),
            $this->createMock(ValidatorInterface::class)
        );
        $field = (new DateField('releaseDate', 'releaseDate'));
        $params = new WriteParameterBag(/* ... */);

        $encoded = iterator_to_array($serializer->encode($field, $params, new KeyValuePair('releaseDate', '2025-01-15', true), $params));

        static::assertSame('2025-01-15', $encoded['releaseDate']);
    }
}
```

Source: PR #16759. Field serializer tests don't need real DAL — the serializer's `encode`/`decode` methods operate on `WriteParameterBag` directly.

## When no pattern fits

If the test's apparatus doesn't match any of patterns 1–6 but PLACEMENT-001..007 say migrate, bucket the test as **keep** and surface the situation as a follow-up: "Migration would require a novel refactoring pattern. Capture the pattern, extend this file, then re-audit." Do not invent migrations without a known pattern.
