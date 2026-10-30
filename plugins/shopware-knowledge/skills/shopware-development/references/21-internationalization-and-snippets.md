# Internationalization and Snippets

## Core Rules

- Keep storefront snippets, admin snippets, and entity translations explicit. Do not mix them into one vague "translations" bucket.
- Use snippets for UI text and translation associations for real entity content.
- Keep language-aware DAL logic aligned with the current context instead of assuming one fallback language or one storefront.
- On 6.7.3+, use base snippet files such as `messages.en.base.json` and keep country-specific files small and intentional.

Example patterns:

```text
Bad: hardcode storefront labels directly in Twig or JS because the first language is English.
Good: use a snippet key and keep the file structure aligned with the plugin's storefront or admin scope.
```

```text
Bad: treat translated entity content like generic customFields and ignore the active language chain.
Good: use proper translation associations and read them in the correct language-aware context.
```

## Storefront and Admin Snippets

- Keep snippet keys namespaced by plugin or feature.
- Do not duplicate the same text across storefront and administration files unless the scopes are truly separate.
- Validate filename and directory conventions when shipping the extension.
- When a translation key changes, update the code and snippet files together.
- **Database snippets win over files.** `SnippetService` merges snippets edited in the admin (Settings > Snippets, `snippet` table) over the file snippets with `array_replace_recursive`. When a changed file value doesn't show, check the `snippet` table for an override of that key in the active snippet set.
- **Regional locale fallback is verified in v6.7.15.1.** For `nl-BE`, `SnippetFileCollection::getSnippetFilesWithLocaleFallback()` loads `nl-NL` files first, then `nl-BE` files on top (the canonical locale is `<lang>-<LANG>`, except `en` → `en-GB`). Thus `nl-NL` files can cover missing `nl-BE` keys in that loader. Bare-language files load through the separate fallback-locale mechanism. Check the exact older target's loader rather than assuming a 6.7.10 minimum; where canonical fallback is absent, ship the regional file or a supported country-agnostic base layer (6.7.3+).

## Entity Translations

- Use translation associations for content that truly belongs to the entity and changes by language.
- Keep fallback behavior explicit when the current language lacks a value.
- Do not load or persist translated state with the wrong context and then assume storefront rendering will fix it.
- **A custom entity needs a system-language translation row.** Translated fields are read starting from the system-language row; a value stored only in another language is not returned. See `04-plugin-backend.md` → "Custom Translations Need A System-Language Row".
- **Custom fields can be per language.** On entities whose `customFields` is a `TranslatedField` (for example `promotion`, `product`, `category`, `cms_page`), a custom field saved in one admin content language is not set in another. For a behavioural flag (not text), decide how to read it: from the system language only, or "set in any language". Then make the admin show that rule.

## Validation and Release Checks

- For 6.7.3+ base-layer work, check filename conventions with `bin/console translation:lint-filenames` and use `bin/console translation:validate` where available. The upgrade guide records the rename from `snippets:validate` under 6.7.3. Confirm available commands on an older shop before prescribing them; do not infer a 6.7.11 minimum for the rename.
- Check storefront and admin snippet resolution separately when both surfaces changed.
- If the plugin supports 6.6 and 6.7, verify the filename strategy before bulk-renaming snippet files.

## Country-Agnostic Base Snippet Layer (6.7.3+)

Core snippet files renamed for the country-agnostic base layer:

- `en-GB.json` → `en.json`
- `messages.en-GB.base.json` → `messages.en.base.json`

Resolution is layered, not a universal locale-first list. In v6.7.15.1 `SnippetService::getStorefrontSnippets()` merges from lowest to highest precedence:

1. Configured fallback-locale files, when provided (including the country-agnostic layer where configured).
2. The translator's default `messages` catalogue.
3. Files for the active snippet-set locale. Within a regional lookup, canonical-locale files load before requested-locale files (`en-GB` before `en-US`, for example); bare-language files are handled separately by the fallback-locale mechanism.
4. Database overrides for the active snippet set.

Regional variants should hold only their delta snippets rather than duplicating a full base catalogue; counts depend on the release and language.

- Existing extensions do not need immediate changes; previous naming still resolves.
- For new 6.7.3+ base-layer extensions, prefer country-agnostic naming. Do not bulk-rename files needed by an explicitly supported older version without checking its loader.
- Ship only the diff for `en-US` vs `en`; do not duplicate translations.

Source: [country-agnostic layer ADR](https://developer.shopware.com/docs/resources/references/adr/2025-09-01-adding-a-country-agnostic-language-layer.html), [v6.7.15.1 SnippetService](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/Snippet/SnippetService.php), [locale file fallback](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/Snippet/Files/SnippetFileCollection.php).

## Snippet CLI (Target-Version Check)

- `bin/console translation:validate` — the current name. `snippets:validate` remains as a deprecated alias slated for removal in 6.8. `snippet:validate` (singular) is not a command; it only ever resolved through Symfony's namespace abbreviation and will stop working.
- `bin/console translation:list`
- `bin/console translation:install --locales it-IT,fr-FR` (interactive multi-select supported)
- `SnippetValidator` becomes `@internal` — do not extend.

Source: [v6.7.15.1 validation command and deprecated alias](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/Snippet/Command/ValidateSnippetsCommand.php), [upgrade guide rename](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md#country-agnostic-language-layer-is-now-implemented). Other commands above are present in the target version; verify their flags on older supported versions.

## Language Pack Sunset In 6.8

The Shopware Language Pack plugin is unsupported from 6.8. Migrate before the jump:

```bash
bin/console translation:install --locales it-IT,fr-FR
```

- Check the resulting languages under Settings → Languages and their sales-channel/domain assignment. In v6.7.15.1 `translation:install` creates missing languages and activates newly created ones by default (`--skip-activation` opts out); it does not simply ignore every inactive locale or require all languages to exist before installation. Existing language activation still needs checking.
- Repoint sales-channel domains from `LanguagePack en-US` snippet sets to `BASE en-US`; Language Pack ≥5.37.1 does this automatically.
- If FK constraint errors appear during removal, upgrade to Shopware ≥6.7.7.0 and Language Pack ≥5.37.1 first.

Source: [Language Pack migration guide](https://developer.shopware.com/docs/guides/upgrades-migrations/language-pack-migration.html), [v6.7.15.1 install options](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/Snippet/Command/InstallTranslationCommand.php), [language/snippet-set creation](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/Snippet/Service/TranslationLoader.php). Check the exact Shopware/Language Pack compatibility and domain remapping before uninstalling; the external plugin's version-specific migration is not proven by core alone.

## Theme Snippet Keys Required In 6.8

For theme configuration `label` and `helpText`, constructed snippet keys are required in 6.8:

```
sw-theme.<technicalName>.<tabName>.<blockName>.<sectionName>.<fieldName>.label
sw-theme.<technicalName>.<tabName>.<blockName>.<sectionName>.<fieldName>.helpText
```

- API `label` / `helpText` deprecated → `labelSnippetKey` / `helpTextSnippetKey`.
- `ThemeService::getThemeConfiguration()` deprecated → `ThemeConfigurationService::getPlainThemeConfiguration()`.

Full theme details in `17-accessibility-and-template-best-practices.md`.

Use kebab-case `technicalName` and `default` for unnamed tabs/blocks/sections. The 6.8 requirement is the documented migration contract, not verification of a later deployment.

Source: [v6.7.15.1 theme translation migration](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md#translation-labels-and-helptexts-for-themes).
