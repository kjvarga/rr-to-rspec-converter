# RR to RSpec Converter

This is a modification of the [Rails5 Spec Converter](https://github.com/tjgrathwell/rr-to-rspec-converter) tool to handle converting from [RR v1.1.2](https://github.com/rr/rr/blob/master/doc/03_api_overview.md) to [RSpec v3.6.0](https://relishapp.com/rspec/rspec-mocks/v/3-6/docs) syntax for mocking and stubbing.  This is a basic implementation to handle the needs of a large codebase of 6000+ tests.  It handles most usages but is not exhaustive.

  * [Installation](#installation)
  * [Usage](#usage)
  * [Development](#development)
  * [RR](#rr)
    + [Mocking and Stubbing](#mocking-and-stubbing)
      - [#mock](#%23mock)
      - [#mock!](#%23mock)
      - [#stub](#%23stub)
      - [#stub!](#%23stub)
      - [#dont_allow](#%23dont_allow)
      - [#dont_allow!](#%23dont_allow)
      - [#proxy](#%23proxy)
      - [#proxy!](#%23proxy)
      - [#instance_of](#%23instance_of)
      - [#instance_of!](#%23instance_of)
      - [#any_instance_of](#%23any_instance_of)
      - [#with_any_args](#%23with_any_args)
      - [#with_no_args](#%23with_no_args)
      - [#times](#%23times)
      - [#any_times](#%23any_times)
      - [#returns](#%23returns)
      - [#yields](#%23yields)
      - [#with](#%23with)
      - [#never](#%23never)
      - [#once](#%23once)
      - [#at_least](#%23at_least)
      - [#at_most](#%23at_most)
    + [Matchers](#matchers)
      - [#anything](#%23anything)
      - [#is_a](#%23is_a)
      - [#numeric](#%23numeric)
      - [#boolean](#%23boolean)
      - [#duck_type](#%23duck_type)
      - [#hash_including](#%23hash_including)
      - [#rr_satisfy](#%23rr_satisfy)
    + [Module References](#module-references)
      - [RR::WildcardMatchers::HashIncluding](#rrwildcardmatchershashincluding)
      - [RR::WildcardMatchers::Satisfy](#rrwildcardmatcherssatisfy)
      - [RR.reset](#rrreset)
  * [Manual Cleanup](#manual-cleanup)
  * [Configure RSpec](#configure-rspec)
  * [License](#license)
## Installation

Install the gem standalone like so:

    $ gem install rr-to-rspec-converter

## Usage

Make sure you've committed everything to Git first, then

    $ cd some-project
    $ rr-to-rspec-converter

This will update all the files in that directory matching the globs `spec/**/*_spec.rb` or `test/**/*_test.rb`.

If you want to specify a specific set of files instead, you can run `rr-to-rspec-converter path_to_my_files`.

By default it will make some noise, run with `rr-to-rspec-converter --quiet` if you want it not to.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## RR

The following lists each RR API method and the conversion that is applied.  Some cases are not handled.  To see which ones, search for `unhandled` in this document.

### Mocking and Stubbing

#### #mock

    mock(view).render.with_any_args.twice do |*args|
      if args.first == {:partial => "user_info"}
        "User Info"
      else
        "Stuff in the view #{args.inspect}"
      end
    end

    => expect(object).to receive(:method).with(arguments).and_return(return_val)

#### #mock!

* Nested `mock!`, e.g. `mock.something.mock!.method { result }` => `and_return(double(method: result))`


Simnple usage:

    mock!
    =>
      instance_double("ConsoleNotifier")
      class_double("ConsoleNotifier")
      [object_double(User.new, :save => true)](https://relishapp.com/rspec/rspec-mocks/docs/verifying-doubles/using-an-object-double)
      object_double("MyApp::LOGGER", :info => nil).as_stubbed_const

      Then assert expectations with `have_received` or `receive`.

#### #stub

By itself:

    x = stub

    => [double](https://relishapp.com/rspec/rspec-mocks/v/3-8/docs/basics/partial-test-doubles)

With method:

    x = stub(object).method.with(args).returns { return_val }

    => allow(object).to receive(:method).with(arguments).and_return(return_val)

#### #stub!

**Unhandled**

    =>
      instance_double("ConsoleNotifier")
      class_double("ConsoleNotifier")
      object_double(User.new, :save => true)
      object_double("MyApp::LOGGER", :info => nil).as_stubbed_const

#### #dont_allow

Normal usage:

    dont_allow(object).method(args)

    => expect(object).not_to receive(:method).with(args)

Inside `any_instance_of` block (**Unhandled*):*

    any_instance_of(klass) do |o|
      dont_allow(object).method(args)
    end

    => expect_any_instance_of(klass).not_to receive(:method).with(args)

#### #dont_allow!

**Unhandled**

#### #proxy

**Unhandled**

    =>
      and_call_original, or
      and_wrap_original

      allow(Calculator).to receive(:add).and_call_original
      allow(Calculator).to receive(:add).with(2, 3).and_return(-5)

      expect(API).to receive(:solve_for).and_wrap_original { |m, *args| m.call(*args).first(5) }
      expect(API.solve_for(100)).to eq [1,2,3,4,5]

#### #proxy!

**Unhandled**

#### #instance_of

    => instance_of

#### #instance_of!

**Unhandled**

#### #any_instance_of

    any_instance_of(User) do |u|
      stub(u).valid? { false }
    end
     or
    any_instance_of(User, :valid? => false)
     or
    any_instance_of(User, :valid? => lambda { false })

    =>

      allow_any_instance_of(klass).to receive_messages(:method => return_value)
      expect_any_instance_of(klass).to receive_messages(:method => return_value)
      allow_any_instance_of(klass).to receive(:method => return_value)
      expect_any_instance_of(klass).to receive(:method => return_value)


#### #with_any_args

    mock(PetitionGroup).find.with_any_args.returns(petition_group)

    => with(any_args)

#### #with_no_args

    => with(no_args)

#### #times

    =>
      times(0) => expect().not_to receive()
      times(1) => once
      times(2) => twice
      times(n) => exactly(n).times  **Unhandled**
      times(any_times) => allow().to receive() OR at_least(:once)

#### #any_times

Converts to `at_least(:once)` but this interpretation may be incorrect.  The intention of the test may be to `allow` the message to be received - in which case `mock` should not have been used.

    .any_times
    .times(any_times)

    => allow().to receive() OR at_least(:once)

#### #returns

    mock(PetitionGroup).find.with_any_args.returns(petition_group)

    => and_return

#### #yields

**Unhandled**

#### #with

    => with

#### #never

    => expect(object).not_to receive(:method)

#### #once

    => once

#### #at_least

    =>
      at_least(0)  => Use `allow` instead of `expect` **Unhandled**
      at_least(1)  => at_least(:once)
      at_least(2)  => at_least(:twice)
      at_least(n)  => at_least(n).times

#### #at_most

    =>
      at_most(1)  => at_most(:once)
      at_most(2)  => at_most(:twice)
      at_most(n)  => at_most(n).times

### Matchers

#### #anything

    => anything

#### #is_a

    => kind_of

#### #numeric

    => kind_of(Numeric)

#### #boolean

    => boolean

#### #duck_type

    => duck_type

#### #hash_including

    => hash_including

#### #rr_satisfy

Use RSpec `satisfy` method.  Would need to rewrite to use arguments from block, which alters the intent of the test.  Will probably require manual fixes post conversion.

    => satisfy

### Module References

#### RR::WildcardMatchers::HashIncluding

    => hash_including

#### RR::WildcardMatchers::Satisfy

    => rr_satisfy

#### RR.reset

    => removes line

## Manual Cleanup

* Remove all comments that reference `/\brr\b/i`
* Remove 'rr' from Gemfile
* Remove `config.mock_with :rr` from `spec/spec_helper.rb`

## Configure RSpec

    RSpec.configure do |config|
      config.mock_with :rspec do |mocks|
        mocks.verify_partial_doubles = true
      end
    end

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

