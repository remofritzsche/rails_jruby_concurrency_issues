# Rails jRuby Concurrency Issues Sample Application

This sample Rails application reproduces multiple concurrency issues that arise
with Rails 5 in conjunction with jRuby 9k.

This has been reported in [Rails issue #27418](https://github.com/rails/rails/issues/27418).

Setup
=====

1. Install jruby (we're using `jruby 9.1.6.0`)

2. Install a MySQL server

3. Checkout this repository

4. Adapt `config/database.yml` if required

5. Install gems and migrate database

   ```bash
   jruby ./bin/bundle install --path vendor/bundle
   RAILS_ENV=production jruby ./bin/rake db:create # If required
   RAILS_ENV=production jruby ./bin/rake db:migrate
   ```

Issue #1: Loading model schema information is not thread safe
=============================================================

When first using an Active Record model, the detailed schema information is
loaded from the database. This process does not appear to be threadsafe.

To reproduce this, run the following script:

```bash
RAILS_ENV=production jruby ./bin/rails runner test_schema_loading.rb
```

In most cases, this produces an error like the following (you might need to
re-run it a couple of times):

```
NoMethodError: undefined method `default_scope_override' for #<Class:0x5d75f90e>
Did you mean?  default_scope_override=
                          method_missing at org/jruby/RubyBasicObject.java:1655
                          method_missing at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/dynamic_matchers.rb:21
                     build_default_scope at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping/default.rb:111
                          default_scoped at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping/named.rb:33
                                     all at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping/named.rb:28
                        scope_attributes at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping.rb:24
  populate_with_current_scope_attributes at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping.rb:36
           initialize_internals_callback at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/scoping.rb:43
                              initialize at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/core.rb:317
                                     new at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/inheritance.rb:65
                                  create at /thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:33
```

Also, you might notice that the schema information is loaded multiple times.
Probably there is a missing mutex somewhere.

This problem is also described in [this Stack Overflow question](http://stackoverflow.com/questions/41239806).

Issue #2: Using active record concurrently
==========================================

This second issue is harded to describe and the error messages vary. It can be
reproduced if you fiddle around with Active Record models and / or relations in
a concurrent manner. For this purpose, we wrote a simple script that creates a
`Group`, a `User` and associates both with each other. We assume that other AR
actions would lead to an even wider variety of exceptions (in one of our
applications, we are experiencing different exceptions that could not yet be
reproduced by running this test script).

To reproduce this, run the following script:

```bash
RAILS_ENV=production jruby ./bin/rails runner test_ar_concurrency.rb
```

In our tests, this has yielded one of the following errors in most cases (you
might need to re-run it a couple of times):

```
Exception: uninitialized constant ActiveRecord::QueryMethods::PredicateBuilder
Did you mean?  ActiveRecord::PredicateBuilder
org/jruby/RubyModule.java:3343:in `const_missing'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation/query_methods.rb:631:in `where!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation/query_methods.rb:625:in `where'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation.rb:83:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:545:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/locking/optimistic.rb:79:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/attribute_methods/dirty.rb:119:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:306:in `block in _update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:126:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:506:in `block in compile'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:455:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:101:in `__run_callbacks__'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:750:in `_run_update_callbacks'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:306:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/timestamp.rb:81:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:534:in `create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:298:in `block in create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:126:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:506:in `block in compile'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:455:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:101:in `__run_callbacks__'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:750:in `_run_save_callbacks'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:298:in `create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:152:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/validations.rb:50:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/attribute_methods/dirty.rb:30:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:324:in `block in save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:395:in `block in with_transaction_returning_status'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:230:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:211:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:392:in `with_transaction_returning_status'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:324:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/suppressor.rb:45:in `save!'
test_ar_concurrency.rb:9:in `block in test'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:232:in `block in transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/transaction.rb:189:in `within_new_transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:232:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:211:in `transaction'
test_ar_concurrency.rb:5:in `test'
test_ar_concurrency.rb:18:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'
```

```
Exception: uninitialized constant ActiveRecord::QueryMethods::Relation
Did you mean?  ActiveRecord::Relation
org/jruby/RubyModule.java:3343:in `const_missing'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation/query_methods.rb:1230:in `where_clause_factory'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation/query_methods.rb:632:in `where!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation/query_methods.rb:625:in `where'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/relation.rb:83:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:545:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/locking/optimistic.rb:79:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/attribute_methods/dirty.rb:119:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:306:in `block in _update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:126:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:506:in `block in compile'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:455:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:101:in `__run_callbacks__'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:750:in `_run_update_callbacks'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:306:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/timestamp.rb:81:in `_update_record'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:534:in `create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:298:in `block in create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:126:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:506:in `block in compile'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:455:in `call'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:101:in `__run_callbacks__'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/callbacks.rb:750:in `_run_save_callbacks'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/callbacks.rb:298:in `create_or_update'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/persistence.rb:152:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/validations.rb:50:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/attribute_methods/dirty.rb:30:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:324:in `block in save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:395:in `block in with_transaction_returning_status'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:230:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:211:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:392:in `with_transaction_returning_status'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:324:in `save!'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/suppressor.rb:45:in `save!'
test_ar_concurrency.rb:9:in `block in test'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:232:in `block in transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/transaction.rb:189:in `within_new_transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/connection_adapters/abstract/database_statements.rb:232:in `transaction'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activerecord-5.0.0.1/lib/active_record/transactions.rb:211:in `transaction'
test_ar_concurrency.rb:5:in `test'
test_ar_concurrency.rb:18:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'
```

Issue #3: Development mode auto reloading
=========================================

Autoreloading in development mode does not seem thread safe. In the past, we've
encountered countless issues with autoreloading when using concurrency in
development mode and just assumed this was not supported. As
[mentioned by @mathewd](https://github.com/rails/rails/issues/27418#issuecomment-268308638)
though, Rails' autoreloading should indeed be thread-safe.

In MRI it probably is because of GIL (Global Interpreter Lock), but in jRuby we
reckon it isn't.

To reproduce one of the autoreloading exceptions, run the following script:

```bash
RAILS_ENV=development jruby ./bin/rails runner test_auto_reloading.rb
```

This leads to errors like:

```
Exception: Circular dependency detected while autoloading constant User
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:509:in `load_missing_constant'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:203:in `const_missing'
test_auto_reloading.rb:2:in `test'
test_auto_reloading.rb:15:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'Exception: Circular dependency detected while autoloading constant User
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:509:in `load_missing_constant'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:203:in `const_missing'
test_auto_reloading.rb:2:in `test'
test_auto_reloading.rb:15:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'Exception: Circular dependency detected while autoloading constant User
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:509:in `load_missing_constant'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:203:in `const_missing'
test_auto_reloading.rb:2:in `test'
test_auto_reloading.rb:15:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'Exception: Circular dependency detected while autoloading constant User
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:509:in `load_missing_constant'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:203:in `const_missing'
test_auto_reloading.rb:2:in `test'
test_auto_reloading.rb:15:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'Exception: Circular dependency detected while autoloading constant User
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:509:in `load_missing_constant'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/activesupport-5.0.0.1/lib/active_support/dependencies.rb:203:in `const_missing'
test_auto_reloading.rb:2:in `test'
test_auto_reloading.rb:15:in `block in (root)'
/thread_safe_col_loading/vendor/bundle/jruby/2.3.0/gems/concurrent-ruby-1.0.3-java/lib/concurrent/executor/java_executor_service.rb:94:in `run'
```
