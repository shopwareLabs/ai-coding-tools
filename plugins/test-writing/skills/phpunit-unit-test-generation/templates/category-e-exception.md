# Category E: Exception Test Template

## Contents
- [When to Use](#when-to-use)
- [Exception Class Template](#exception-class-template)
- [Exception with Factory Methods Template](#exception-with-factory-methods-template)
- [Testing Exception Throwing in Services](#testing-exception-throwing-in-services)
- [Validation Exception Testing](#validation-exception-testing)
- [HTTP Exception Response Testing](#http-exception-response-testing)

---

## When to Use

Use for classes that:
- Extend `ShopwareHttpException` or other exception classes
- Have static factory methods for creating exceptions
- Contain error codes and messages
- Handle error scenarios

**IMPORTANT**: Exception expectations MUST be set BEFORE the throwing call.

## Exception Class Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Symfony\Component\HttpFoundation\Response;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // 1. HAPPY PATH (error code and status verification)
    #[TestDox('returns correct error code')]
    public function testGetErrorCodeReturnsCorrectCode(): void
    {
        $exception = new {TargetClass}('Test message');

        static::assertSame('{MODULE}_{ERROR_CODE}', $exception->getErrorCode());
    }

    #[TestDox('returns correct HTTP status code')]
    public function testGetStatusCodeReturnsCorrectHttpStatus(): void
    {
        $exception = new {TargetClass}('Test message');

        static::assertSame(Response::HTTP_BAD_REQUEST, $exception->getStatusCode());
    }

    // 2. VARIATIONS
    #[TestDox('includes provided text in error message')]
    public function testMessageContainsProvidedText(): void
    {
        $exception = new {TargetClass}('Custom error message');

        static::assertStringContainsString('Custom error message', $exception->getMessage());
    }

    #[TestDox('exposes parameters for error formatting')]
    public function testGetParametersReturnsExpectedData(): void
    {
        $exception = new {TargetClass}('Message with {{ param }}', ['param' => 'value']);

        $parameters = $exception->getParameters();

        static::assertArrayHasKey('param', $parameters);
        static::assertSame('value', $parameters['param']);
    }
}
```

## Exception with Factory Methods Template

Test factory methods using `expectExceptionObject()` when the exception is thrown, and direct instantiation + full assertion when verifying the exception object itself.

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Symfony\Component\HttpFoundation\Response;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // 1. HAPPY PATH - Factory method behavior (assert all three: code + status + message)
    #[TestDox('notFound factory creates exception with correct error code, status, and message')]
    public function testNotFoundReturnsCorrectException(): void
    {
        $exception = {TargetClass}::notFound('entity-id');

        static::assertSame('{MODULE}_NOT_FOUND', $exception->getErrorCode());
        static::assertSame(Response::HTTP_NOT_FOUND, $exception->getStatusCode());
        static::assertStringContainsString('entity-id', $exception->getMessage());
    }

    #[TestDox('invalidInput factory creates exception with field and reason in message')]
    public function testInvalidInputReturnsCorrectException(): void
    {
        $exception = {TargetClass}::invalidInput('field-name', 'must not be empty');

        static::assertSame('{MODULE}_INVALID_INPUT', $exception->getErrorCode());
        static::assertSame(Response::HTTP_BAD_REQUEST, $exception->getStatusCode());
        static::assertStringContainsString('field-name', $exception->getMessage());
        static::assertStringContainsString('must not be empty', $exception->getMessage());
    }

    #[TestDox('unauthorized factory creates exception with correct status and error code')]
    public function testUnauthorizedReturnsCorrectException(): void
    {
        $exception = {TargetClass}::unauthorized();

        static::assertSame('{MODULE}_UNAUTHORIZED', $exception->getErrorCode());
        static::assertSame(Response::HTTP_UNAUTHORIZED, $exception->getStatusCode());
    }

    // 2. VARIATIONS - Parameter accessibility
    #[TestDox('factory method exposes parameters via getParameters')]
    public function testFactoryMethodParametersAreAccessible(): void
    {
        $exception = {TargetClass}::notFound('entity-id');

        $parameters = $exception->getParameters();

        static::assertArrayHasKey('id', $parameters);
        static::assertSame('entity-id', $parameters['id']);
    }
}
```

## Testing Exception Throwing in Services

Exception expectations MUST be set BEFORE the throwing call. **Never use `expectException()` alone without message, code, or object** — this is E018.

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{ServiceClass};
use Shopware\Core\{Module}\{Submodule}\{ExceptionClass};

#[CoversClass({ServiceClass}::class)]
class {ServiceClass}Test extends TestCase
{
    // PRIMARY PATTERN: expectExceptionObject for Shopware factory exceptions
    // Verifies type + message + parameters in a single call
    #[TestDox('throws notFound exception with entity ID when entity is missing')]
    public function testThrowsNotFoundExceptionWithId(): void
    {
        $this->expectExceptionObject({ExceptionClass}::notFound('entity-id'));

        $this->service->find('entity-id');
    }

    // FALLBACK PATTERN: expectException + expectExceptionMessage (when no factory method)
    // Never use expectException() alone — always include message
    #[TestDox('throws exception when entity not found')]
    public function testThrowsWhenNotFound(): void
    {
        // Set expectations BEFORE the throwing call — include message (E018 if missing)
        $this->expectException({ExceptionClass}::class);
        $this->expectExceptionMessage('Entity with id "non-existent" was not found');

        // Act - throwing call LAST
        $this->service->find('non-existent');
    }

    // DATA PROVIDER PATTERN: multiple exception scenarios using expectExceptionObject
    public static function exceptionProvider(): iterable
    {
        yield 'empty input triggers empty validation' => [
            'input' => [],
            'exception' => {ExceptionClass}::emptyInput(),
        ];
        yield 'malformed data triggers format validation' => [
            'input' => ['data' => 'invalid'],
            'exception' => {ExceptionClass}::invalidFormat('data'),
        ];
        yield 'missing required field triggers field validation' => [
            'input' => ['optional' => 'value'],
            'exception' => {ExceptionClass}::missingField('required'),
        ];
    }

    #[DataProvider('exceptionProvider')]
    #[TestDox('throws correct exception for invalid input')]
    public function testThrowsCorrectException(array $input, \Throwable $exception): void
    {
        $this->expectExceptionObject($exception);

        $this->service->process($input);
    }
}
```

## Validation Exception Testing

```php
#[TestDox('validation exception contains constraint violations')]
public function testValidationExceptionContainsViolations(): void
{
    try {
        $this->validator->validate(['name' => '']);
        static::fail('Expected validation exception');
    } catch (ConstraintViolationException $e) {
        $violations = $e->getViolations();

        static::assertCount(1, $violations);
        static::assertSame('/name', $violations[0]->getPropertyPath());
        static::assertSame('This value should not be blank.', $violations[0]->getMessage());
    }
}
```

## HTTP Exception Response Testing

```php
#[TestDox('exception serializes to JSON API error format')]
public function testExceptionSerializesToCorrectJsonStructure(): void
{
    $exception = {TargetClass}::notFound('entity-id');

    $errors = $exception->getErrors();
    $error = iterator_to_array($errors)[0];

    static::assertSame('{MODULE}_NOT_FOUND', $error['code']);
    static::assertSame('404', $error['status']);
    static::assertArrayHasKey('detail', $error);
}
```
