# == Schema Information
#
# Table name: announcement_recipients
#
#  id              :integer          not null, primary key
#  user_id         :integer
#  announcement_id :integer
#

class AnnouncementRecipient < ActiveRecord::Base

    has_paper_trail

  belongs_to :user, class_name: "User"
  belongs_to :announcement
end
