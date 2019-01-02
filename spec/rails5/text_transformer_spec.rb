require 'spec_helper'

describe Rails5::SpecConverter::TextTransformer do
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

  describe 'a complex file' do
    it 'converts correctly' do
      contents = File.read(File.expand_path('../../support/complex_file_test.rb', __FILE__))
      expected = File.read(File.expand_path('../../support/complex_file_test_result.rb', __FILE__))
      result = transform(contents)
      expect(result).to eq(expected)
    end
  end

  describe 'never' do
    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        mock(GeoNames).timezone_from_lat_lng.never
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(GeoNames).not_to receive(:timezone_from_lat_lng)
      RUBY
    end

    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        mock(Tag).update_all({ discoverable: true }, anything).never
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(Tag).not_to receive(:update_all).with({ discoverable: true }, anything)
      RUBY
    end

    it 'converts to expect().not_to receive' do
      result = transform(<<-RUBY)
        mock(LoggedEvent).fire_fluentd(anything, anything).never
      RUBY

      expect(result).to eq(<<-RUBY)
        expect(LoggedEvent).not_to receive(:fire_fluentd).with(anything, anything)
      RUBY
    end
  end

  describe 'dont_allow' do
    context 'with argument' do
      it 'converts to expect().not_to receive' do
        result = transform(<<-RUBY)
          dont_allow(GeoNames, :timezone_from_lat_lng)
        RUBY

        expect(result).to eq(<<-RUBY)
          expect(GeoNames).not_to receive(:timezone_from_lat_lng)
        RUBY
      end
    end

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
    context 'with no method call' do
      it 'assumes Kernel' do
        result = transform(<<-RUBY)
          stub(rand) { 1 }
        RUBY

        expect(result).to eq(<<-RUBY)
          allow(Kernel).to receive(:rand) { 1 }
        RUBY
      end
    end

    context 'by itself' do
      it 'converts to double' do
        result = transform(<<-RUBY)
          request = stub
        RUBY

        expect(result).to eq(<<-RUBY)
          request = double
        RUBY
      end
    end

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
    context 'by itself' do
      it 'converts to double' do
        result = transform(<<-RUBY)
          request = mock
        RUBY

        expect(result).to eq(<<-RUBY)
          request = double
        RUBY
      end
    end

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
    pending 'dont_allow' do
      it 'rewrites as expect().not_to receive' do
        result = transform(<<-RUBY)
          any_instance_of(User) do |o|
            dont_allow(o).valid?
            stub(o).admin.and_return(true)
          end
        RUBY

        expect(result).to eq(<<-RUBY)
          expect_any_instance_of(User).to receive(:valid?).and_return(false)
            allow_any_instance_of(User).to receive(:admin).and_return(true)
        RUBY
      end
    end

    context 'with block argument' do
      it 'rewrites each inner expect and allow' do
        result = transform(<<-RUBY)
          any_instance_of(User) do |o|
            mock(o).valid?.and_return(false)
            stub(o).admin.and_return(true)
          end
        RUBY

        expect(result).to eq(<<-RUBY)
          expect_any_instance_of(User).to receive(:valid?).and_return(false)
            allow_any_instance_of(User).to receive(:admin).and_return(true)
        RUBY
      end

      it 'rewrites each inner expect and allow' do
        result = transform(<<-RUBY)
          any_instance_of(User) { |o| mock(o).valid? { false }; stub(o).admin { true } }
        RUBY

        expect(result).to eq(<<-RUBY)
          expect_any_instance_of(User).to receive(:valid?) { false }; allow_any_instance_of(User).to receive(:admin) { true }
        RUBY
      end

      it 'rewrites correctly' do
        result = transform(<<-RUBY)
          any_instance_of(Facebook::Cookie) do |facebook_cookie|
            mock(facebook_cookie).user_id.never { facebook_id }
            stub(facebook_cookie).access_token { access_token }
          end
        RUBY

        expect(result).to eq(<<-RUBY)
          expect_any_instance_of(Facebook::Cookie).not_to receive(:user_id) { facebook_id }
            allow_any_instance_of(Facebook::Cookie).to receive(:access_token) { access_token }
        RUBY
      end

      it 'rewrites correctly' do
        result = transform(<<-RUBY)
          any_instance_of(ApiConsumer) do |c|
            stub(c).update_status(anything) { false }
          end
        RUBY

        expect(result).to eq(<<-RUBY)
          allow_any_instance_of(ApiConsumer).to receive(:update_status).with(anything) { false }
        RUBY
      end
    end

    context 'with hash argument' do
      it 'converts to block syntax' do
        result = transform(<<-RUBY)
          any_instance_of(User, :valid? => false, admin: true)
        RUBY

        expect(result).to eq(<<-RUBY)
          allow_any_instance_of(User).to receive(:valid?).and_return(false)
          allow_any_instance_of(User).to receive(:admin).and_return(true)
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
    context 'when no argument' do
      it 'leaves it unmodified' do
        result = transform(<<-RUBY.strip_heredoc)
          2.times
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          2.times
        RUBY
      end
    end

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

    context 'when argument is any_times' do
      it 'converts to at_least(:once)' do
        result = transform(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).times(any_times)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          allow(controller).to receive(:ga_first_click_attribution).at_least(:once)
        RUBY
      end
    end

    context 'when argument is 0' do
      it 'converts to expect().not_to receive()' do
        result = transform(<<-RUBY.strip_heredoc)
          any_instance_of(User) { |u| mock(u).find.with(anything).times(0) }
          mock(controller).ga_first_click_attribution(anything).times(0)
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          expect_any_instance_of(User).not_to receive(:find).with(anything)
          expect(controller).not_to receive(:ga_first_click_attribution).with(anything)
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
end
