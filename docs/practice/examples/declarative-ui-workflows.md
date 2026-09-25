---
title: Declarative UI Workflows — playwright-bdd
description: High-altitude step definitions that delegate to Page Object Model methods, keeping Gherkin at business-domain altitude while hiding UI mechanics in POM classes.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-examples-decorators-readme-readme
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
---

# Declarative UI Workflows — playwright-bdd

A declarative step definition does one thing: it calls a method on a Page Object (or equivalent support class) and passes the result to an assertion. The step body should be one to three lines. All UI mechanics live in the POM.

## The altitude principle in practice

Imperative (avoid):
```gherkin
When I click the "Settings" link in the top navigation
And I scroll down to the "Notifications" section
And I toggle the "Email notifications" switch
And I click the "Save changes" button
```

Declarative (aim for this):
```gherkin
When I disable email notifications
```

The declarative version describes intent. How the UI achieves it is the POM's responsibility.

## Feature file

```gherkin
Feature: Account settings

  Background:
    Given I am signed in as a pro user

  Scenario: Disable email notifications
    When I disable email notifications
    Then my notification preferences show email as disabled

  Scenario: Change the display name
    When I update my display name to "Jane Smith"
    Then my profile shows the display name "Jane Smith"

  Scenario: Cancel account
    When I cancel my account
    Then I am redirected to the goodbye page
    And I receive an account cancellation email

  Scenario: Two-factor authentication setup
    When I enable two-factor authentication
    Then my security settings show 2FA as active
    And I am shown a QR code for my authenticator app
```

## Page Object Model

```typescript
// support/pages/settings-page.ts
import { type Page, expect } from '@playwright/test';

export class SettingsPage {
  constructor(private readonly page: Page) {}

  async goto(): Promise<void> {
    await this.page.goto('/settings');
    await expect(this.page.getByRole('heading', { name: 'Account Settings' })).toBeVisible();
  }

  async disableEmailNotifications(): Promise<void> {
    await this.page.getByRole('link', { name: 'Notifications' }).click();
    const toggle = this.page.getByRole('switch', { name: 'Email notifications' });
    if (await toggle.isChecked()) {
      await toggle.click();
    }
    await this.page.getByRole('button', { name: 'Save changes' }).click();
    await expect(this.page.getByText('Settings saved')).toBeVisible();
  }

  async getEmailNotificationStatus(): Promise<boolean> {
    await this.page.getByRole('link', { name: 'Notifications' }).click();
    return this.page.getByRole('switch', { name: 'Email notifications' }).isChecked();
  }

  async updateDisplayName(name: string): Promise<void> {
    await this.page.getByRole('link', { name: 'Profile' }).click();
    await this.page.getByLabel('Display name').fill(name);
    await this.page.getByRole('button', { name: 'Update profile' }).click();
    await expect(this.page.getByText('Profile updated')).toBeVisible();
  }

  async cancelAccount(): Promise<void> {
    await this.page.getByRole('link', { name: 'Danger zone' }).click();
    await this.page.getByRole('button', { name: 'Cancel account' }).click();
    await this.page.getByRole('button', { name: 'Yes, cancel my account' }).click();
  }

  async enableTwoFactor(): Promise<void> {
    await this.page.getByRole('link', { name: 'Security' }).click();
    await this.page.getByRole('button', { name: 'Enable 2FA' }).click();
    // Wait for QR code to render
    await expect(this.page.getByRole('img', { name: 'QR code' })).toBeVisible();
  }
}
```

## fixtures.ts — inject POM via fixture

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { SettingsPage } from '../../support/pages/settings-page';
import { ProfilePage } from '../../support/pages/profile-page';

type Fixtures = {
  settingsPage: SettingsPage;
  profilePage: ProfilePage;
};

export const test = base.extend<Fixtures>({
  settingsPage: async ({ page }, use) => {
    await use(new SettingsPage(page));
  },
  profilePage: async ({ page }, use) => {
    await use(new ProfilePage(page));
  },
});

export const { Given, When, Then } = createBdd(test);
```

## Step definitions

```typescript
// features/steps/settings.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from './fixtures';

Given('I am signed in as a pro user', async ({ page }) => {
  // Auth is handled by storageState in playwright.config.ts;
  // this step navigates to the starting point for this feature
  await page.goto('/dashboard');
});

When('I disable email notifications', async ({ settingsPage }) => {
  await settingsPage.goto();
  await settingsPage.disableEmailNotifications();
});

Then(
  'my notification preferences show email as disabled',
  async ({ settingsPage }) => {
    const isEnabled = await settingsPage.getEmailNotificationStatus();
    expect(isEnabled).toBe(false);
  }
);

When(
  'I update my display name to {string}',
  async ({ settingsPage }, name: string) => {
    await settingsPage.goto();
    await settingsPage.updateDisplayName(name);
  }
);

Then(
  'my profile shows the display name {string}',
  async ({ profilePage }, expectedName: string) => {
    await profilePage.goto();
    await expect(
      profilePage.getDisplayName()
    ).resolves.toBe(expectedName);
  }
);

When('I cancel my account', async ({ settingsPage }) => {
  await settingsPage.goto();
  await settingsPage.cancelAccount();
});

Then('I am redirected to the goodbye page', async ({ page }) => {
  await expect(page).toHaveURL('/goodbye');
});

Then('I receive an account cancellation email', async ({ request }) => {
  // Check via API rather than real email
  const res = await request.get('/api/test/emails?type=cancellation&limit=1');
  const emails = await res.json();
  expect(emails.length).toBeGreaterThan(0);
});

When('I enable two-factor authentication', async ({ settingsPage }) => {
  await settingsPage.goto();
  await settingsPage.enableTwoFactor();
});

Then('my security settings show 2FA as active', async ({ page }) => {
  const badge = page.getByRole('status', { name: '2FA active' });
  await expect(badge).toBeVisible();
});

Then(
  'I am shown a QR code for my authenticator app',
  async ({ page }) => {
    await expect(page.getByRole('img', { name: 'QR code' })).toBeVisible();
  }
);
```

## Using decorator style for POM integration

With playwright-bdd's decorator syntax, POM classes can own their own step registrations:

```typescript
// support/pages/settings-page.ts (decorator variant)
import { Fixture, Given, When, Then } from 'playwright-bdd/decorators';
import type { test } from '../fixtures';

@Fixture<typeof test>('settingsPage')
export class SettingsPage {
  // ...constructor and methods as before...

  @When('I disable email notifications')
  async disableEmailNotifications(): Promise<void> {
    // implementation directly on the POM
  }

  @Then('my notification preferences show email as disabled')
  async assertEmailDisabled(): Promise<void> {
    const isEnabled = await this.getEmailNotificationStatus();
    expect(isEnabled).toBe(false);
  }
}
```

!!! tip "Step body length rule"
    If a step definition body is longer than 5–7 lines, extract the logic to a POM method. Step files should read like a table of contents; POM classes contain the chapters.

!!! note "Protocol exceptions"
    Some steps are legitimately more specific: `Then the API returns HTTP 404` names a protocol-level behavior. This is not imperative; the HTTP status code is the behavior under test. See [Declarative vs. Imperative](../../gherkin/best-practices/scenario-structure.md) for the full distinction.

## Related

- [Decorator style](../playwright-bdd/decorators.md) — full decorator API reference
- [Step Definition Design](../../gherkin/best-practices/step-definition-design.md) — the thin translation layer principle
- [Gherkin Declarative UI Workflows examples](../../gherkin/examples/declarative-ui-workflows.md) — feature file only
