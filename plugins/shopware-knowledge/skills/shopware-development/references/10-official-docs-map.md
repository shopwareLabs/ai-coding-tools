# Official Docs Map

Index: research protocol, Shopware docs, storefront/accessibility, admin/apps, payments, operations, Symfony, extension surfaces, core anchors.

## Docs Research Protocol

- Treat rendered Shopware docs as navigation and starting evidence, not final behavior authority.
- For detailed research, prefer the Markdown source in `shopware/docs` and the matching source file in `shopware/shopware` or installed `vendor/shopware/*`.
- Try the page's verified Markdown URL (`.md`) or locate its source in `shopware/docs`; do not assume replacing `.html` always resolves. Verify paths before citing them.
- Verify behavior-sensitive guidance against matching core or vendor code before implementing or reporting a finding.
- For Symfony, check all relevant surfaces before concluding: component docs, framework or bundle integration docs, and reference/config docs.
- If separate research agents are explicitly allowed, scope each to one docs/source question and require source-code verification. If delegation is not available, do the same checks inline.

## Versioned Shopware Docs

- Shopware docs root: `https://developer.shopware.com/docs/`
- Archived 6.6 docs root: `https://developer.shopware.com/docs/v6.6/`
- Shopware docs Markdown source: `https://github.com/shopware/docs/tree/main/`
- Shopware core baseline: `https://github.com/shopware/shopware/tree/v6.7.15.1/` (select the project's matching tag, not a moving development branch)

When a 6.6 page is needed, start with the same path under `/docs/v6.6/` and confirm that the archived page exists.

## Plugin Fundamentals

- plugin base guide: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-base-guide`
- add custom service: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/add-custom-service.html`
- adjust service: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/adjusting-service.html`
- plugin lifecycle: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/plugin-lifecycle.html`
- database migrations: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/database-migrations.html`
- use plugin configuration: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/use-plugin-configuration.html`
- add custom CLI commands: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/add-custom-commands.html`

## Data, Cart, Cache, and Async

- DAL concept: `https://developer.shopware.com/docs/concepts/framework/data-abstraction-layer.html`
- cart concept: `https://developer.shopware.com/docs/concepts/commerce/checkout-concept/cart.html`
- add cart collector/processor: `https://developer.shopware.com/docs/guides/plugins/plugins/checkout/cart/add-cart-processor-collector.html`
- Store API guide index: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/store-api/`
- add Store API route: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/store-api/add-store-api-route.html`
- override existing Store API route: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/store-api/override-existing-route.html`
- cache concept: `https://developer.shopware.com/docs/guides/hosting/performance/caches.html`
- HTTP cache: `https://developer.shopware.com/docs/concepts/framework/http_cache.html`
- plugin caching guide: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/caching/`
- hosting caches: `https://developer.shopware.com/docs/guides/hosting/performance/caches.html`
- add caching to custom controller: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-caching-to-custom-controller.html`
- add dynamic content via AJAX calls: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-dynamic-content-via-ajax-calls.html`
- add data indexer: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/data-handling/add-data-indexer.html`
- message queue: `https://developer.shopware.com/docs/guides/hosting/infrastructure/message-queue.html`
- add message to queue: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/message-queue/add-message-to-queue.html`
- add message handler: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/message-queue/add-message-handler.html`
- add middleware: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/message-queue/add-middleware.html`
- add scheduled task: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/add-scheduled-task.html`

## Storefront and Themes

- customize templates: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/customize-templates.html`
- add custom JavaScript: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-custom-javascript.html`
- custom styling: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-custom-styling.html`
- using a modal window: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/using-a-modal-window.html`
- add cookie to manager: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-cookie-to-manager.html`
- reacting to cookie consent changes: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/reacting-to-cookie-consent-changes.html`
- reacting to javascript events: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/reacting-to-javascript-events.html`
- working with media and thumbnails: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/use-media-thumbnails.html`
- add SCSS variables: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/add-scss-variables.html`
- theme inheritance: `https://developer.shopware.com/docs/guides/plugins/themes/add-theme-inheritance.html`
- SEO guides: `https://developer.shopware.com/docs/guides/plugins/plugins/content/seo/`
- add custom SEO URL: `https://developer.shopware.com/docs/guides/plugins/plugins/content/seo/add-custom-seo-url.html`
- custom fields in storefront: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/using-custom-fields-storefront.html`

## Accessibility and U.S. Standards

- storefront accessibility: `https://developer.shopware.com/docs/guides/development/accessibility/storefront-accessibility.html`
- accessibility checklist: `https://developer.shopware.com/docs/guides/development/accessibility/accessibility-checklist.html`
- ADA web guidance: `https://www.ada.gov/resources/web-guidance/`
- ADA 2024 web rule: `https://www.ada.gov/resources/2024-03-08-web-rule/`
- WCAG 2.2: `https://www.w3.org/TR/WCAG22/`
- WAI-ARIA APG index: `https://www.w3.org/WAI/ARIA/apg/`
- dialog modal pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/`
- menu button pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/`
- tabs pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/tabs/`
- carousel pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/carousel/`
- disclosure pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/`
- combobox pattern: `https://www.w3.org/WAI/ARIA/apg/patterns/combobox/`
- Section 508 / ICT baseline: `https://www.access-board.gov/ict/`

## Administration and Apps

- administration guide index: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/`
- add custom module: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/module-component-management/add-custom-module.html`
- add ACL rules: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/permissions-error-handling/add-acl-rules.html`
- data handling: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/data-handling-processing/using-data-handling.html`
- using services: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/services-utilities/injecting-services.html`
- adding snippets: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/templates-styling/adding-snippets.html`
- Vue 3 upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/vue3.html`
- Pinia upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/pinia.html`
- Vite upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/vite.html`
- app administration: `https://developer.shopware.com/docs/guides/plugins/apps/administration/`
- add custom module to an app: `https://developer.shopware.com/docs/guides/plugins/apps/administration/add-custom-modules.html`

## Payments

- payment guide 6.7: `https://developer.shopware.com/docs/guides/plugins/plugins/checkout/payment/add-payment-plugin.html`
- payment guide 6.6: `https://developer.shopware.com/docs/v6.6/guides/plugins/plugins/checkout/payment/add-payment-plugin.html`
- payment concept: `https://developer.shopware.com/docs/concepts/commerce/checkout-concept/payments.html`

## Quality, Security, and Operations

- security reference: `https://developer.shopware.com/docs/resources/references/security.html`
- logging: `https://developer.shopware.com/docs/guides/hosting/configurations/observability/logging.html`
- PHPUnit guide: `https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit.html`
- PHP integration testing: `https://developer.shopware.com/docs/guides/development/testing/unit/php-unit.html`
- Shopware CLI: `https://developer.shopware.com/docs/products/cli/`
- Shopware CLI validation: `https://developer.shopware.com/docs/products/tools/cli/validation.html`
- add rate limiter to API route: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/rate-limiter/add-rate-limiter-to-api-route.html`
- quality guidelines for store extensions: `https://developer.shopware.com/docs/resources/guidelines/testing/store/quality-guidelines-plugins/`
- store review errors: `https://developer.shopware.com/docs/guides/development/monetization/store-review-errors.html`
- translation extension upgrade: `https://developer.shopware.com/docs/resources/references/upgrades/core/translation/extension-translation.html`
- fallback language selection: `https://developer.shopware.com/docs/concepts/framework/translations/fallback-language-selection.html`
- snippets concept: `https://developer.shopware.com/docs/concepts/translations/`

## Symfony

Select the installed Symfony major/minor in the documentation version selector. `current` may describe APIs unavailable to a 6.6/6.7 project. Check the component guide, FrameworkBundle integration, and configuration reference; none alone establishes the full Shopware wiring contract.

- best practices: `https://symfony.com/doc/current/best_practices.html`
- service container: `https://symfony.com/doc/current/service_container.html`
- HttpClient: `https://symfony.com/doc/current/http_client.html`
- Messenger: `https://symfony.com/doc/current/messenger.html`
- logging: `https://symfony.com/doc/current/logging.html`
- configuration reference: `https://symfony.com/doc/current/reference/configuration/framework.html`

## Extension Surfaces

- add custom flow trigger: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/flow/add-flow-builder-trigger.html`
- add CMS element: `https://developer.shopware.com/docs/guides/plugins/plugins/content/cms/add-cms-element.html`
- add custom rules: `https://developer.shopware.com/docs/guides/plugins/plugins/framework/rule/add-custom-rules.html`

## Core Source Anchors

Use matching Shopware core when the official docs are thin or a behavior is version-sensitive:

- cart processing order: `src/Core/Checkout/Cart/Processor.php`
- cart collector interface: `src/Core/Checkout/Cart/CartDataCollectorInterface.php`
- cart processor interface: `src/Core/Checkout/Cart/CartProcessorInterface.php`
- cacheable storefront controller example: `src/Storefront/Controller/ProductController.php`
- Shopware integration test traits: `src/Core/Framework/Test/TestCaseBase/`
- repository mocking ADR: `adr/2023-04-01-mocking-repositories.md`
- entity indexer base class: `src/Core/Framework/DataAbstractionLayer/Indexing/EntityIndexer.php`
- iterator factory: `src/Core/Framework/DataAbstractionLayer/Dbal/Common/IteratorFactory.php`
- storefront plugin manager: `src/Storefront/Resources/app/storefront/src/plugin-system/plugin.manager.js`
- cookie configuration plugin: `src/Storefront/Resources/app/storefront/src/plugin/cookie/cookie-configuration.plugin.js`
- static cookie storage helper: `src/Storefront/Resources/app/storefront/src/helper/storage/cookie-storage.helper.js`
- cart widget DOM replacement: `src/Storefront/Resources/app/storefront/src/plugin/header/cart-widget.plugin.js`
- payment entry points: `src/Core/Checkout/Payment/PaymentProcessor.php`
- HTTP cache response policy: `src/Core/Framework/Adapter/Cache/Http/CacheResponseSubscriber.php`
- cache variation headers: `src/Core/Framework/Adapter/Cache/Http/HttpCacheVariantHeaders.php`
- cache cookie/hash handling: `src/Core/Framework/Adapter/Cache/Http/CacheHeadersService.php`
- delayed invalidation schedule: `src/Core/Framework/Adapter/Cache/InvalidateCacheTask.php`
- plugin migration execution: `src/Core/Framework/Plugin/PluginLifecycleService.php`
- targeted index API: `src/Core/Framework/Api/Controller/CacheController.php`
- full index message API: `src/Core/Framework/Api/Controller/IndexingController.php`
- Messenger delay restriction: `src/Core/DevOps/StaticAnalyze/PHPStan/Rules/NoDelayStampRule.php`
- Elasticsearch product definition: `src/Elasticsearch/Product/ElasticsearchProductDefinition.php`
- OpenSearch admin search ADR: `adr/2026-01-28-apply-opensearch-in-admin-api.md`
