# == Schema Information
#
# Table name: core_accesses
#
#  id                 :integer          not null, primary key
#  project_id         :integer          not null
#  cluster_id         :integer          not null
#  state              :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  project_group_name :string(255)
#

module Core
  class Access < ActiveRecord::Base

    has_paper_trail


    belongs_to :project
    belongs_to :cluster

    has_many :fields, class_name: "AccessField", inverse_of: :access, dependent: :destroy
    accepts_nested_attributes_for :fields

    validates :project, :cluster, presence: true

    include AASM
    include ::AASM_Additions
    aasm :state, :column => :state do
      state :opened, :initial => true
      state :closed

      event :close do
        transitions :from => :opened, :to => :closed
      end

      event :reopen do
        transitions :from => :closed, :to => :opened
      end
    end

    def quota_resources_info
      fields.map(&:to_s).join(" | ")
    end

    # Требования к теребоньке.
    #
    # Выполнять все действия в по одному ssh-соединению
    # логировать все команды и результаты выполнения
    # синхронизовать проект
    # синхронизовать участников проекта
    # для участников проекта закидывать ключи через scp

    def synchronize!
      Synchronizer.new(self).run!
    end
  end
end
