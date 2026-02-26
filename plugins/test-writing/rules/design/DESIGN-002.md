---
id: DESIGN-002
title: Single Behavior Per Test
group: design
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Single Behavior Per Test

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Each test method MUST test exactly one behavior.

### Violation Signs

- Method name contains "And"
- Comment sections separating test parts
- Multiple unrelated assertions
- Testing create, update, and delete in one method

### Detection

```php
// INCORRECT - multiple behaviors
public function testUserManagement(): void
{
    // creation
    $user = $this->createUser();
    static::assertNotNull($user->getId());

    // update
    $user->setName('NewName');
    $this->repo->update($user);
    static::assertEquals('NewName', $user->getName());

    // deletion
    $this->repo->delete($user);
    static::assertNull($this->repo->find($user->getId()));
}
```

### Fix — Split Methods

```php
public function testCreatesUserWithValidData(): void
{
    $user = $this->createUser();
    static::assertNotNull($user->getId());
}

public function testUpdatesUserName(): void
{
    $user = $this->createUser();
    $user->setName('NewName');
    $this->repo->update($user);
    static::assertEquals('NewName', $user->getName());
}

public function testDeletesUser(): void
{
    $user = $this->createUser();
    $this->repo->delete($user);
    static::assertNull($this->repo->find($user->getId()));
}
```
