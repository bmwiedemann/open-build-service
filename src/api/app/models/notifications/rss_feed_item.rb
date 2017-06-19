class Notifications::RssFeedItem < Notifications::Base
  MAX_ITEMS_PER_USER = 10
  MAX_ITEMS_PER_GROUP = 10

  def self.cleanup
    User.all_without_nobody.find_in_batches batch_size: 500 do |batch|
      batch.each do |user|
        offset = user.is_active? ? MAX_ITEMS_PER_USER : 0
        ids = user.rss_feed_items.offset(offset).pluck(:id)
        user.rss_feed_items.where(id: ids).delete_all
      end
    end
    Group.find_in_batches batch_size: 500 do |batch|
      batch.each do |group|
        ids = group.rss_feed_items.offset(MAX_ITEMS_PER_GROUP).pluck(:id)
        group.rss_feed_items.where(id: ids).delete_all
      end
    end
  end

  def title
    event.subject
  end

  def description
    ApplicationController.renderer.new.render(
      template: "event_mailer/#{event.template_name}",
      layout: false,
      format: :txt,
      assigns: { e: event.expanded_payload, host: ::Configuration.obs_url, configuration: ::Configuration.first })
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                         :integer          not null, primary key
#  user_id                    :integer          indexed
#  group_id                   :integer          indexed
#  type                       :string(255)      not null
#  event_type                 :string(255)      not null
#  event_payload              :text(65535)      not null
#  subscription_receiver_role :string(255)      not null
#  delivered                  :boolean          default(FALSE)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_notifications_on_group_id  (group_id)
#  index_notifications_on_user_id   (user_id)
#
