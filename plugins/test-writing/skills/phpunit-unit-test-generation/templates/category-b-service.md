# Category B: Service Test Template

## Contents
- [When to Use](#when-to-use)
- [Basic Template](#template)
- [With SystemConfigService](#with-systemconfigservice)
- [With HTTP Client Mock](#with-http-client-mock)

---

## When to Use

Use for classes with:
- Constructor dependencies (services, repositories, config)
- Business logic methods
- No direct DAL repository usage (use Category D for those)

**Skip tests for**:
- Methods that only delegate to dependencies without logic
- Pure passthrough constructors

## Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\MockObject\Stub;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
// Import Shopware stubs: StaticSystemConfigService, StaticEntityRepository

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    private {TargetClass} $subject;
    // Use Foo&Stub for dependencies where you only configure return values
    // Use Foo&MockObject only when you need expects() for interaction verification

    protected function setUp(): void
    {
        // Initialize Shopware stubs (preferred over PHPUnit stubs/mocks)
        // $this->configService = new StaticSystemConfigService([...]);

        // Initialize PHPUnit stubs for other dependencies (not mocks — use createStub())
        // $this->dependency = $this->createStub(SomeDependency::class);
        // $this->dependency->method('getSomething')->willReturn('value');

        // For side-effect dependencies (event dispatchers, HTTP clients): use createMock() + expects()
        // $this->eventDispatcher = $this->createMock(EventDispatcherInterface::class);

        // Create subject under test
        $this->subject = new {TargetClass}(
            // Pass dependencies
        );
    }

    // 1. HAPPY PATH
    #[TestDox('returns expected result for valid input')]
    public function test{Method}Returns{Expected}(): void
    {
        // Arrange
        $input = /* prepare input */;

        // Act
        $result = $this->subject->{method}($input);

        // Assert
        static::assertSame($expected, $result);
    }

    #[TestDox('processes valid input successfully')]
    public function test{Method}WithValidInputSucceeds(): void
    {
        // Arrange
        $input = /* valid input */;

        // Act
        $result = $this->subject->{method}($input);

        // Assert
        static::assertNotNull($result);
        static::assertInstanceOf(ExpectedClass::class, $result);
    }

    // 2. VARIATIONS
    #[TestDox('handles variation correctly')]
    public function test{Method}With{Variation}Returns{Expected}(): void
    {
        // Arrange - setup variation
        $input = /* variation input */;

        // Act
        $result = $this->subject->{method}($input);

        // Assert
        static::assertSame($expectedVariation, $result);
    }

    // 3. CONFIGURATION
    #[TestDox('skips processing when config disabled')]
    public function test{Method}WhenConfigDisabledSkipsProcessing(): void
    {
        // Arrange - configure disabled state
        // IMPORTANT: satisfy all other guard clauses so only the config guard can fire
        $this->configService = new StaticSystemConfigService([
            'config.key' => false,
        ]);
        $this->subject = new {TargetClass}($this->configService);

        // Act
        $result = $this->subject->{method}($input);

        // Assert
        static::assertNull($result);
    }

    // 4. EDGE CASES
    #[TestDox('returns empty result for empty input')]
    public function test{Method}WithEmptyInputReturnsEmpty(): void
    {
        // Arrange
        $input = [];

        // Act
        $result = $this->subject->{method}($input);

        // Assert
        static::assertSame([], $result);
    }

    #[TestDox('returns default value for null input')]
    public function test{Method}WithNullReturnsDefault(): void
    {
        // Act
        $result = $this->subject->{method}(null);

        // Assert
        static::assertSame($defaultValue, $result);
    }

    // 5. ERROR CASES
    #[TestDox('throws exception for invalid input')]
    public function test{Method}ThrowsOn{Condition}(): void
    {
        // Arrange
        $invalidInput = /* invalid input */;

        // PRIMARY: use expectExceptionObject() for Shopware factory exceptions
        // $this->expectExceptionObject({Exception}::factoryMethod($invalidInput));

        // FALLBACK: if no factory method, include message (never use expectException alone)
        $this->expectException({Exception}::class);
        $this->expectExceptionMessage('Expected message');  // REQUIRED — never omit

        // Act - throwing call LAST
        $this->subject->{method}($invalidInput);
    }

    #[TestDox('throws exception when dependency fails')]
    public function test{Method}ThrowsWhenDependencyFails(): void
    {
        // Arrange - configure dependency to fail
        $this->dependency
            ->method('doSomething')
            ->willThrowException(new \RuntimeException('Dependency failed'));

        $this->expectException({Exception}::class);
        $this->expectExceptionMessage('Expected message');  // Always include message

        // Act
        $this->subject->{method}($input);
    }
}
```

## With SystemConfigService

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Test\Stub\SystemConfigService\StaticSystemConfigService;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    public static function configProvider(): iterable
    {
        yield 'feature enabled returns enabled value' => [
            ['feature.enabled' => true],
            'expected when enabled',
        ];
        yield 'feature disabled returns disabled value' => [
            ['feature.enabled' => false],
            'expected when disabled',
        ];
        yield 'missing config uses default fallback' => [
            [],
            'default value',
        ];
    }

    #[DataProvider('configProvider')]
    #[TestDox('returns $expected based on configuration')]
    public function testReturnsBasedOnConfig(array $config, string $expected): void
    {
        $configService = new StaticSystemConfigService($config);
        $subject = new {TargetClass}($configService);

        $result = $subject->getValue();

        static::assertSame($expected, $result);
    }
}
```

## With HTTP Client Mock

HTTP clients are external dependencies — mocking with `expects()` is appropriate here because the HTTP call IS the side effect being verified.

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\MockObject\Stub;
use PHPUnit\Framework\TestCase;
use Symfony\Contracts\HttpClient\HttpClientInterface;
use Symfony\Contracts\HttpClient\ResponseInterface;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // HttpClientInterface: use MockObject because we verify the request IS made (side effect)
    private HttpClientInterface&MockObject $httpClient;
    private {TargetClass} $subject;

    protected function setUp(): void
    {
        $this->httpClient = $this->createMock(HttpClientInterface::class);
        $this->subject = new {TargetClass}($this->httpClient);
    }

    #[TestDox('fetches data from external API and returns parsed response')]
    public function testFetchDataReturnsResponse(): void
    {
        // ResponseInterface: use Stub — we only need it to return a value
        $response = $this->createStub(ResponseInterface::class);
        $response->method('toArray')->willReturn(['data' => 'value']);

        // expects(once()) justified: HTTP request is a side effect, not verified by return value alone
        $this->httpClient
            ->expects($this->once())
            ->method('request')
            ->with('GET', 'https://api.example.com/endpoint')
            ->willReturn($response);

        $result = $this->subject->fetchData();

        static::assertSame(['data' => 'value'], $result);
    }
}
```
