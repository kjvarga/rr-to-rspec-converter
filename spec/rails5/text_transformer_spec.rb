require 'spec_helper'

describe Rails5::SpecConverter::TextTransformer do
  let(:controller_spec_file_path) { 'spec/controllers/test_spec.rb' }
  let(:request_spec_file_path) { 'spec/requests/test_spec.rb' }

  def transform(text, options = nil)
    if options
      described_class.new(text, options).transform
    else
      described_class.new(text).transform
    end
  end

  def quiet_transform(text)
    options = TextTransformerOptions.new
    options.quiet = true
    transform(text, options)
  end

  describe 'dont_allow' do
    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        dont_allow(GeoNames).timezone_from_lat_lng
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(GeoNames).not_to receive(:timezone_from_lat_lng)
      RUBY
    end

    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        dont_allow(Fluent::Logger).post('monorail.signature.resend_email', anything)
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(Fluent::Logger).not_to receive(:post).with('monorail.signature.resend_email', anything)
      RUBY
    end

    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        dont_allow(OrganizationMailer).optins_downloaded.with(any_args)
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(OrganizationMailer).not_to receive(:optins_downloaded).with(any_args)
      RUBY
    end
  end

  describe 'stub' do
    it 'converts to allow' do
      result = transform(<<-RUBY)
        stub(Fluent::Logger).post('monorail.petition_starter.petition_comment.created.onsite', anything)
      RUBY

      expect(result).to eq(<<-RUBY)
        allow(Fluent::Logger).to receive(:post).with('monorail.petition_starter.petition_comment.created.onsite', anything)
      RUBY
    end

    it 'converts to allow' do
      result = transform(<<-RUBY)
        stub(controller).get_or_set_user_tracker_uuid_for_current_user
      RUBY

      expect(result).to eq(<<-RUBY)
        allow(controller).to receive(:get_or_set_user_tracker_uuid_for_current_user)
      RUBY
    end

    it 'converts to allow' do
      result = transform(<<-RUBY)
        stub(controller).sponsorship_form_shown_recently? { sponsorship_form_shown_recently }.at_least(:once)
      RUBY

      expect(result).to eq(<<-RUBY)
        allow(controller).to receive(:sponsorship_form_shown_recently?) { sponsorship_form_shown_recently }.at_least(:once)
      RUBY
    end
  end

  describe 'mock' do
    it 'converts to expect' do
      result = transform(<<-RUBY)
        mock(Fluent::Logger).post('monorail.petition_starter.petition_comment.created.onsite', anything)
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(Fluent::Logger).to receive(:post).with('monorail.petition_starter.petition_comment.created.onsite', anything)
      RUBY
    end

    it 'converts to expect' do
      result = transform(<<-RUBY)
        mock(controller).get_or_set_user_tracker_uuid_for_current_user
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(controller).to receive(:get_or_set_user_tracker_uuid_for_current_user)
      RUBY
    end

    it 'converts to expect' do
      result = transform(<<-RUBY)
        mock(controller).sponsorship_form_shown_recently? { sponsorship_form_shown_recently }.at_least(:once)
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(controller).to receive(:sponsorship_form_shown_recently?) { sponsorship_form_shown_recently }.at_least(:once)
      RUBY
    end
  end

  describe 'any_instance_of' do
    context 'with hash argument' do
      it 'converts to block syntax' do
        result = transform(<<-RUBY)
          any_instance_of(User, :valid? => false, admin: true)
        RUBY

        expect(result).to eq(<<-RUBY)
          any_instance_of(User) do |o|
            stub(o).valid?.and_return(false)
            stub(o).admin.and_return(true)
          end
        RUBY
      end
    end
  end

  describe 'RR.reset' do
    it 'removes the line' do
      result = transform(<<-RUBY.strip_heredoc)
        RR.reset
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)

      RUBY
    end

    it 'removes the statement' do
      result = transform(<<-RUBY.strip_heredoc)
        RR.reset; something = :foo;
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        something = :foo;
      RUBY
    end
  end

  describe 'rr_satisfy' do
    it 'converts to satisfy' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(rr_satisfy(params: 1)).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(satisfy(params: 1)).something
      RUBY
    end

    it 'converts to satisfy' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(rr_satisfy( {params: 1} )).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(satisfy( {params: 1} )).something
      RUBY
    end
  end

  describe 'RR::WildcardMatchers::Satisfy' do
    it 'converts to satisfy' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(RR::WildcardMatchers::Satisfy.new( {params: 1} )).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(rr_satisfy( {params: 1} )).something
      RUBY
    end
  end

  describe 'RR::WildcardMatchers::HashIncluding' do
    it 'converts to hash_including' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(RR::WildcardMatchers::HashIncluding.new(params: 1)).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(hash_including(params: 1)).something
      RUBY
    end

    it 'converts to hash_including' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(RR::WildcardMatchers::HashIncluding.new( {params: 1} )).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(hash_including( {params: 1} )).something
      RUBY
    end
  end

  describe 'numeric' do
    it 'converts to kind_of(Numeric)' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(numeric).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(kind_of(Numeric)).something
      RUBY
    end
  end

  describe 'is_a' do
    it 'converts to kind_of' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(is_a(User)).something
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with(kind_of(User)).something
      RUBY
    end
  end

  describe 'at_most' do
    context 'when 1' do
      it 'converts to at_most(:once)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(1)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(:once)
        RUBY
      end

      it 'converts to at_most(:once)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(1).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(:once).something
        RUBY
      end
    end

    context 'when 2' do
      it 'converts to at_most(:twice)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(2)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(:twice)
        RUBY
      end

      it 'converts to at_most(:twice)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(2).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(:twice).something
        RUBY
      end
    end

    context 'when greater than 2' do
      it 'converts to at_most(n).times' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(3)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(3).times
        RUBY
      end

      it 'converts to at_most(n).times' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(3).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_most(3).times.something
        RUBY
      end
    end
  end

  describe 'at_least' do
    context 'when 1' do
      it 'converts to at_least(:once)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(1)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(:once)
        RUBY
      end

      it 'converts to at_least(:once)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(1).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(:once).something
        RUBY
      end
    end

    context 'when 2' do
      it 'converts to at_least(:twice)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(2)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(:twice)
        RUBY
      end

      it 'converts to at_least(:twice)' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(2).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(:twice).something
        RUBY
      end
    end

    context 'when greater than 2' do
      it 'converts to at_least(n).times' do
        result = transform(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(3)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect(UsersService).not_to receive(:update).with.at_least(3).times
        RUBY
      end
    end
  end

  describe 'times' do
    context 'when argument is 1' do
      it 'converts to once' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times(1).something
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).once.something
        RUBY
      end
    end

    context 'when argument is 1 with spaces' do
      it 'converts to once' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times  1
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).once
        RUBY
      end
    end

    context 'when argument is 2' do
      it 'converts to twice' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times(2)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).twice
        RUBY
      end
    end

    context 'when argument is greater than 2' do
      it 'does not modify it' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times(3)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times(3)
        RUBY
      end
    end
  end

  describe 'returns' do
    context 'when no parentheses' do
      it 'converts to and_return and doesn\'t modify parentheses' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).returns argument
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).and_return argument
        RUBY
      end
    end

    it 'converts to and_return' do
      result = transform(<<-RUBY.strip_heredoc)
        allow(User).to receive(:find_by_param).with(user.id.to_s).returns(nil)
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        allow(User).to receive(:find_by_param).with(user.id.to_s).and_return(nil)
      RUBY
    end

    context 'when an intermediate method' do
      it 'converts to and_return' do
        result = transform(<<-RUBY.strip_heredoc)
          mock!.headers({}).returns(header: 'value').subject
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          mock!.headers({}).and_return(header: 'value').subject
        RUBY
      end
    end
  end

  describe 'any_times' do
    it 'converts to at_least(:once) when trailing method' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with.any_times
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with.at_least(:once)
      RUBY
    end

    it 'converts to at_least(:once) with block' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(controller).to receive(:create_new_user).any_times { user }
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(controller).to receive(:create_new_user).at_least(:once) { user }
      RUBY
    end

    it 'converts to at_least(:once) when an intermediate method' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).any_times.something(petition_group)
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).at_least(:once).something(petition_group)
      RUBY
    end

    it 'converts to at_least(:once) when there is extra whitespace' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).any_times.
            something(petition_group)
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).at_least(:once).
            something(petition_group)
      RUBY
    end
  end

  describe 'with_any_args' do
    it 'converts to with(any_args) when trailing method' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with.with_any_args
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(UsersService).not_to receive(:update).with.with(any_args)
      RUBY
    end

    it 'converts to with(any_args) with block' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(controller).to receive(:create_new_user).with_any_args { user }
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(controller).to receive(:create_new_user).with(any_args) { user }
      RUBY
    end

    it 'converts to with(any_args) when an intermediate method' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).with_any_args.something(petition_group)
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).with(any_args).something(petition_group)
      RUBY
    end

    it 'converts to with(any_args) when there is extra whitespace' do
      result = transform(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).with_any_args.
            something(petition_group)
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        expect(PetitionGroup).to receive(:find).with(any_args).
            something(petition_group)
      RUBY
    end
  end

  describe 'unparsable ruby' do
    let(:unparsable_content) do
      <<-RUBYISH
        gibberish do
      RUBYISH
    end

    it 'leaves unparsable ruby alone' do
      expect(quiet_transform(unparsable_content)).to eq(unparsable_content)
    end

    it 'prints a warning message' do
      expect {
        transform(unparsable_content)
      }.to output(/unparsable/i).to_stdout
    end
  end

  # it 'leaves invocations with no arguments undisturbed' do
  #   test_content = <<-RUBY
  #     get :index
  #   RUBY
  #   expect(transform(test_content)).to eq(test_content)
  # end

  # it 'leaves invocations with only permitted keys undisturbed' do
  #   test_content = <<-RUBY
  #     get :index, format: :json
  #   RUBY
  #   expect(transform(test_content)).to eq(test_content)
  # end

  # it 'leaves invocations that already have a "params" key undisturbed' do
  #   test_content = <<-RUBY
  #     post :create, params: {token: build.token}, headers: {'X-PANCAKE' => 'banana'}
  #   RUBY
  #   expect(transform(test_content)).to eq(test_content)
  # end

  # it 'can add "params: {}" if an empty hash of arguments is present' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, {}
  #     end
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, params: {}
  #     end
  #   RUBY
  # end

  # it 'can add "params: {}" around hashes that contain a double-splat' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     get :index, **index_params, order: 'asc', format: :json
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     get :index, params: { **index_params, order: 'asc' }, format: :json
  #   RUBY
  # end

  # it 'can add "params: {}" around multiline hashes that contain a double-splat' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     let(:retrieve_index) do
  #       get :index, order: 'asc',
  #                   **index_params,
  #                   format: :json
  #     end
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     let(:retrieve_index) do
  #       get :index, params: {
  #                     order: 'asc',
  #                     **index_params
  #                   },
  #                   format: :json
  #     end
  #   RUBY
  # end

  # it 'can add "params: {}" when only unpermitted keys are present' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, search: 'bayleef'
  #     end
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, params: { search: 'bayleef' }
  #     end
  #   RUBY
  # end

  # it 'can add "params: {}" when both permitted and unpermitted keys are present' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, search: 'bayleef', format: :json
  #     end
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, params: { search: 'bayleef' }, format: :json
  #     end
  #   RUBY
  # end

  # describe 'controller tests' do
  #   let(:controllery_file_options) do
  #     TextTransformerOptions.new.tap do |options|
  #       options.file_path = controller_spec_file_path
  #     end
  #   end

  #   describe 'session and flash params' do
  #     it 'assigns additional positional arguments as "session" and "flash"' do
  #       result = transform(<<-RUBY.strip_heredoc, controllery_file_options)
  #         get :index, {search: 'bayleef'}, {'session_property' => 'banana'}, {info: 'Great Search!'}
  #       RUBY

  #       expect(result).to eq(<<-RUBY.strip_heredoc)
  #         get :index, params: {search: 'bayleef'}, session: {'session_property' => 'banana'}, flash: {info: 'Great Search!'}
  #       RUBY
  #     end
  #   end
  # end

  # describe 'request tests' do
  #   let(:requesty_file_options) do
  #     TextTransformerOptions.new.tap do |options|
  #       options.file_path = request_spec_file_path
  #     end
  #   end

  #   describe 'header params' do
  #     it 'assigns additional arguments as "headers"' do
  #       result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
  #         get :index, {search: 'bayleef'}, {'X-PANCAKE' => 'banana'}
  #       RUBY

  #       expect(result).to eq(<<-RUBY.strip_heredoc)
  #         get :index, params: {search: 'bayleef'}, headers: {'X-PANCAKE' => 'banana'}
  #       RUBY
  #     end

  #     it 'adds "params" and "header" keys regardless of surrounding whitespace' do
  #       result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
  #         get :index, {
  #           search: 'bayleef'
  #         }, {
  #           'X-PANCAKE' => 'banana'
  #         }
  #       RUBY

  #       expect(result).to eq(<<-RUBY.strip_heredoc)
  #         get :index, params: {
  #           search: 'bayleef'
  #         }, headers: {
  #           'X-PANCAKE' => 'banana'
  #         }
  #       RUBY
  #     end

  #     it 'wraps header args in curly braces if they are not already present' do
  #       result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
  #         get :show, nil, 'X-BANANA' => 'pancake'
  #       RUBY

  #       expect(result).to eq(<<-RUBY.strip_heredoc)
  #         get :show, headers: { 'X-BANANA' => 'pancake' }
  #       RUBY
  #     end
  #   end
  # end

  # it 'keeps hashes tightly packed if the existing source has any tightly-packed hashes in it' do
  #   result = transform(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, {search: 'bayleef', format: :json}
  #     end
  #   RUBY

  #   expect(result).to eq(<<-RUBY.strip_heredoc)
  #     it 'executes the controller action' do
  #       get :index, params: {search: 'bayleef'}, format: :json
  #     end
  #   RUBY
  # end

  # describe 'preserving whitespace' do
  #   it 'preserves hash indentation if the hash starts on a new line' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       it 'executes the controller action' do
  #         post :create, {
  #           color: 'blue',
  #           style: 'striped'
  #         }
  #       end
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       it 'executes the controller action' do
  #         post :create, params: {
  #           color: 'blue',
  #           style: 'striped'
  #         }
  #       end
  #     RUBY
  #   end

  #   describe 'request tests' do
  #     let(:requesty_file_options) do
  #       TextTransformerOptions.new.tap do |options|
  #         options.file_path = request_spec_file_path
  #       end
  #     end

  #     it 'preserves hash indentation if the hash starts on a new line and a headers hash is present' do
  #       result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
  #         post :create, {
  #           color: 'blue',
  #           size: {
  #             width: 10
  #           }
  #         }, {
  #           'header' => 'value'
  #         }
  #       RUBY

  #       expect(result).to eq(<<-RUBY.strip_heredoc)
  #         post :create, params: {
  #           color: 'blue',
  #           size: {
  #             width: 10
  #           }
  #         }, headers: {
  #           'header' => 'value'
  #         }
  #       RUBY
  #     end
  #   end

  #   it 'indents hashes appropriately if they start on the same line as the action' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       post :show, branch_name: 'new_design3',
  #                   ref: 'foo',
  #                   format: :json
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       post :show, params: {
  #                     branch_name: 'new_design3',
  #                     ref: 'foo'
  #                   },
  #                   format: :json
  #     RUBY
  #   end

  #   it 'indents hashes appropriately if they start on a new line' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       post :show,
  #            branch_name: 'new_design3',
  #            ref: 'foo',
  #            format: :json
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       post :show,
  #            params: {
  #              branch_name: 'new_design3',
  #              ref: 'foo'
  #            },
  #            format: :json
  #     RUBY
  #   end

  #   it 'indents hashes appropriately if they start on a new line and contain indented content' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       put :update,
  #         id: @rubygem.to_param,
  #         linkset: {
  #           code: @url
  #         },
  #         format: :json
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       put :update,
  #         params: {
  #           id: @rubygem.to_param,
  #           linkset: {
  #             code: @url
  #           }
  #         },
  #         format: :json
  #     RUBY
  #   end

  #   describe 'inconsistent hash spacing' do
  #     describe 'when a hash has inconsistent indentation' do
  #       it 'rewrites hashes as single-line if the first two pairs are on the same line' do
  #         result = quiet_transform(<<-RUBY.strip_heredoc)
  #           let(:perform_action) do
  #             post :search,
  #               type: 'fire', limit: 10,
  #               order: 'asc'
  #           end
  #         RUBY

  #         expect(result).to eq(<<-RUBY.strip_heredoc)
  #           let(:perform_action) do
  #             post :search,
  #               params: { type: 'fire', limit: 10, order: 'asc' }
  #           end
  #         RUBY
  #       end
  #     end
  #   end

  #   it 'indents hashes appropriately if they start on the first line but contain indented content' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       describe 'important stuff' do
  #         let(:perform_action) do
  #           post :mandrill, mandrill_events: [{
  #             "event" => "hard_bounce"
  #           }]
  #         end
  #       end
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       describe 'important stuff' do
  #         let(:perform_action) do
  #           post :mandrill, params: {
  #             mandrill_events: [{
  #               "event" => "hard_bounce"
  #             }]
  #           }
  #         end
  #       end
  #     RUBY
  #   end
  # end

  # describe 'trailing commas' do
  #   it 'preserves trailing commas if they exist in any of the transformed hashes' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       let(:perform_request) do
  #         post :show, {
  #           branch_name: 'new_design3',
  #           ref: 'foo',
  #           format: :json,
  #         }
  #       end
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       let(:perform_request) do
  #         post :show, {
  #           params: {
  #             branch_name: 'new_design3',
  #             ref: 'foo',
  #           },
  #           format: :json,
  #         }
  #       end
  #     RUBY
  #   end
  # end

  # describe 'things that look like route definitions' do
  #   it 'leaves invocations that look like route definitions undisturbed' do
  #     test_content_stringy = <<-RUBY
  #       get 'profile', to: 'users#show'
  #     RUBY
  #     expect(transform(test_content_stringy)).to eq(test_content_stringy)

  #     test_content_hashy = <<-RUBY
  #       get 'profile', to: :show, controller: 'users'
  #     RUBY
  #     expect(transform(test_content_hashy)).to eq(test_content_hashy)
  #   end

  #   it 'adds "params" to invocations that have the key `to` but are not route definitions' do
  #     result = transform(<<-RUBY.strip_heredoc)
  #       get 'users', from: yesterday, to: today
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       get 'users', params: { from: yesterday, to: today }
  #     RUBY
  #   end
  # end

  # describe 'optional configuration' do
  #   it 'allows a custom indent to be set' do
  #     options = TextTransformerOptions.new
  #     options.indent = '    '

  #     result = transform(<<-RUBY.strip_heredoc, options)
  #       post :show, branch_name: 'new_design3',
  #                   ref: 'foo'
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       post :show, params: {
  #                       branch_name: 'new_design3',
  #                       ref: 'foo'
  #                   }
  #     RUBY
  #   end

  #   it 'allows extra spaces whitespace in hashes to be forced off' do
  #     options = TextTransformerOptions.new
  #     options.hash_spacing = false

  #     result = transform(<<-RUBY.strip_heredoc, options)
  #       get :index, search: 'bayleef', format: :json
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       get :index, params: {search: 'bayleef'}, format: :json
  #     RUBY
  #   end

  #   it 'allows extra spaces whitespace in hashes to be forced on' do
  #     options = TextTransformerOptions.new
  #     options.hash_spacing = true

  #     result = transform(<<-RUBY.strip_heredoc, options)
  #       post :users, user: {name: 'bayleef'}
  #     RUBY

  #     expect(result).to eq(<<-RUBY.strip_heredoc)
  #       post :users, params: { user: {name: 'bayleef'} }
  #     RUBY
  #   end

  #   describe 'warning about inconsistent indentation' do
  #     it 'produces warnings if hashes have inconsistent separators between pairs' do
  #       inconsistent_spacing_example = <<-RUBY
  #         post :users, name: 'SampleUser', email: 'sample@example.com',
  #                      role: Roles::User
  #       RUBY

  #       expect {
  #         transform(inconsistent_spacing_example)
  #       }.to output(/inconsistent/i).to_stdout
  #     end
  #   end
  # end
end
