---
description: IBootstrap, constructor autowire, Server::get, no Autowire attribute
globs: "**/{AppInfo/Application.php,*Controller.php,*Listener.php,*Mapper.php,*Service.php}"
alwaysApply: false
---

# Dependency injection

Pimple + constructor reflection. **Any instantiable class is a service** on first `get()`. Registration is the exception. `#[Autowire]` and `#[Listen]` **do not exist**.

## Pattern

`apps/<id>/lib/AppInfo/Application.php` extends `OCP\AppFramework\App` and implements `IBootstrap`.

- `register(IRegistrationContext)`: catalog only — `registerEventListener`, `registerCapability`, `registerNotifierService`, `registerConfigLexicon`, `registerSetupCheck`, … **Do not** `registerService` every class.
- Concrete `OCA\Foo\Service\Bar` is constructed from typehints. Bind interfaces with `registerServiceAlias`. Factories only for conditional / unshared / extra scalars.
- `boot(IBootContext)` often empty. Runtime glue: `$context->injectFn(...)` (autowires the closure).
- Listeners: class-string + `IEventListener::handle`. Not Symfony `#[AsEventListener]`.
- Controllers: constructor promotion. `?string $userId`, `string $appName`, `IRequest` are container parameters. Do not take services as **method** args (Dispatcher can resolve them from the container — that is a footgun).
- `OCP\Server::get(Foo::class)` is a locator wrapping `OC::$server`. Prefer ctor injection. Acceptable in static helpers and some `Application::register` sharing-registry wiring.
- `appinfo/app.php` is gone. `IContainer::query` / ArrayAccess on the container are deprecated since 20.

## Follow

- `apps/comments/lib/AppInfo/Application.php` — listeners/capability/notifier, empty `boot()`, no factories.
- `apps/files_reminders/lib/AppInfo/Application.php` — same, 2023+ app.
- `apps/user_status/lib/Controller/UserStatusController.php` — promoted props + `?string $userId`.
- `lib/private/AppFramework/Utility/SimpleContainer.php` — type → param name → default → null.

## Do not copy

- `apps/files/lib/AppInfo/Application.php` — `Server::get(ISharingRegistry::class)` during `register()` (locator before boot).
- `apps/user_status/lib/AppInfo/Application.php` — `$this->getContainer()->get(IConfig::class)` in `register()` to decide a widget.
- `apps/dav/lib/AppInfo/Application.php` / `apps/settings/lib/AppInfo/Application.php` — `registerService` closures that only `new` + `$c->get()` (duplicates autowire).
- `apps/lookup_server_connector` / `files_sharing` — `addListener` closures that then `$container->get(Listener::class)` instead of `registerEventListener`.
- `OC::$server` in controllers.

## Frontend

Not provide/inject for app-wide services. Newer Vue (`files`): Pinia `defineStore`. Older (`settings`, `user_status`): Vuex still present. Do not introduce a third state library.

## MUST

- MUST implement `IBootstrap` in `lib/AppInfo/Application.php`.
- MUST constructor-inject; MUST NOT `OC::$server` in controllers/listeners.
- MUST NOT `registerService` a concrete class whose constructor already typehints resolvable services.
- MUST register listeners via `registerEventListener($event, $listener)`.
