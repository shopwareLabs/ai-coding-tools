---
id: DESIGN-010
title: Guard Clause Isolation in Arrange
group: design
enforce: should-fix
test-types: unit
test-categories: B,C,D
scope: general
---

## Guard Clause Isolation in Arrange

**Scope**: B,C,D | **Enforce**: Should fix

When testing one early-return condition in a method with multiple sequential guards, the arrange section MUST satisfy all other guards so there is only one possible exit path.

Without this, the test may pass because the method exits at a different guard clause than the one the test name implies. The outcome looks correct (e.g., "nothing happens"), but the test proves nothing about the intended condition.

### Detection Algorithm

Requires source class (from `#[CoversClass]`):

1. Read the source method exercised by the test
2. Identify sequential early-return conditions (guard clauses)
3. If the method has 2+ guards AND the test name/behavior targets a specific guard:
   a. Check whether the arrange section provides inputs that would pass all other guards
   b. If any prior or subsequent guard would also cause an early return with the current arrange, flag it

### Detection

```php
// Source method has two guards:
//   Guard 1: if (!$googleRecaptchaActive) { return; }
//   Guard 2: if (!$requiredCookieGroup || !$requiredCookieGroup->isRequired) { return; }

// INCORRECT — tests guard 1, but guard 2 would also fire (isRequired defaults to false)
public function testCaptchaConfigNotActive(): void
{
    $this->systemConfigService->set('captcha.active', false);

    $cookieGroup = new CookieGroup('required');
    // isRequired not set → guard 2 would also return early
    $event = new CookieGroupCollectEvent(new CookieGroupCollection([$cookieGroup]), ...);

    $this->listener->__invoke($event);

    static::assertNull($event->cookieGroupCollection->get('required')?->getEntries()?->get('_GRECAPTCHA'));
}
```

### Fix

Satisfy all guards except the one under test:

```php
// CORRECT — guard 2 would pass, so only guard 1 can cause the early return
public function testCaptchaConfigNotActive(): void
{
    $this->systemConfigService->set('captcha.active', false);

    $cookieGroup = new CookieGroup('required');
    $cookieGroup->isRequired = true;  // satisfies guard 2
    $event = new CookieGroupCollectEvent(new CookieGroupCollection([$cookieGroup]), ...);

    $this->listener->__invoke($event);

    static::assertNull($event->cookieGroupCollection->get('required')?->getEntries()?->get('_GRECAPTCHA'));
}
```

### When This Rule Does NOT Apply

- Method has only one guard clause — no ambiguity possible
- Test explicitly tests the "all guards fail" path (e.g., completely empty input)
- Guards produce distinguishable outcomes (e.g., one throws, another returns null — the test assertion would fail if the wrong guard fired)
- Category A (DTO) tests — simple objects rarely have multi-guard methods
