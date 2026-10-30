# Messenger Handlers

Contents: [routing](#routing-and-message-shape), [idempotency](#durable-and-concurrent-idempotency), [compatibility](#scheduled-task-and-message-size-compatibility), [webhook transport](#webhook-messenger-transport-webhooks_rework).

## Routing and Message Shape

- Use explicit message classes plus idempotent handlers for async work. Persist dedupe or state-transition guards before dispatch when duplicates would hurt.
- Prefer separate transports for checkout-sensitive async work and low-priority bulk work.
- On Shopware, move non-urgent work to `low_priority` via `LowPriorityMessageInterface` or `shopware.messenger.routing_overwrite` instead of letting it compete with checkout-adjacent async work.
- Do not use Symfony `DelayStamp` as a portable Shopware default because it is not compatible with every supported Messenger transport. Prefer a scheduled task or persisted due-time queue when delayed execution is required; use transport-specific delay only after the project proves support.
- Keep handler side effects bounded. Re-read fresh state inside the handler instead of serializing whole entities into the message.

```php
// Preferred: mark clearly non-urgent work as low priority
final class RebuildPartnerSnapshotMessage implements LowPriorityMessageInterface
{
    public function __construct(private readonly string $customerId)
    {
    }
}
```

```php
// Bad: serializing mutable entities or large payloads into the message
$this->messageBus->dispatch(new SyncPartnerOrderMessage($orderEntity, $request->request->all()));
```

## Durable and Concurrent Idempotency

A read such as `alreadyProcessed($orderId)` followed by `syncOrder()` is not a concurrency guard: two workers can pass the check. Recording success afterwards also leaves a crash window after provider acceptance. A queue acknowledgement, state-machine lock, or request-local boolean does not close either window.

Use a stable business-operation key, such as shop/provider account + order ID + operation + persisted export revision. Retries and duplicate dispatches of that revision must reuse the key and immutable payload; a genuinely new export revision gets a new key. Do not generate a new random key on each dispatch.

The following is an application-service contract, not a built-in Shopware API. `OperationStore` must implement a unique DB constraint on `business_key`, atomic claim/compare-and-set with a durable lease, a persisted payload fingerprint, and a completion record including the provider reference. Busy claims must be retried (not silently acknowledged); expired claims enter recovery with the same key. Lease renewal/fencing protects completion from a superseded worker.

```php
#[AsMessageHandler(fromTransport: 'low_priority')]
final class SyncPartnerOrderHandler
{
    public function __construct(
        private readonly OperationStore $operations,
        private readonly PartnerSyncService $partnerSyncService,
    ) {
    }

    public function __invoke(SyncPartnerOrderMessage $message): void
    {
        $operation = $this->operations->load($message->operationId);
        if ($operation->isCompleted()) {
            return;
        }

        // Atomic claim rechecks completion; contention throws a retryable exception.
        $claim = $this->operations->claimOrRetry($operation->businessKey);
        if ($claim === null) {
            return; // Another worker durably completed it before the claim.
        }

        // Adapter forwards this stable key to the provider's idempotency mechanism.
        $result = $this->partnerSyncService->syncOrder(
            $claim->payload,
            idempotencyKey: $claim->businessKey,
        );
        $this->operations->completeIfOwner($claim, $result->providerReference);
    }
}
```

Persist the operation and an outbox/dispatch marker with the business write when losing the handoff would matter. Dispatch/recovery may repeat; the unique key is the authority. Do not hold an open DB transaction over the HTTP call.

If a timeout or crash follows remote acceptance, retain an unknown/recoverable state. Reconcile by the provider key/reference, or repeat only when its idempotency contract guarantees safety for the same payload and retention window. Without provider idempotency/status lookup, stop unsafe automatic replay and require reconciliation; a local lock cannot promise exactly-once remote effects. Test concurrent delivery, duplicate dispatch, provider timeout, crash after acceptance, and recovery after lease expiry.

## Scheduled Task and Message Size Compatibility

Since 6.7.0.0, `ScheduledTaskHandler` requires a non-nullable `Psr\Log\LoggerInterface` constructor argument (optional/nullable in 6.6). A subclass with its own constructor must inject it and pass it to `parent::__construct()`; container registration alone does not fix an outdated parent call. From 6.7.13, `markTaskRunning()`, `markTaskFailed()`, and `rescheduleTask()` hooks are deprecated; let the framework own bookkeeping.

Message-size enforcement is **opt-in and off by default**:

- `shopware.messenger.enforce_message_size` — `defaultFalse()`. The size listener returns early while this is false, so nothing is capped out of the box.
- `shopware.messenger.message_max_kib_size` — default `1024` KiB; applies only when enforcement is enabled. `0` disables.
- Design messages to reference DB rows instead of carrying blobs regardless of the setting. Do not raise the limit as a first response — small messages are the correct long-term pattern.

## Webhook Messenger Transport (`WEBHOOKS_REWORK`)

At 6.7.15.1, `WEBHOOKS_REWORK` is opt-in (`default: false`). With it enabled, outbound Shopware webhooks use a dedicated DB-backed transport and outbox-owned retry scheduling: 5s, 30s, 5min, 30min, 4h. This is not the authentication model for inbound provider callbacks.

- Consumers must include `webhook` in the transport list:
  ```bash
  bin/console messenger:consume webhook async low_priority
  ```
- If the admin worker is used, include `webhook` in `shopware.admin_worker.transports`; CLI workers remain the production path.
- Rollback path: `bin/console webhook:drain-to-async`. Check pending outbox work and the installed command behavior before disabling the flag.

## Source Anchors

- [Symfony 7.4 idempotent handlers](https://symfony.com/doc/7.4/messenger.html#writing-idempotent-handlers): duplicate delivery and stable business keys. The durable claim/provider seam above is an application design, not a core deduplication guarantee.
- [NoDelayStampRule](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/DevOps/StaticAnalyze/PHPStan/Rules/NoDelayStampRule.php), [queue configuration](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Resources/config/packages/shopware.yaml), and [message-size configuration](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/DependencyInjection/Configuration.php).
- [ScheduledTaskHandler 6.7.15.1](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/MessageQueue/ScheduledTask/ScheduledTaskHandler.php); compare the installed 6.6 patch before adapting constructor calls.
- [Feature defaults](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Resources/config/packages/feature.yaml), [RetryDelayCalculator](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Webhook/Outbox/RetryDelayCalculator.php), and [WebhookDrainToAsyncCommand](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Webhook/Command/WebhookDrainToAsyncCommand.php).

Return to [plugin backend](04-plugin-backend.md) for DAL, API, and lifecycle guidance.
