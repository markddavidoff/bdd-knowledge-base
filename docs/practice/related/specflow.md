---
title: SpecFlow (C#)
description: SpecFlow BDD runner for .NET — attribute-based step definitions, value retrievers, and NUnit/xUnit integration, with JS equivalent mapping.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - git-gherkin-parser-dotnet-readme-readme
---

# SpecFlow (C#)

SpecFlow is the standard BDD framework for .NET. It implements the same Gherkin specification as playwright-bdd and CucumberJS, so `.feature` files written by your BA or product team are portable. What differs is everything in the step definition layer — syntax, tooling, and the dependency injection model.

This page is a reference for teams that maintain SpecFlow suites alongside JavaScript services, or for developers crossing from .NET into TypeScript BDD work.

## The Same Feature File

```gherkin
Feature: User account management

  Scenario: Admin promotes a user to editor role
    Given Alice has a "viewer" account
    When an admin promotes Alice to "editor"
    Then Alice's role is "editor"
    And Alice can access the editor dashboard
```

This feature file is identical whether it runs under SpecFlow, playwright-bdd, or any other Gherkin runner.

## Step Definitions in C#

SpecFlow uses C# attributes to decorate step methods. The binding class must carry `[Binding]`:

```csharp
// StepDefinitions/AccountSteps.cs
using TechTalk.SpecFlow;
using NUnit.Framework;

[Binding]
public class AccountSteps
{
    private readonly IAccountService _accountService;
    private User _alice;

    // Constructor injection via SpecFlow's IoC container
    public AccountSteps(IAccountService accountService)
    {
        _accountService = accountService;
    }

    [Given(@"Alice has a ""(.*)"" account")]
    public async Task GivenAliceHasAnAccount(string role)
    {
        _alice = await _accountService.CreateUser("alice@example.com", role);
    }

    [When(@"an admin promotes Alice to ""(.*)""")]
    public async Task WhenAnAdminPromotesAlice(string newRole)
    {
        await _accountService.PromoteUser(_alice.Id, newRole);
    }

    [Then(@"Alice's role is ""(.*)""")]
    public async Task ThenAlicesRoleIs(string expectedRole)
    {
        var user = await _accountService.GetUser(_alice.Id);
        Assert.That(user.Role, Is.EqualTo(expectedRole));
    }

    [Then(@"Alice can access the editor dashboard")]
    public async Task ThenAliceCanAccessEditorDashboard()
    {
        var canAccess = await _accountService.HasAccess(_alice.Id, "editor-dashboard");
        Assert.That(canAccess, Is.True);
    }
}
```

Key observations:
- **`[Given]`, `[When]`, `[Then]`** are attributes from `TechTalk.SpecFlow`
- Step patterns use **regular expressions** (not Cucumber Expressions by default, though SpecFlow v3.9+ adds Cucumber Expression support)
- **Dependency injection** replaces the World object: services are constructor-injected by SpecFlow's built-in IoC container (or Autofac, Unity, etc.)
- State between steps in the same scenario is shared via **instance fields** on the binding class (SpecFlow creates one instance per scenario by default)

## Value Retrievers (SpecFlow's Parameter Types)

SpecFlow's equivalent to `defineParameterType` is the **Value Retriever** interface:

```csharp
// Support/OrgPlanValueRetriever.cs
using TechTalk.SpecFlow.Assist;

public class OrgPlan
{
    public bool BillingEnabled { get; set; }
    public int SeatLimit { get; set; }
}

public class OrgPlanValueRetriever : IValueRetriever
{
    public bool CanRetrieve(KeyValuePair<string, string> keyValuePair,
                            Type targetType, Type propertyType)
        => propertyType == typeof(OrgPlan);

    public object Retrieve(KeyValuePair<string, string> keyValuePair,
                           Type targetType, Type propertyType)
    {
        return keyValuePair.Value switch
        {
            "free"       => new OrgPlan { BillingEnabled = false, SeatLimit = 5 },
            "pro"        => new OrgPlan { BillingEnabled = true,  SeatLimit = 50 },
            "enterprise" => new OrgPlan { BillingEnabled = true,  SeatLimit = int.MaxValue },
            _ => throw new ArgumentException($"Unknown plan: {keyValuePair.Value}")
        };
    }
}
```

Value Retrievers are used primarily with SpecFlow's Table Assist helpers (`table.CreateInstance<T>()`), which auto-populate POCOs from data tables.

## NUnit and xUnit Integration

SpecFlow generates test classes at build time that are compatible with NUnit or xUnit. You configure the runner in `specflow.json`:

```json
{
  "bindingCulture": { "language": "en-US" },
  "stepAssemblies": [],
  "plugins": []
}
```

The test project `.csproj` selects the runner package:

```xml
<PackageReference Include="SpecFlow.NUnit" Version="3.*" />
<!-- OR -->
<PackageReference Include="SpecFlow.xUnit" Version="3.*" />
```

## SpecFlow+ LivingDoc

SpecFlow+ LivingDoc generates HTML living documentation from your feature files and test results, serving a similar purpose to Allure or Cucumber's HTML reporter in the JS ecosystem:

```bash
# Install the tool
dotnet tool install --global SpecFlow.Plus.LivingDoc.CLI

# Generate report after a test run
livingdoc test-assembly MyProject.Tests.dll -t TestExecution.json
```

## Concept Mapping: SpecFlow → playwright-bdd

| SpecFlow concept | playwright-bdd equivalent |
|-----------------|--------------------------|
| `[Binding]` class | Step file (any `.ts` file loaded by config) |
| `[Given]` attribute | `Given()` from `createBdd()` |
| Constructor injection | Fixture parameter (`{ myFixture }`) |
| Instance field for state | Fixture holding scenario state |
| Value Retriever | `defineParameterType` transformer |
| `Table.CreateInstance<T>()` | `DataTableType` transformer |
| `specflow.json` | `playwright.config.ts` with `defineBddConfig()` |
| LivingDoc | Allure or Cucumber HTML reporter |

## When Teams Cross From SpecFlow

The Gherkin syntax is identical — feature files transfer directly. The mental model shift:

1. **DI → fixtures**: Instead of constructor injection, state enters step functions as the first parameter. Playwright fixtures are functionally equivalent but compositional rather than container-based.
2. **Regex → Cucumber Expressions**: SpecFlow defaults to regex patterns. Switch to `{string}`, `{int}`, `{word}` Cucumber Expressions for cleaner, snippet-generated patterns.
3. **Sync → async**: SpecFlow supports async; C# `async Task` maps directly to TypeScript `async () => {}`.

!!! example "The one-line translation"
    `[Given(@"Alice has a ""(.*)"" account")]` becomes  
    `` Given('Alice has a {string} account', async ({ accountService }, role: string) => { ... }) ``
