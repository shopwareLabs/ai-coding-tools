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
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
// Import Shopware stubs: StaticSystemConfigService, StaticEntityRepository

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    private {TargetClass} $subject;
    // Declare stub/mock properties for dependencies

    protected function setUp(): void
    {
        // Initialize stubs (prefer Shopware stubs over mocks)
        // $this->configService = new StaticSystemConfigService([...]);

        // Initialize mocks for external dependencies only
        // $this->httpClient = $this->createMock(HttpClientInterface::class);

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

        // Set expectations BEFORE the throwing call
        $this->expectException({Exception}::class);
        $this->expectExceptionMessage('Expected message');

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

HTTP clients are external dependencies - mocking is appropriate here.

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Symfony\Contracts\HttpClient\HttpClientInterface;
use Symfony\Contracts\HttpClient\ResponseInterface;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // Intersection types for type-safe mock declarations (PHP 8.1+)
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
        $response = $this->createMock(ResponseInterface::class);
        $response->method('toArray')->willReturn(['data' => 'value']);

        $this->httpClient
            ->expects(static::once())
            ->method('request')
            ->with('GET', 'https://api.example.com/endpoint')
            ->willReturn($response);

        $result = $this->subject->fetchData();

        static::assertSame(['data' => 'value'], $result);
    }
}
```
