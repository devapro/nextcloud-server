---
description: QueryBuilder, QBMapper, Entity, migrations, no Doctrine ORM
globs: "**/{*Mapper.php,*Entity.php,**/Db/**,**/Migration/**,lib/private/DB/**}"
alwaysApply: false
---

# Database access

QueryBuilder over ORM. There is **no** Doctrine ORM and no Eloquent. `3rdparty` has DBAL only.

## Pattern (app tables)

`QBMapper` + `Entity` + `SimpleMigrationStep`. Table names in PHP **never** include `oc_` (QueryBuilder prepends `*PREFIX*` → default `oc_`).

```php
class ReminderMapper extends QBMapper {
    public const TABLE_NAME = 'files_reminders';
    public function __construct(IDBConnection $db, private ITimeFactory $timeFactory) {
        parent::__construct($db, self::TABLE_NAME, Reminder::class);
    }
    public function findDueForUser(IUser $user, int $fileId): Reminder {
        $qb = $this->db->getQueryBuilder();
        $qb->select(...)
            ->from($this->getTableName())
            ->where($qb->expr()->eq('user_id', $qb->createNamedParameter($user->getUID(), IQueryBuilder::PARAM_STR)));
        return $this->findEntity($qb);
    }
}
```

- Bind **all** values with `createNamedParameter`. `expr()->eq/in/...`.
- Prefer `$qb->executeQuery()` / `executeStatement()`. `IDBConnection::executeQuery($sql)` is a SQL taint sink.
- Prefer `getTypedQueryBuilder()` (34+) when selecting typed columns; same object as `getQueryBuilder()`.
- Transactions: `OCP\AppFramework\Db\TTransactional::atomic($fn, $db)` or begin/commit/rollback. Dispatcher rolls back leftover controller transactions.
- Schema: `changeSchema` + `ISchemaWrapper` (`hasTable`/`createTable`/`addColumn`/`setPrimaryKey`). Data fixes in `postSchemaChange` via QB.
- Core hot paths (`filecache`, `share`, `users`) skip mappers and use specialized QB. Do not invent a mapper over them.

**New ORM (35, not dominant):** `OCP\AppFramework\ORM\Repository` + `#[Entity]` / `#[Column]`. Still implemented with QueryBuilder. Used by `twofactor_backupcodes` BackupCodeMapper and `TagMapper`. New shipped-app tables SHOULD still use QBMapper unless matching that 35 style on purpose.

## Follow

- `apps/files_reminders/lib/Db/ReminderMapper.php` + `Reminder.php` + `lib/Migration/Version10000Date20230725162149.php`.
- `apps/oauth2/lib/Db/AccessTokenMapper.php`.
- `lib/public/AppFramework/Db/QBMapper.php`.

## Do not copy

- `IDBConnection::createQueryBuilder()` (Doctrine native) — use `getQueryBuilder()`.
- Interpolating user input into SQL or into `createFunction`. Column names MUST be whitelisted if they must be dynamic (LDAP `AbstractMapping`).
- `lib/private/DB/Adapter.php` `insertIfNotExist` (deprecated) concatenates identifiers.
- Importing `Doctrine\ORM\EntityManager`. Nextcloud `OC\AppFramework\ORM\EntityManager` is a thin QB hydrator.

## MUST

- MUST inject `IDBConnection` and use `getQueryBuilder()` / `getTypedQueryBuilder()`.
- MUST bind values; MUST NOT concatenate request data into SQL.
- MUST create app tables via `SimpleMigrationStep` with unprefixed names.
- MUST NOT add Doctrine ORM or Eloquent.
