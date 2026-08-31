#!/usr/bin/env bats
# bats file_tags=test-writing,surviving-tests
# Tests for assert_surviving_tests: what a test class contains once a set of
# deletions is applied (lib/survival.sh in the test-rules MCP server).
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/mcp.log"
    export MCP_LOG_FILE
    log() { printf '[%s] %s\n' "$1" "$2" >> "${MCP_LOG_FILE}"; }
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    export PROJECT_ROOT
    mkdir -p "${PROJECT_ROOT}/tests/unit"
    # A `jq` shadow that fails only the invocation whose argument list holds
    # this exact word, so each of the tool's jq status checks is reachable from
    # a test. Empty (the default) passes everything through. Test helpers call
    # `command jq` so fixture construction is never affected.
    _JQ_FAIL_ON=""
    jq() {
        local arg
        for arg in "$@"; do
            if [[ -n "${_JQ_FAIL_ON}" ]] && [[ "${arg}" == "${_JQ_FAIL_ON}" ]]; then
                return 3
            fi
        done
        command jq "$@"
    }
    source "${TEST_RULES_LIB_DIR}/survival.sh"
}

# Write a PHP fixture from stdin and echo the PROJECT_ROOT-relative path the
# tool is called with.
# Args: $1 = file name (must match the declared class, PSR-4 style)
_fixture() {
    cat > "${PROJECT_ROOT}/tests/unit/$1"
    printf '%s' "tests/unit/$1"
}

# Build the tool's arguments object.
# Args: $1 = test_path, $2 = deleted_methods as a JSON value
_args() {
    command jq -nc --arg p "$1" --argjson d "$2" '{test_path: $p, deleted_methods: $d}'
}

# Assert one field of the tool's JSON result.
# Args: $1 = field name, $2 = expected value (jq -r rendering)
_assert_field() {
    local actual
    actual=$(printf '%s' "${output}" | command jq -r --arg f "$1" '.[$f]')
    assert_equal "${actual}" "$2"
}

# Assert one field of the tool's JSON result carries a substring.
# Args: $1 = field name, $2 = expected substring
_assert_field_contains() {
    local actual
    actual=$(printf '%s' "${output}" | command jq -r --arg f "$1" '.[$f]')
    if [[ "${actual}" != *"$2"* ]]; then
        fail "field $1: expected to contain '$2', got '${actual}'"
    fi
}

# A three-test class used by the cases about counting and deletion.
_write_cart_test() {
    _fixture 'CartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Checkout;

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

#[CoversClass(Cart::class)]
class CartTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }

    public function testRemovesLineItem(): void
    {
        static::assertTrue(true);
    }

    public function testCalculatesTotal(): void
    {
        static::assertTrue(true);
    }
}
PHP
}

# ============================================================================
# Counting and status
# ============================================================================

@test "an empty deleted_methods reports every test method as surviving" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    assert_output '{"test_path":"tests/unit/CartTest.php","total":3,"deleted":0,"surviving":3,"status":"OK"}'
}

@test "deleting every test method reports EMPTY" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem","testRemovesLineItem","testCalculatesTotal"]')"
    assert_success
    _assert_field surviving 0
    _assert_field status EMPTY
}

@test "deleting a proper subset reports the remaining test methods" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem"]')"
    assert_success
    _assert_field deleted 1
    _assert_field surviving 2
    _assert_field status OK
}

@test "a test method carrying #[DataProvider] is counted" {
    local path
    path=$(_fixture 'ProviderTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class ProviderTest extends TestCase
{
    #[DataProvider('roundingProvider')]
    public function testRoundsAmount(float $given, float $expected): void
    {
        static::assertSame($expected, $given);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a data provider method is not counted as a test" {
    local path
    path=$(_fixture 'ProviderTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class ProviderTest extends TestCase
{
    #[DataProvider('roundingProvider')]
    public function testRoundsAmount(float $given, float $expected): void
    {
        static::assertSame($expected, $given);
    }

    public static function roundingProvider(): iterable
    {
        yield 'rounds up' => [1.005, 1.01];
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a private method named test is not counted" {
    local path
    path=$(_fixture 'PrivateTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class PrivateTest extends TestCase
{
    public function testPublishesOrder(): void
    {
        static::assertTrue(true);
    }

    private function testHelperIsNotATest(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a static method named test is not counted" {
    local path
    path=$(_fixture 'StaticTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class StaticTest extends TestCase
{
    public function testPublishesOrder(): void
    {
        static::assertTrue(true);
    }

    public static function testStaticIsNotATest(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a method carrying #[Test] without a test prefix is counted" {
    local path
    path=$(_fixture 'AttributeTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

class AttributeTest extends TestCase
{
    #[Test]
    public function publishesOrder(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a method whose attributes span several lines is counted" {
    local path
    path=$(_fixture 'MultilineTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;

class MultilineTest extends TestCase
{
    #[DataProvider(
        'roundingProvider'
    )]
    #[TestDox(
        'rounds the amount'
    )]
    #[Test]
    public function roundsAmount(float $given): void
    {
        static::assertIsFloat($given);
    }

    public static function roundingProvider(): iterable
    {
        yield 'rounds up' => [1.005];
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "a commented-out method is not counted" {
    local path
    path=$(_fixture 'CommentedTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class CommentedTest extends TestCase
{
    public function testPublishesOrder(): void
    {
        static::assertTrue(true);
    }

    // public function testCommentedOutSingleLine(): void
    // {
    //     static::assertTrue(true);
    // }

    /*
    public function testCommentedOutBlock(): void
    {
        static::assertTrue(true);
    }
    */

    /**
     * public function testCommentedOutDocblock(): void
     */
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
}

@test "deleting a non-test method leaves the surviving test count unchanged" {
    local path
    path=$(_fixture 'ProviderTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class ProviderTest extends TestCase
{
    #[DataProvider('roundingProvider')]
    public function testRoundsAmount(float $given, float $expected): void
    {
        static::assertSame($expected, $given);
    }

    public static function roundingProvider(): iterable
    {
        yield 'rounds up' => [1.005, 1.01];
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '["roundingProvider"]')"
    assert_success
    _assert_field deleted 0
    _assert_field surviving 1
    _assert_field status OK
}

# ============================================================================
# PHP constructs the line scan must not misread
# ============================================================================

@test "a quoted URL in an attribute argument does not swallow the attributes below it" {
    local path
    path=$(_fixture 'TestDoxUrlTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;

class TestDoxUrlTest extends TestCase
{
    #[TestDox('rounds as https://example.com/spec says')]
    #[Test]
    public function roundsAmount(): void
    {
        static::assertTrue(true);
    }

    public function testCalculatesTotal(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 2
    _assert_field status OK
}

@test "#[Test] is recognized as one member of a comma-separated attribute group" {
    local path
    path=$(_fixture 'GroupedAttributeTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;

class GroupedAttributeTest extends TestCase
{
    #[Test, TestDox('publishes the order')]
    public function publishesOrder(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
    _assert_field status OK
}

@test "#[TestWith] alone is not read as a #[Test] marker" {
    local path
    path=$(_fixture 'TestWithOnlyTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\Attributes\TestWith;
use PHPUnit\Framework\TestCase;

class TestWithOnlyTest extends TestCase
{
    #[TestWith([1])]
    public function acceptsValue(int $given): void
    {
        static::assertIsInt($given);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 0
    _assert_field status EMPTY
}

@test "a test method declared inside a nowdoc is not counted" {
    local path
    path=$(_fixture 'NowdocOnlyTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class NowdocOnlyTest extends TestCase
{
    private function snippet(): string
    {
        return <<<'PHP_SNIPPET'
            public function testFromTheNowdoc(): void
            {
                static::assertTrue(true);
            }
            PHP_SNIPPET;
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 0
    _assert_field status EMPTY
}

@test "a heredoc closes so test methods declared after it are still counted" {
    local path
    path=$(_fixture 'HeredocSurroundedTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class HeredocSurroundedTest extends TestCase
{
    public function testKeepsCounting(): void
    {
        static::assertSame('x', 'x');
    }

    private function snippet(string $marker): string
    {
        return <<<SQL
            SELECT public function testInterpolated(): void FROM t WHERE a = '$marker'
            SQL;
    }

    public function testStillCounted(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 2
    _assert_field status OK
}

@test "a string literal containing the word class does not truncate the method scan" {
    local path
    path=$(_fixture 'StringClassWordTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class StringClassWordTest extends TestCase
{
    public function testReportsClassLoaderMessage(): void
    {
        static::assertSame('Probably a class loader error occurred', 'Probably a class loader error occurred');
    }

    public function testStillCountedAfterTheStringLiteral(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 2
    _assert_field status OK
}

@test "a test function declared after the class closes is not counted" {
    local path
    path=$(_fixture 'StrayFunctionTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class StrayFunctionTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}

function testStrayNamespaceFunction(): void
{
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem"]')"
    assert_success
    _assert_field total 1
    _assert_field status EMPTY
}

@test "a test method declared inside an anonymous class in a test body is not counted" {
    local path
    path=$(_fixture 'AnonymousInnerTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class AnonymousInnerTest extends TestCase
{
    public function testBuildsAnonymousStub(): void
    {
        $stub = new class {
            public function testNotATestMethod(): void
            {
            }
        };

        static::assertNotNull($stub);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '["testBuildsAnonymousStub"]')"
    assert_success
    _assert_field total 1
    _assert_field status EMPTY
}

@test "a file whose braces do not balance is refused rather than counted" {
    local path
    path=$(_fixture 'UnbalancedBraceTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class UnbalancedBraceTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_failure
    assert_output --partial 'UnbalancedBraceTest.php'
    assert_output --partial 'brace'
}

# ============================================================================
# UNRESOLVED — the runnable set is not derivable from this file alone
# ============================================================================

@test "an abstract test class reports UNRESOLVED rather than EMPTY" {
    local path
    path=$(_fixture 'AbstractCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

abstract class AbstractCartTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
    _assert_field surviving null
}

@test "a class extending another test class reports UNRESOLVED" {
    local path
    path=$(_fixture 'ChildCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

class ChildCartTest extends AbstractCartTest
{
    public function testRemovesLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "a class extending a qualified TestCase from another namespace reports UNRESOLVED" {
    local path
    path=$(_fixture 'ForeignBaseTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

class ForeignBaseTest extends \Acme\TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "a class extending a bare TestCase imported from another namespace reports UNRESOLVED" {
    local path
    path=$(_fixture 'ImportedForeignBaseTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use Acme\TestCase;

class ImportedForeignBaseTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "a class extending a bare TestCase the file does not import reports UNRESOLVED" {
    local path
    path=$(_fixture 'UnimportedBaseTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

class UnimportedBaseTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "a class extending ShopwareTestCase under its Shopware import is counted" {
    local path
    path=$(_fixture 'ShopwareBaseTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use Shopware\Core\Test\ShopwareTestCase;

class ShopwareBaseTest extends ShopwareTestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field total 1
    _assert_field status OK
}

@test "an UNRESOLVED result names the condition that caused it" {
    local path
    path=$(_fixture 'AbstractCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

abstract class AbstractCartTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field_contains reason 'abstract'
}

@test "a class using a trait reports UNRESOLVED" {
    local path
    path=$(_fixture 'TraitCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour;

class TraitCartTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "an unmatched deleted_methods entry is not reported for an UNRESOLVED class" {
    local path
    path=$(_fixture 'ChildCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

class ChildCartTest extends AbstractCartTest
{
    public function testRemovesLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '["testInheritedFromParent"]')"
    assert_success
    _assert_field status UNRESOLVED
}

@test "a file declaring no class named after its basename is refused rather than reported as UNRESOLVED" {
    local path
    path=$(_fixture 'MisnamedTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class ActuallyNamedDifferentlyTest extends TestCase
{
    public function testPublishesOrder(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_failure
    assert_output --partial 'MisnamedTest.php'
    assert_output --partial 'MisnamedTest'
}

@test "a string literal left open at end of line is refused rather than reported as UNRESOLVED" {
    local path
    path=$(_fixture 'MultilineStringTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

class MultilineStringTest extends TestCase
{
    public function testBuildsMessage(): void
    {
        $message = "first line
second line";

        static::assertNotSame('', $message);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    assert_failure
    assert_output --partial 'MultilineStringTest.php'
    assert_output --partial 'not closed on line 11'
}

# ============================================================================
# Refusals
# ============================================================================

@test "a deleted_methods entry naming an absent method is refused by name" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem","testGhostMethod"]')"
    assert_failure
    assert_output --partial 'testGhostMethod'
    refute_output --partial 'testAddsLineItem'
}

@test "deleted_methods given as a string is refused with the received value" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '"testAddsLineItem"')"
    assert_failure
    assert_output --partial 'deleted_methods'
    assert_output --partial 'string'
    assert_output --partial 'testAddsLineItem'
}

@test "a non-string deleted_methods entry is refused with the received value" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem",7]')"
    assert_failure
    assert_output --partial 'deleted_methods'
    assert_output --partial '7'
}

@test "an empty deleted_methods entry is refused" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem",""]')"
    assert_failure
    assert_output --partial 'deleted_methods'
    assert_output --partial 'empty'
}

@test "a deleted_methods entry with a trailing newline is refused" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem\n"]')"
    assert_failure
    assert_output --partial 'deleted_methods'
    assert_output --partial 'testAddsLineItem\n'
}

@test "a deleted_methods entry beginning with a digit is refused by shape" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["123abc"]')"
    assert_failure
    assert_output --partial 'Invalid deleted_methods'
    assert_output --partial '123abc'
}

@test "a deleted_methods entry beginning with a digit is refused by shape on an unresolvable class" {
    local path
    path=$(_fixture 'AbstractCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

use PHPUnit\Framework\TestCase;

abstract class AbstractCartTest extends TestCase
{
    public function testAddsLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    run tool_assert_surviving_tests "$(_args "${path}" '["123abc"]')"
    assert_failure
    assert_output --partial 'Invalid deleted_methods'
    assert_output --partial '123abc'
}

@test "a deleted_methods entry with an embedded space is refused" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem extra"]')"
    assert_failure
    assert_output --partial 'deleted_methods'
    assert_output --partial 'testAddsLineItem extra'
}

@test "a duplicate deleted_methods entry is refused by name" {
    local path
    path=$(_write_cart_test)
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem","testAddsLineItem"]')"
    assert_failure
    assert_output --partial 'duplicate'
    assert_output --partial 'testAddsLineItem'
}

@test "a missing test_path is refused by name" {
    run tool_assert_surviving_tests '{"deleted_methods":[]}'
    assert_failure
    assert_output --partial 'test_path'
}

@test "a test_path that does not exist is refused by name" {
    run tool_assert_surviving_tests "$(_args 'tests/unit/AbsentTest.php' '[]')"
    assert_failure
    assert_output --partial 'tests/unit/AbsentTest.php'
}

@test "an unreadable test_path is refused by name" {
    local path
    path=$(_write_cart_test)
    chmod 000 "${PROJECT_ROOT}/${path}"
    run tool_assert_surviving_tests "$(_args "${path}" '[]')"
    chmod 644 "${PROJECT_ROOT}/${path}"
    assert_failure
    assert_output --partial 'tests/unit/CartTest.php'
}

@test "a failing deleted_methods read is refused even when the array is empty" {
    local path args
    path=$(_write_cart_test)
    args=$(_args "${path}" '[]')
    _JQ_FAIL_ON='.deleted_methods[]'
    run tool_assert_surviving_tests "${args}"
    assert_failure
    assert_output --partial 'deleted_methods'
}

@test "a failing result builder is refused by name rather than reported as no output" {
    local path args
    path=$(_write_cart_test)
    args=$(_args "${path}" '[]')
    _JQ_FAIL_ON='-n'
    run tool_assert_surviving_tests "${args}"
    assert_failure
    assert_output --partial 'could not build its result'
}

@test "a failing result builder on the UNRESOLVED path is refused rather than reported as success" {
    local path args
    path=$(_fixture 'ChildCartTest.php' <<'PHP'
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit;

class ChildCartTest extends AbstractCartTest
{
    public function testRemovesLineItem(): void
    {
        static::assertTrue(true);
    }
}
PHP
)
    args=$(_args "${path}" '[]')
    _JQ_FAIL_ON='-n'
    run tool_assert_surviving_tests "${args}"
    assert_failure
    assert_output --partial 'could not build its result'
}

# ============================================================================
# Working-directory independence
# ============================================================================

@test "decoy files in the working directory do not change the result" {
    local path decoys
    path=$(_write_cart_test)
    decoys="${BATS_TEST_TMPDIR}/decoys"
    mkdir -p "${decoys}"
    touch "${decoys}/testAddsLineItem" "${decoys}/testRemovesLineItem" \
        "${decoys}/CartTest.php" "${decoys}/*" "${decoys}/tests"

    cd "${decoys}"
    run tool_assert_surviving_tests "$(_args "${path}" '["testAddsLineItem"]')"
    assert_success
    assert_output '{"test_path":"tests/unit/CartTest.php","total":3,"deleted":1,"surviving":2,"status":"OK"}'
}
