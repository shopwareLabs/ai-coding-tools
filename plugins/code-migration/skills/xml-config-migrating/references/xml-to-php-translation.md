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
| Decorator inner reference | explicit `service(Decorator::class . '.inner')` |
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
| Route import with prefix | `$routes->import('res')->prefix('/x')` |
| Inline `<route id="r" path="/p"><default key="_controller">C</default></route>` | `$routes->add('r', '/p')->controller('...')` |
| Extension config in packages XML (e.g. `<monolog:config>`) | YAML file, or PHP `$containerConfigurator->extension('monolog', [...])` |

## Gotchas

- **Anonymous inline services** can never be byte-identical: the XML loader hoists them to hidden `.N_Class~<hash>` services, `inline_service()` keeps them inline. This is the only acceptable ("inert") dump diff — document it, don't chase it.
- **Dashed tag attributes**: the XML loader duplicates `option-name="x"` as BOTH `option-name` and `option_name` keys. The PHP file must emit both, or the dump differs.
- **Scalar casting**: XML strings like `"true"` / `"0"` are cast by the loader. If the dump differs on a scalar, match the dump, not the XML text.
- **Multiline parameters**: preserved verbatim including whitespace — copy exactly.
- **Empty env-default parameter** `<parameter key="env(X)"/>` is the empty string `''`, not null.
- **`services_test.*`** loads only in the test env — its dumps must be taken with `APP_ENV=test`.
- **Empty `<services/>` file**: delete the XML without replacement; a config file is optional.
- **`Resources/config/config.xml` is not Symfony config** — plugin settings schema, stays XML, never migrate it.
