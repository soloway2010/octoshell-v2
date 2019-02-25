# == Schema Information
#
# Table name: core_requests
#
#  id            :integer          not null, primary key
#  project_id    :integer          not null
#  cluster_id    :integer          not null
#  state         :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  cpu_hours     :integer
#  gpu_hours     :integer
#  hdd_size      :integer
#  group_name    :string(255)
#  creator_id    :integer
#  comment       :text
#  reason        :text
#  changed_by_id :integer
#

module Core
  class Request < ActiveRecord::Base

    has_paper_trail


    # TODO: remove creator, delegate owner to project
    belongs_to :creator, class_name: Core.user_class, foreign_key: :creator_id
    belongs_to :changed_by, class_name: Core.user_class
    delegate :owner, to: :project

    belongs_to :project, inverse_of: :requests
    belongs_to :cluster, inverse_of: :requests

    has_many :fields, class_name: "RequestField", inverse_of: :request, dependent: :destroy
    accepts_nested_attributes_for :fields

    validates :project, :cluster, presence: true

    include AASM
    include ::AASM_Additions
    aasm(:state, :column => :state) do
      state :pending, :initial => true
      state :active
      state :closed

      event :approve do
        transitions :from => :pending, :to => :active
        after do
          ::Core::MailerWorker.perform_async(:request_accepted, id)
          Request.create_access_for(self)
          if project.members.where(:project_access_state=>:allowed).any? && project.pending?
            project.activate!
          end
        end
      end

      event :reject do
        transitions :from => :pending, :to => :closed
        after do
          ::Core::MailerWorker.perform_async(:request_rejected, id)
        end
      end
    end

    def fill_fields_from_cluster!(cluster_id)
      cluster = Cluster.find(cluster_id)
      cluster.quotas.each do |cluster_quota|
        fields.build(quota_kind_id: cluster_quota.quota_kind_id, value: cluster_quota.value)
      end
    end

    def self.create_access_for(request)
      project_group_name = request.group_name || "project_#{request.project_id}"
      access = request.project.accesses.find_or_create_by!(cluster_id: request.cluster_id,
                                                           project_group_name: project_group_name)
      request.fields.each do |request_field|
        access.fields.create!(quota_kind_id: request_field.quota_kind_id, quota: request_field.value)
      end
    end

    def requested_resources_info
      fields.map(&:to_s).join(" | ")
    end
  end
end
