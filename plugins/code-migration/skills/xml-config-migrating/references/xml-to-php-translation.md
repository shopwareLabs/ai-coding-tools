# XML → PHP Configuration Translation Reference

## File skeletons

Service definitions (`services.php`):

```php
<?php declare(strict_types=1);

use Swag\Example\Service\MyService;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

return static function (ContainerConfigurator $containerConfigurator): void {
    $services = $containerConfigurator->services();

    $services->set(MyService::class)
        ->args([service('some.service.id')])
        ->tag('kernel.event_subscriber');
};
```

Routes (`routes.php`):

```php
<?php declare(strict_types=1);

use Symfony\Component\Routing\Loader\Configurator\RoutingConfigurator;

return static function (RoutingConfigurator $routes): void {
    $routes->import('../../Controller/**/*Controller.php', 'attribute');
};
```

## Style rules

- Every class reference: `use` statement + short `Foo::class` in the body — services, `service()` references, factories, configurators, aliases, `decorate()` targets, class-valued tag attributes. No inline FQCN strings.
- Name collisions between imported classes: import alias (`use Swag\A\Handler as AHandler;`).
- Global PHP classes (e.g. `\ArrayIterator::class`) keep the leading backslash in namespaced files — code-style fixers strip `use ArrayIterator;`.
- Plain string ids (e.g. `shopware.filesystem.private`) stay strings.

## Translation table

| XML | PHP |
|---|---|
| `<service id="Foo\Bar">` | `$services->set(Bar::class)` |
| `<service id="my.id" class="Foo\Bar">` | `$services->set('my.id', Bar::class)` |
| `<argument type="service" id="X"/>` | `service(X::class)` inside `->args([...])` |
| `on-invalid="null"` / `on-invalid="ignore"` | `service(...)->nullOnInvalid()` / `->ignoreOnInvalid()` |
| `%param%` as whole argument | `param('param')` |
| Literal `%` inside a longer string | stays `%%` |
| `%env(FOO)%` and processors like `%env(bool:FOO)%` | `env('FOO')`, `env('FOO')->bool()` / `->int()` / `->string()` / `->resolve()` — also inside collections and parameter values |
| `%env(default:param:VAR)%` | `env('VAR')->default('param')` |
| Parameter KEY `env(FOO)` (env default) | stays a literal string key: `->set('env(FOO)', 'default')` |
| `<tag name="x" priority="10" someAttr="y"/>` | `->tag('x', ['priority' => 10, 'someAttr' => 'y'])` |
| `<call method="setX">` | `->call('setX', [...])` |
| `<factory service="F" method="m"/>` | `->factory([service(F::class), 'm'])` |
| `<factory class="F" method="m"/>` (static) | `->factory([F::class, 'm'])` |
| `decorates="id"` (+ priority / on-invalid) | `->decorate('id', null, $priority, ContainerInterface::IGNORE_ON_INVALID_REFERENCE)` as applicable |
| Decorator inner reference | keep the XML's spelling: `id="Foo.inner"` → `service(Foo::class . '.inner')`; the magic `id=".inner"` → `service('.inner')` (both are accepted by the compiler pass — rewriting one into the other changes the file beyond the format) |
| `<tagged_iterator tag="t" index-by="key"/>` | `tagged_iterator('t', 'key')` — only pass attributes present in the XML |
| Service locator / tagged locator | `service_locator([...])` / `tagged_locator(...)` |
| `<argument type="expression">` | `expr('...')` |
| `<argument type="collection">` | PHP array |
| `<argument type="abstract">` | `abstract_arg('description')` |
| `<argument type="constant">` | the PHP constant directly |
| Anonymous inline `<service>` as argument | `inline_service(Foo::class)` (see gotchas) |
| `public="true"`, `lazy`, `shared`, `synthetic`, `abstract` | `->public()`, `->lazy()`, `->share(false)`, `->synthetic()`, `->abstract()` |
| `autowire="true"`, `autoconfigure="true"` on a `<service>` | `->autowire()`, `->autoconfigure()` — only when the XML already has them, never introduce |
| `<deprecated package="p" version="v">text</deprecated>` | `->deprecate('p', 'v', 'text')` |
| `<service id="a" alias="b" public="true"/>` | `$services->alias('a', 'b')->public()` |
| `<parameters><parameter key="k">v</parameter></parameters>` | `$containerConfigurator->parameters()->set('k', v)` |
| `<defaults autowire="true" public="true"/>` | `$services->defaults()->autowire()->public()` — replicate exactly, add nothing |
| `<instanceof id="Foo">` + tags | `$services->instanceof(Foo::class)->tag(...)` |
| `<import resource="x"/>` (routes) | `$routes->import('x')`; attribute imports: `$routes->import('path', 'attribute')` |
| `<when env="dev">` (routes) | `if ($routes->env() === 'dev') { ... }` |
| `<when env="test">` (services) | a `when@test` key in an array-return file — the closure form cannot express it (see gotchas) |
| Route import with prefix | `$routes->import('res')->prefix('/x')` |
| Inline `<route id="r" path="/p"><default key="_controller">C</default></route>` | `$routes->add('r', '/p')->controller('...')` |
| Extension config in packages XML (e.g. `<monolog:config>`) | YAML file, or PHP `$containerConfigurator->extension('monolog', [...])` |

## Gotchas

- **Anonymous inline services** can never be byte-identical: the XML loader hoists them to hidden `.N_Class~<hash>` services, `inline_service()` keeps them inline. This is the only acceptable ("inert") dump diff — document it, don't chase it.
- **Services `<when env>` needs the array-return file form**, not the closure: the loader registers the `.container.known_envs` parameter from a `when@<env>` key, and only the array-return branch produces one, so the closure translation drops the parameter and `verify-dumps.sh` reports DIFFERS on the params and container dumps. In the XML, `<when env>` is a child of `<container>` and a sibling of `<services>` — the XSD rejects it inside `<services>`. Every definition in the resulting PHP file follows the array-return dialect below, not the fluent translation table above.

  ```php
  <?php declare(strict_types=1);

  use Swag\Example\Service\MyService;
  use Swag\Example\Test\TestOnlyService;

  use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

  return [
      'services' => [
          MyService::class => [
              'class' => MyService::class,
              'arguments' => [service('some.service.id')],
              'tags' => ['kernel.event_subscriber'],
          ],
      ],
      'when@test' => [
          'services' => [
              TestOnlyService::class => ['class' => TestOnlyService::class],
          ],
      ],
  ];
  ```

- **Dashed tag attributes**: the XML loader duplicates `option-name="x"` as BOTH `option-name` and `option_name` keys. The PHP file must emit both, or the dump differs.
- **Scalar casting**: XML strings like `"true"` / `"0"` are cast by the loader. If the dump differs on a scalar, match the dump, not the XML text.
- **Multiline parameters**: preserved verbatim including whitespace — copy exactly.
- **Empty env-default parameter** `<parameter key="env(X)"/>` is the empty string `''`, not null.
- **`services_test.*`** loads only in the test env — its dumps must be taken with the test environment selected on the console command itself.
- **Empty `<services/>` file**: delete the XML without replacement; a config file is optional.
- **`Resources/config/config.xml` is not Symfony config** — plugin settings schema, stays XML, never migrate it.

## Array-return dialect

An array return from a services PHP file is not configurator output: the loader hands the array to the YAML services parser, so every key in the file is a YAML services key and none of the fluent spellings in the translation table apply inside it. A key outside the allowed set is rejected with an error naming the allowed keys, so a stray fluent spelling fails loudly rather than silently.

Value-level helpers still work inside `services` — `service()`, `inline_service()`, `tagged_iterator()`, `service_locator()`, `expr()`, `abstract_arg()`, `param()`, `env()` are all converted before the YAML parser sees them. They do not work inside `parameters`: that branch is processed with service values disallowed, and a `service()` there throws.

| Fluent form (translation table) | Array-return key |
|---|---|
| `$services->set(Foo::class)` | `Foo::class => ['class' => Foo::class]` |
| `->args([...])` | `'arguments' => [...]` |
| `->call('setX', [$a])` | `'calls' => [['setX', [$a]]]` |
| `->tag('x', ['priority' => 10, 'someAttr' => 'y'])` | `'tags' => [['name' => 'x', 'priority' => 10, 'someAttr' => 'y']]` |
| `$services->alias('a', 'b')->public()` | `'a' => ['alias' => 'b', 'public' => true]` |
| `->public()` | `'public' => true` |
| `->decorate('id', $inner, $priority, $onInvalid)` | `'decorates' => 'id'`, `'decoration_inner_name' => $inner`, `'decoration_priority' => $priority`, `'decoration_on_invalid' => …` |
| `->factory([service(F::class), 'm'])` | `'factory' => [service(F::class), 'm']` |
| `->configurator([service(C::class), 'm'])` | `'configurator' => [service(C::class), 'm']` |
| `->deprecate('p', 'v', 'text')` | `'deprecated' => ['package' => 'p', 'version' => 'v', 'message' => 'text']` |
| `->lazy()` | `'lazy' => true` |
| `->share(false)` | `'shared' => false` |
| `->synthetic()` | `'synthetic' => true` |
| `->abstract()` | `'abstract' => true` |
| `$containerConfigurator->parameters()->set('k', v)` | top-level `'parameters' => ['k' => v]` |
| `$services->defaults()->autowire()->public()` | `'services' => ['_defaults' => ['autowire' => true, 'public' => true]]` |
| `<when env="test">` | top-level `'when@test' => ['services' => [...]]` |

`_defaults` accepts only `public`, `tags`, `resource_tags`, `autowire`, `autoconfigure`, `bind`; anything else the XML `<defaults>` carried is repeated per definition instead. `decoration_on_invalid` takes `'exception'`, `'ignore'`, or an unquoted `null` — the string `'null'` is rejected with its own error. A `when@<env>` key is honoured only at the top level of the returned array: one nested inside another `when@` block registers nothing.

A `<when env="test">` fragment carrying a decorated service:

```xml
<container xmlns="http://symfony.com/schema/dic/services">
    <services>
        <service id="Swag\Example\Service\MyService"/>
    </services>

    <when env="test">
        <services>
            <service id="Swag\Example\Test\CountingDecorator"
                     decorates="Swag\Example\Service\MyService"
                     decoration-priority="10">
                <argument type="service" id="Swag\Example\Test\CountingDecorator.inner"/>
                <tag name="kernel.event_subscriber" priority="100"/>
            </service>
        </services>
    </when>
</container>
```

```php
<?php declare(strict_types=1);

use Swag\Example\Service\MyService;
use Swag\Example\Test\CountingDecorator;

use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

return [
    'services' => [
        MyService::class => ['class' => MyService::class],
    ],
    'when@test' => [
        'services' => [
            CountingDecorator::class => [
                'class' => CountingDecorator::class,
                'decorates' => MyService::class,
                'decoration_priority' => 10,
                'arguments' => [service(CountingDecorator::class . '.inner')],
                'tags' => [['name' => 'kernel.event_subscriber', 'priority' => 100]],
            ],
        ],
    ],
];
```
