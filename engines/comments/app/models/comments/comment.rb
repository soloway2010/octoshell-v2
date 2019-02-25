# == Schema Information
#
# Table name: comments_comments
#
#  id              :integer          not null, primary key
#  text            :text
#  attachable_id   :integer          not null
#  attachable_type :string           not null
#  user_id         :integer          not null
#  context_id      :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

module Comments
  class Comment < ActiveRecord::Base

    has_paper_trail

    include Attachable
    DEFAUlT_PER = 10
    validates :text, presence: true

    def self.all_records_to_json_view(hash)
      hash[:per] ||= DEFAUlT_PER
      hash[:includes] = {user: %i[groups profile]}
      relation, pages, corrected_page = pag_all_records(hash)
      [relation.to_a.map { |c| c.to_full_json_with_preload hash[:user_id] }, pages, corrected_page]
    end

    def self.to_json_view(hash)
      hash[:per] ||= DEFAUlT_PER
      hash[:includes] = {user: %i[groups profile]}
      relation, pages, corrected_page = pag_records(hash)
      [relation.to_a.map { |c| c.to_full_json_with_preload hash[:user_id] }, pages, corrected_page]
    end

    def to_json_with_preload(user_id)
      attributes = self.attributes.slice('text', 'created_at', 'updated_at', 'id','context_id')
      profile_attributes = user.profile.attributes.slice('first_name', 'last_name', 'middle_name')
      {
        can_update: can_update?(user_id),
        user_groups: groups_names,
        email: user.email,
        context_name: context.try(:name)
      }.merge(attributes)
        .merge(profile_attributes)
    end

    def to_full_json_with_preload(user_id)
      to_json_with_preload(user_id).merge(attachable_to_json)
    end

    def groups_names
      user.groups.map(&:name)
    end
  end
end
