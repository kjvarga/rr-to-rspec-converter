# Convert RR to RSpec mocks/stubs

This is a custom modification of the transpec tool to handle converting from [RR v1.1.2](https://github.com/rr/rr/blob/master/doc/03_api_overview.md) to [RSpec v3.6.0](https://relishapp.com/rspec/rspec-mocks/v/3-6/docs) mocks.

## Configure RSpec

    RSpec.configure do |config|
      config.mock_with :rspec do |mocks|
        mocks.verify_partial_doubles = true
      end
    end

## RR API

### #mock DONE
    1142 matches across 222 files

    mock(view).render.with_any_args.twice do |*args|
      if args.first == {:partial => "user_info"}
        "User Info"
      else
        "Stuff in the view #{args.inspect}"
      end
    end

    => expect(object).to receive(:method).with(arguments).and_return(return_val)

### #mock! DONE
    17 matches across 7 files
    /Users/kvarga/Projects/change/spec/controllers/account_settings_controller_spec.rb:
    /Users/kvarga/Projects/change/spec/controllers/soa/mailers_controller_spec.rb:
    /Users/kvarga/Projects/change/spec/lib/external_services/client_spec.rb:
    /Users/kvarga/Projects/change/spec/lib/photo_cropper_spec.rb:
    /Users/kvarga/Projects/change/spec/lib/sitemap_generator_spec.rb:
    /Users/kvarga/Projects/change/spec/workers/delete_payment_info_for_closed_user_accounts_worker_spec.rb:
    /Users/kvarga/Projects/change/spec/workers/petition_counters_worker_spec.rb:

    =>
      instance_double("ConsoleNotifier")
      class_double("ConsoleNotifier")
      [object_double(User.new, :save => true)](https://relishapp.com/rspec/rspec-mocks/docs/verifying-doubles/using-an-object-double)
      object_double("MyApp::LOGGER", :info => nil).as_stubbed_const

      Then assert expectations with `have_received` or `receive`.

### #stub DONE
    1227 matches across 241 files

    By itself:
    => [double](https://relishapp.com/rspec/rspec-mocks/v/3-8/docs/basics/partial-test-doubles)

    With method:
    => allow(object).to receive(:method).with(arguments).and_return(return_val)

### #stub! DONE
    5 matches across 5 files
    /Users/kvarga/Projects/change/spec/concerns/launch_member_sponsored_upsell_concern_spec.rb:
    /Users/kvarga/Projects/change/spec/controllers/login_controller_spec.rb:
    /Users/kvarga/Projects/change/spec/controllers/sitemaps_controller_spec.rb:
    /Users/kvarga/Projects/change/spec/controllers/soa/petition_ads_controller_spec.rb:
    /Users/kvarga/Projects/change/spec/models/event_invitation_spec.rb:

    =>
      instance_double("ConsoleNotifier")
      class_double("ConsoleNotifier")
      object_double(User.new, :save => true)
      object_double("MyApp::LOGGER", :info => nil).as_stubbed_const

### #dont_allow DONE
    162 matches across 62 files

    => expect(object).not_to receive(:method).with(args)

### #dont_allow! DONE
    0 matches

### #proxy DONE
    8 matches across 4 files
    /Users/kvarga/Projects/change/spec/lib/i18n/backend/local_from_s3_spec.rb:
    /Users/kvarga/Projects/change/spec/models/current_user_spec.rb:
    /Users/kvarga/Projects/change/spec/models/photo_spec.rb
    /Users/kvarga/Projects/change/spec/support/shared_contexts/stubbed_redshift.rb:

    =>
      and_call_original, or
      and_wrap_original

      allow(Calculator).to receive(:add).and_call_original
      allow(Calculator).to receive(:add).with(2, 3).and_return(-5)

      expect(API).to receive(:solve_for).and_wrap_original { |m, *args| m.call(*args).first(5) }
      expect(API.solve_for(100)).to eq [1,2,3,4,5]

### #proxy!
    0 matches

### #instance_of DONE
    3 matches across 2 files
    /Users/kvarga/Projects/change/spec/concerns/launch_member_sponsored_upsell_concern_spec.rb:
    /Users/kvarga/Projects/change/spec/controllers/petitions/signatures_controller_spec.rb:

    => instance_of

### #instance_of!
    0 matches

### #any_instance_of DONE
    194 matches across 80 files

    any_instance_of(User) do |u|
      stub(u).valid? { false }
    end
     or
    any_instance_of(User, :valid? => false)
     or
    any_instance_of(User, :valid? => lambda { false })

    =>
      Convert hash argument usage to block usage in these files:

      /Users/kvarga/Projects/change/spec/actions/send_petition_starter_commented_notifications_spec.rb
      /Users/kvarga/Projects/change/spec/controllers/admin/petitions/locale_settings_controller_spec.rb:
      /Users/kvarga/Projects/change/spec/controllers/admin/petitions/spam_management_controller_spec.rb:
      /Users/kvarga/Projects/change/spec/requests/i18n_request_spec.rb

      Then convert the block syntax to RSpec:

      allow_any_instance_of(klass).to receive_messages(:method => return_value)
      expect_any_instance_of(klass).to receive_messages(:method => return_value)
      allow_any_instance_of(klass).to receive(:method => return_value)
      expect_any_instance_of(klass).to receive(:method => return_value)


### #with_any_args DONE
    93 matches across 47 files

    mock(PetitionGroup).find.with_any_args.returns(petition_group)

    => with(any_args)

### #with_no_args DONE
    0 matches

    => with(no_args)

### #times DONE
    80 matches across 37 files

    =>
      times(1) => once
      times(2) => twice
      times(n) => times(n)

### #any_times  DONE
    11 matches across 8 files

    Usages:
    .any_times
    .times(any_times)

    => at_least(:once)

### #returns DONE
    130 matches across 34 files

    mock(PetitionGroup).find.with_any_args.returns(petition_group)

    => and_return

### #yields DONE
    0 matches

### #with DONE
    111 matches across 35 files

    => with

### #never DONE
    23 matches across 13 files

    => expect(object).not_to receive(:method)

### #once DONE
    36 matches across 15 files

    => once

### #at_least DONE
    15 matches across 11 files

    =>
      at_least(1)  => at_least(:once)
      at_least(2)  => at_least(:twice)
      at_least(n)  => at_least(n).times

### #at_most DONE
    10 matches across 2 files
    /Users/kvarga/Projects/change/spec/mailers/promotion_service_mailer_spec.rb
    /Users/kvarga/Projects/change/spec/models/signature_spec.rb:

    =>
      at_most(1)  => at_most(:once)
      at_most(2)  => at_most(:twice)
      at_most(n)  => at_most(n).times

## Matchers

### #anything DONE
    237 matches across 79 files

    => anything

### #is_a DONE
    26 matches across 12 files

    => kind_of

### #numeric DONE
    1 matches in 1 file
    /Users/kvarga/Projects/change/spec/controllers/petitions/signatures_controller_spec.rb

    => kind_of(Numeric)

### #boolean DONE
    0 matches

    => boolean

### #duck_type DONE
    0 matches

    => duck_type

### #hash_including DONE
    50 matches across 16 files

    => hash_including

### #rr_satisfy DONE
    10 matches across 8 files

    => satisfy

    Use RSpec satisfy method.  Would need to rewrite to use arguments from block, which alters the intent of the test.  I think this will need to be done manually.

# Module References

### RR::WildcardMatchers::HashIncluding  DONE

    => hash_including

### RR::WildcardMatchers::Satisfy DONE

    => rr_satisfy

### RR.reset DONE
    /Users/kvarga/Projects/change/spec/workers/handle_sfmc_inactives_worker_spec.rb

    => remove

# Other

Remove all comments that reference /\brr\b/i
Remove 'rr' from Gemfile
Remove `config.mock_with :rr` from `spec/spec_helper.rb`

# RSpec API

and_return
and_raise
and_throw
and_yield
and_call_original
and_wrap_original










--------------------------------------------------------------------------------------------------

# Rails5 Spec Converter

[![Build Status](https://travis-ci.org/tjgrathwell/rails5-spec-converter.svg?branch=master)](https://travis-ci.org/tjgrathwell/rails5-spec-converter)

A script that fixes the syntax of your tests so Rails 5 will like them better. Inspired by [transpec](https://github.com/yujinakayama/transpec), the RSpec 2 -> 3 syntax conversion tool.

If you write a test like this:

```
get :users, search: 'bayleef', format: :json
expect(response).to be_success
```

Rails 5 will issue a hearty deprecation warning, persuading you to write this instead:

```
get :users, params: { search: 'bayleef' }, format: :json
expect(response).to be_success
```

This is great! That syntax is great. However, if you have a thousand tests lying around, it will probably be very time consuming to find all the places where you need to fix that.

## Installation

Install the gem standalone like so:

    $ gem install rails5-spec-converter

## Usage

Make sure you've committed everything to Git first, then

    $ cd some-project
    $ rails5-spec-converter

This will update all the files in that directory matching the globs `spec/**/*_spec.rb` or `test/**/*_test.rb`.

If you want to specify a specific set of files instead, you can run `rails5-spec-converter path_to_my_files`.

By default it will make some noise, run with `rails5-spec-converter --quiet` if you want it not to.

### Whitespace

#### Indentation

The tool will attempt to indent the newly-added "params" hash in situations when the arguments are on newlines, e.g.:

```
  get :index
      search: 'bayleef',
      format: :json
```

becomes

```
  get :index
      params: {
        search: 'bayleef'
      },
      format: :json
```

Since the extra spaces in front of 'params' are brand-new whitespace, you may want to configure them (default is 2 spaces).

`rails5-spec-converter --indent '    '`

`rails5-spec-converter --indent '\t'`

#### Hash Spacing

By default, for single-line hashes, a single space will be added after the opening curly brace and before the ending curly brace. The space will be omitted if the new params hash will contain any hash literals that do not have surrounding whitespace, ex:

```
post :users, user: {name: 'bayleef'}
```

becomes

```
post :users, params: {user: {name: 'bayleef'}}
```

* `--no-hash-spacing` will force hashes to be written **without** extra whitespace in all files regardless of context.

* `--hash-spacing` will force hashes to be written **with** extra whitespace in all files regardless of context.

## Compatibility

It **should** work for both RSpec and MiniTest, but who really knows?

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tjgrathwell/rails5-spec-converter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## Contact

If this Gem helped you out at all, or it didn't help because you wanted it to do something different or it broke all your computer code, please let me know on twitter [@tjgrathwell](http://twitter.com/tjgrathwell)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

