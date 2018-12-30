require 'spec_helper'

describe SendPetitionStarterCommentedNotifications do
  let(:petition_starter) { FactoryGirl.create(:user) }
  let(:petition) { FactoryGirl.create(:petition, user_id: petition_starter.id) }
  let(:dm_response) { FactoryGirl.create(:petition_target_response) }
  let(:petition_comment) { FactoryGirl.create(:opinion, commentable_type: 'Event', commentable_id: petition.id, user_id: petition_starter.id) }
  let(:dm_response_comment) { FactoryGirl.create(:opinion, commentable_type: 'PetitionTargetResponse', commentable_id: dm_response.id, user_id: petition_starter.id) }
  let(:child_comment) { FactoryGirl.create(:opinion, parent_id: petition_comment.id, user_id: petition_starter.id) }

  def dont_allow_email_notification
    stub(Resque).enqueue_in
    mock(Resque).enqueue_in.with(anything, PetitionStarterCommentedEmailWorker).never
  end

  def dont_allow_onsite_notification
    stub(Fluent::Logger).post
    mock(Fluent::Logger).post.with(anything).never
  end

  def dont_allow_any_notifications
    dont_allow_email_notification
    dont_allow_onsite_notification
  end

  describe '#initialize' do
    context 'when not passing a comment param' do
      it 'raises an error' do
        expect { described_class.new }.to raise_error(ArgumentError, 'missing keyword: comment')
      end
    end
  end

  describe '#send_notifications' do
    before do
      Rails.app.feature_config_manager.set(FeatureConfig.new(id: 'petition_starter_comment_email_notif', group: 'en-US', type: 'boolean', value: true))
    end

    context 'when not initialized with a commentable entity' do
      it 'gets the commentable entity from the comment' do
        described_class.new(comment: petition_comment).send_notifications
        assert_queued_in(24.hours, PetitionStarterCommentedEmailWorker, [petition_comment.user_id, petition_comment.commentable_type, petition.id, petition_comment.created_at])
      end

      context 'when the commentable entity does not exist' do
        let(:comment) { FactoryGirl.build(:opinion, commentable_type: 'Event', commentable_id: 12_345, user_id: petition_starter.id) }

        it 'raises an ActiveRecord::NotFound error' do
          expect { described_class.new(comment: comment) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'when the comment is a child' do
      it 'does not send any notifications' do
        dont_allow_any_notifications
        described_class.new(comment: child_comment, commentable_entity: petition).send_notifications
      end
    end

    context 'when the comment is not on a petition' do
      it 'does not send any notifications' do
        dont_allow_any_notifications
        described_class.new(comment: dm_response_comment, commentable_entity: petition).send_notifications
      end
    end

    context 'when the commenter is not the petition starter' do
      let(:non_petition_starter) { FactoryGirl.create(:user) }
      let(:petition_comment) { FactoryGirl.create(:opinion, commentable_type: 'Event', commentable_id: petition.id, user_id: non_petition_starter.id) }

      it 'does not send any notifications' do
        dont_allow_any_notifications
        described_class.new(comment: petition_comment, commentable_entity: petition)
      end
    end

    context 'when sending an email notification' do
      it 'enqueues an email notification worker' do
        described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
        assert_queued_in(24.hours, PetitionStarterCommentedEmailWorker, [petition_comment.user_id, petition_comment.commentable_type, petition.id, petition_comment.created_at])
        Resque.run!
      end

      context 'when the feature config is not enabled' do
        before do
          Rails.app.feature_config_manager.set(FeatureConfig.new(id: 'petition_starter_comment_email_notif', group: 'en-US', type: 'boolean', value: false))
        end

        it 'does not enqueue a worker' do
          dont_allow_email_notification
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
        end
      end

      context 'when the total recipient count exceeds the SFMC limit' do
        before do
          Rails.app.redis.set(:max_petition_update_size_for_sfmc, 1)
          any_instance_of(Petition, total_signature_count: 2)
        end

        it 'does not enqueue a worker' do
          dont_allow_email_notification
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
        end
      end

      context 'when there is already a worker set to run' do
        it 'does not enqueue another worker' do
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
          expect(Resque.queue(:delayed).length).to be(1)
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
          expect(Resque.queue(:delayed).length).to be(1)
        end

        it 'sets a ttl on the redis key' do
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
          expect(Rails.app.redis.ttl("petition-starter-commented-on-Event-#{petition.id}-email-worker-queued")).to be > 24.hours.seconds
        end
      end

      context 'when there is a feature config for the email delay' do
        expected_delay_time = 10.seconds

        before do
          feature_config = FeatureConfig.new(id: 'petition_starter_commented_email_noti_delay_seconds', type: 'number', value: expected_delay_time)
          Rails.app.feature_config_manager.create(feature_config)
        end

        it 'uses that instead of the default 24.hours' do
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
          assert_queued_in(expected_delay_time, PetitionStarterCommentedEmailWorker, [petition_comment.user_id, petition_comment.commentable_type, petition.id, petition_comment.created_at])
        end
      end
    end

    context 'when sending an onsite notification' do
      before do
        Rails.app.feature_config_manager.set(FeatureConfig.new(id: 'petition_starter_comment_onsite_notif', group: 'en-US', type: 'boolean', value: true))
      end

      it 'sends a fluent event' do
        mock(Fluent::Logger).post('monorail.petition_starter.petition_comment.created.onsite', petition_id: petition.id, comment_id: petition_comment.id, created_at: petition_comment.created_at)
        described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
      end

      context 'when the feature is not enabled' do
        before do
          Rails.app.feature_config_manager.set(FeatureConfig.new(id: 'petition_starter_comment_onsite_notif', group: 'en-US', type: 'boolean', value: false))
        end

        it 'does not send a fluent event' do
          stub(Fluent::Logger).post
          mock(Fluent::Logger).post('monorail.petition_starter.petition_comment.created.onsite', anything).never
          described_class.new(comment: petition_comment, commentable_entity: petition).send_notifications
        end
      end
    end
  end
end
