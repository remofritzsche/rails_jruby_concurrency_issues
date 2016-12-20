# Rails Thread Safe Column Loading

This sample Rails application reproduces the potential Rails bug described in
[this Stack Overflow question](http://stackoverflow.com/questions/41239806).

To reproduce this, checkout the repository, install jruby and then perform
the following steps:

```bash
jruby ./bin/bundle install --path vendor/bundle
RAILS_ENV=production jruby ./bin/rake db:migrate
RAILS_ENV=production jruby ./bin/rails runner test.rb
```
