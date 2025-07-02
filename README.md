# Cro::HTTP::Session::MySQL

An implementation of Cro persistent sessions using MySQL.

## Assumptions

There are dozens of ways we might do session storage; this module handles
the case where: 

* The database is being accessed using `DB::MySQL`.
* You're fine with the session state being serialized and stored as a
  string/blob in the database.

If these don't meet your needs, it's best to steal the code from this
module into your own application and edit it as needed.

## Database setup

Create a table like this in the database:

```sql
CREATE TABLE `sessions` (
  `session_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`session_id`),
  KEY `timestamp_idx` (`timestamp`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

You can change the table and column names, but will then have to specify
them when constructing the session state object.

## Minimal Cro application setup

First, create a session object if you do not already have one. This is
a class that holds the session state. We'll be saving/loading its content.
For example:

```raku
use Cro::HTTP::Auth;
use JSON::Class;

class MySession does Cro::HTTP::Auth does JSON::Class {
    has $.user-id is rw = 0;
    has Str $.user-name is rw = '';
    has Str $.user-email is rw = '';

    method is-logged-in(--> Bool) {
        with $.user-id {
            return True if $_ > 0;
        }
        return False;
     }
}
```

In the case that:

* You are using the default table/column names
* Your session object can be serialized by serializing its public attributes
  to JSON, and deserialized by passing those back to new

Then the only thing needed is to construct the session storage middleware with
a database handle and a session cookie name.

```raku
my $session-middleware = Cro::HTTP::Session::MySQL[MySession].new:
    :$db,
    :expiration(Duration.new(60 * 60)), # 1 hour
    :cookie-name('my_app_name_session');
```

It can then be applied as application or `route`-block level middleware. 

## Tweaking the table and column names

Pass these named arguments as needed during construction:

* `sessions-table`
* `id-column`
* `data-column`
* `timestamp-column`

## This module is a derivative work of the PostgreSQL implementation

This module is a derivative work of the PostgreSQL implementation, which can be
found here: https://github.com/croservices/cro-http-session-pg
