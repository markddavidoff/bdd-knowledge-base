---
title: Cucumber-JVM (Java)
description: Cucumber-JVM step definitions using Java annotations, @ParameterType, Spring dependency injection, and concept mapping to playwright-bdd.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - git-gherkin-parser-java-readme-readme
---

# Cucumber-JVM (Java)

Cucumber-JVM is the reference implementation for Java (and Kotlin, Groovy, Scala). It implements the same Gherkin specification as playwright-bdd and supports the full feature set: custom parameter types, data tables, doc strings, backgrounds, rules, and tags. For teams that operate Java backend services alongside a TypeScript frontend, maintaining both suites against the same feature vocabulary is a practical pattern.

## The Same Feature File

```gherkin
Feature: Order fulfillment

  Scenario: Fulfilling an order for a pro customer
    Given Acme Corp has a "pro" subscription
    And Acme Corp has placed order #ORD-1042 for 5 units of "Widget Pro"
    When the warehouse processes order #ORD-1042
    Then order #ORD-1042 status is "fulfilled"
    And an email confirmation is sent to orders@acme.example
```

## Step Definitions in Java

Cucumber-JVM uses Java annotations `@Given`, `@When`, `@Then` from `io.cucumber.java`. Step classes are plain POJOs; Cucumber-JVM instantiates them and injects dependencies via a DI plugin.

```java
// src/test/java/steps/OrderSteps.java
package steps;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;
import org.springframework.beans.factory.annotation.Autowired;
import static org.assertj.core.api.Assertions.assertThat;

public class OrderSteps {

    @Autowired
    private OrderService orderService;

    @Autowired
    private EmailService emailService;

    private Order order;

    @Given("Acme Corp has placed order #{string} for {int} units of {string}")
    public void acmeCorpPlacedOrder(String orderId, int quantity, String product) {
        order = orderService.createOrder("acme-corp", orderId, product, quantity);
    }

    @When("the warehouse processes order #{string}")
    public void warehouseProcessesOrder(String orderId) {
        orderService.process(orderId);
    }

    @Then("order #{string} status is {string}")
    public void orderStatusIs(String orderId, String expectedStatus) {
        Order fetched = orderService.findById(orderId);
        assertThat(fetched.getStatus()).isEqualTo(expectedStatus);
    }

    @Then("an email confirmation is sent to {string}")
    public void emailConfirmationSent(String recipient) {
        assertThat(emailService.getLastRecipient()).isEqualTo(recipient);
    }
}
```

## @ParameterType: Custom Parameter Types in Java

The `@ParameterType` annotation registers a custom Cucumber Expression type, equivalent to `defineParameterType` in the JS ecosystem:

```java
// src/test/java/steps/ParameterTypes.java
package steps;

import io.cucumber.java.ParameterType;

public class ParameterTypes {

    @ParameterType("free|pro|enterprise")
    public OrgPlan orgPlan(String planName) {
        return switch (planName) {
            case "free"       -> new OrgPlan(false, 5);
            case "pro"        -> new OrgPlan(true,  50);
            case "enterprise" -> new OrgPlan(true,  Integer.MAX_VALUE);
            default -> throw new IllegalArgumentException("Unknown plan: " + planName);
        };
    }
}
```

Then use it in step patterns:

```java
@Given("Acme Corp has a {orgPlan} subscription")
public void acmeCorpHasPlan(OrgPlan plan) {
    org = orgService.create("Acme Corp", plan);
}
```

The method name (`orgPlan`) becomes the parameter type name used in curly-brace expressions.

## Spring Integration

For Spring-based projects, add the `cucumber-spring` dependency to enable full Spring context injection:

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.cucumber</groupId>
    <artifactId>cucumber-spring</artifactId>
    <version>7.15.0</version>
    <scope>test</scope>
</dependency>
```

Annotate the step class or a shared configuration class:

```java
@CucumberContextConfiguration
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class CucumberSpringConfig {
    // Spring beans available to all step classes via @Autowired
}
```

Spring manages the bean lifecycle; Cucumber-JVM requests beans via the container.

## Running Cucumber-JVM

Test runner configuration lives in a JUnit 5 entry point:

```java
// src/test/java/RunCucumberTest.java
import io.cucumber.junit.platform.engine.Constants;
import org.junit.platform.suite.api.*;

@Suite
@IncludeEngines("cucumber")
@SelectClasspathResource("features")
@ConfigurationParameter(
    key = Constants.GLUE_PROPERTY_NAME,
    value = "steps"
)
@ConfigurationParameter(
    key = Constants.FILTER_TAGS_PROPERTY_NAME,
    value = "@smoke"
)
public class RunCucumberTest {}
```

Run from Maven:

```bash
# Run all Cucumber tests
mvn test

# Run with a specific tag
mvn test -Dcucumber.filter.tags="@smoke"
```

## Concept Mapping: Cucumber-JVM → playwright-bdd

| Cucumber-JVM concept | playwright-bdd equivalent |
|---------------------|--------------------------|
| `@Given` annotation | `Given()` from `createBdd()` |
| `@ParameterType` | `defineParameterType` transformer |
| `@Autowired` field | Fixture parameter in step function |
| `CucumberContextConfiguration` | `fixtures.ts` with `test.extend` |
| Instance field for scenario state | Fixture holding scenario state |
| `DataTable` parameter | `DataTable` from playwright-bdd |
| `@DataTableType` | `defineDataTableType` |
| `pom.xml` / `cucumber.properties` | `playwright.config.ts` |
| `mvn test -Dcucumber.filter.tags` | `npx playwright test --grep` |

## When Teams Cross From Cucumber-JVM

Feature files transfer unchanged. The primary conceptual shift:

1. **`@Autowired` → fixtures**: Spring dependency injection maps to Playwright's fixture system. Both are type-safe DI mechanisms; fixtures are function-parameter-based rather than annotation-based.
2. **Instance fields → scoped fixtures**: In Cucumber-JVM, scenario state lives in step class instance fields (Cucumber creates one instance per scenario). In playwright-bdd, scenario state lives in test-scoped fixtures or plain objects inside step closures.
3. **Regex patterns → Cucumber Expressions**: Cucumber-JVM supports both. Cucumber Expressions (`{string}`, `{int}`, custom types) produce cleaner patterns and are preferred.

!!! tip "Sharing vocabulary across stacks"
    If your team uses the same `.feature` files to drive both a Java integration test suite (Cucumber-JVM) and a TypeScript UI test suite (playwright-bdd), keep parameter type names consistent. `{org-plan}` means the same thing in both `@ParameterType` Java and `defineParameterType` TypeScript — the transformer implementation differs, but the Gherkin vocabulary stays unified.
