# ConfStack

ConfStack is a hierarchical configuration management library.

## Usage

ConfStack configuration is loaded from `.confstack` files using a minimal DSL.
The name of this file is configurable when creating the configuration object by
passing a `filename:` argument (e.g. `ConfStack.new filename: 'my-cool-config'`).

ConfStack looks for and evaluates `.confstack` files recursively up the file
tree until it reaches the root of your project, if defined, or your home directory,
if it's not.  Additionally, it always looks for and attempts to load a `.confstack`
file in your home directory, if one exists.

In this way, configuration for your tools can live where it makes the most sense
for it to live with as much or as little duplication as you deem necessary.

Short example:

```ruby

at_project_root   # Specifies that this is the root of your project

# These are functionally equivalent
configure some_value: 'foo'
configure :some_value, 'foo'

# These are also functionally equivalent
configure(:lazy_load) { "some_value is #{some_value}" }
configure lazy_load: proc { "some value is #{some_value}" }

see_also 'path/to/other/configuration'
```

### ConfStack DSL

#### `project_root [directory]`

Specifies the root of your project.  Must be specified to prevent Mastermind
from scanning more of your file system than it needs to.  The easiest way to
do this is to just specify `at_project_root` in a `.confstack` file in the
actual root of your project.

----

#### `at_project_root`

Syntactic sugar for specifying that the current `.confstack` is in the root of your repository.

It's equivalent to `project_root __dir__`.

----

#### `configure attribute [value] [&block]`

Alias: `set`

This command has two forms that are otherwise identical:

* `configure attribute, value # attribute and value as separate arguments`
* `configure attribute: value # attribute and value as key: value of a hash`

Used to set arbitrary configuration options.  When a configuration option is
set in multiple `.confstack` files, the "closest" one to your invocation wins.
In other words, since Mastermind reads `.confstack` files starting in your
current directory and working it's way "up" the hierarchy, the first `.confstack`
that specifies a configuration option "wins".

When provided a block, the value is computed the first time the option is called
for.  The block runs in the context of the `Configuration` object built up by
all the loaded `.confstack` files, so it has access to all previously set
configuration options.

The block is only executed once.  After that, the value is cached so that it
doesn't need to be recomputed.

If both a block and a value are given, the block is ignored and only the value
is stored.

----

#### `see_also filename`

Instructs Mastermind to also load the configuration specified in `filename`.
This file does _not_ have to be named `.confstack` but _does_ have to conform
to the syntax outlined here.

## Installation

Add this line to your application's Gemfile:

```ruby
gem conf-stack'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install conf-stack

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chall8908/conf-stack.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
