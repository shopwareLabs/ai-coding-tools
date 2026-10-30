# Should-Trigger Prompts

Exploratory discovery prompts for fresh Claude Code and Codex sessions. Record actual skill-loading traces; these prompts alone are not a measured trigger rate. Use cases.json and run.py for source-backed behavior evaluation. A correct answer without a load trace does not prove automatic invocation.

## Plugin work

1. Review my Shopware plugin for P0/P1 security issues.
2. Audit this Shopware plugin end-to-end with the 3-pass protocol.
3. Fix a broken cart processor in my Shopware plugin.
4. Migrate my Shopware plugin from 6.6 to 6.7.
5. Add a new Store API route to my Shopware plugin.

## Payments

6. Add a payment handler for a new PSP in Shopware 6.7.
7. Debug a webhook signature failure on my Shopware payment plugin.
8. Convert my Shopware payment handler from `AsyncPaymentHandlerInterface` to `AbstractPaymentHandler`.
9. Why does my Shopware payment plugin create duplicate orders?

## Cart and checkout

10. Fix a cart processor that is causing wrong tax totals in Shopware.
11. Add a shipping-cost collector to my Shopware plugin.
12. Explain how `CartBehavior::isRecalculation` maps to `CheckoutPermissions` in 6.7.
13. Cache TaxJar responses in my Shopware cart to stop 500ms recalcs.

## Cache and HTTP cache

14. Why is my Shopware admin save not showing up in the storefront for 5 minutes?
15. Debug Shopware cache invalidation on a Varnish-backed shop.
16. Explain `sw-cache-hash` and `CACHE_REWORK` in Shopware 6.7.
17. How do I use `sw-force-cache-invalidate` in Shopware?

## Storefront and themes

18. Extend a Shopware Twig template using `sw_extends`.
19. My Shopware storefront JS is not updating focus after a modal closes.
20. Migrate my Shopware admin plugin from Vuex to Pinia.
21. Replace `controllerName` with `activeRoute` in a Shopware theme.

## Admin and apps

22. Convert my Shopware admin `sw-button` usages to `mt-button`.
23. Set up a Shopware app manifest with least-privilege webhook subscriptions.
24. Register an MCP tool on Shopware 6.7.

## i18n

25. Migrate my Shopware plugin snippets to the country-agnostic base file layout for 6.7.3.
26. Prepare my Shopware project for Language Pack sunset in 6.8.

## Plugin lifecycle

31. Why didn't my custom field installer run after deploying?
32. Do I need a version bump for this Shopware plugin change to take effect?
33. What does `updateDestructive()` actually do in a Shopware plugin?
34. My Shopware migration works on a fresh install but not on existing shops.
35. What order should plugin refresh, update, and activate run in on deploy?

## CMS

39. Add a custom CMS element with a data resolver to my Shopware theme.
40. My Shopware CMS block shows slider arrows locally but not on staging.
41. Add per-page inheritance to my Shopware CMS element config fields.

## Conceptual — no file open

These must trigger with an empty working directory. They are what the removed `paths` field was suppressing.

36. How do I add a payment handler in Shopware 6.7?
37. Explain Shopware delayed cache invalidation.
38. What changed for plugins between Shopware 6.6 and 6.7?

## Ops and tooling

27. Set up PHPStan for a Shopware 6.7 plugin.
28. Patch a Shopware core bug with `composer-patches`.
29. Disable Shopware `usage_data.collection_enabled` on a large catalog.
30. Configure Shopware Messenger with a `webhook` transport.

## Local environment

43. Start my Shopware project locally with `shopware-cli project dev`.
44. Migrate my Shopware project from devenv to shopware-cli and Docker.
45. Why does my local Shopware storefront show no products after an import?
46. Disable OpenSearch in my local Shopware Docker environment.
