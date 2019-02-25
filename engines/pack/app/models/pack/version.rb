# == Schema Information
#
# Table name: pack_versions
#
#  id               :integer          not null, primary key
#  name_ru          :string
#  description_ru   :text
#  package_id       :integer
#  created_at       :datetime
#  updated_at       :datetime
#  cost             :integer
#  end_lic          :date
#  state            :string
#  lock_col         :integer          default(0), not null
#  deleted          :boolean          default(FALSE), not null
#  service          :boolean          default(FALSE), not null
#  delete_on_expire :boolean          default(FALSE), not null
#  ticket_id        :integer
#  description_en   :text
#  name_en          :string
#

module Pack
  class Version < ActiveRecord::Base

    has_paper_trail

    include AASM
    attr_accessor :user_accesses

    translates :description, :name
    validates_translated :name, :description,presence: true
    validates_translated :name, uniqueness: { scope: :package_id }
    validates :package, presence: true
    belongs_to :package,inverse_of: :versions
    belongs_to :ticket,  class_name: 'Support::Ticket'
    has_many :clustervers,inverse_of: :version, :dependent => :destroy
    has_many :version_options, inverse_of: :version,:dependent => :destroy
    has_many :options_categories, through: :version_options
    has_many :category_values, through: :version_options
    has_many :accesses, dependent: :destroy
    accepts_nested_attributes_for :version_options,:clustervers, allow_destroy: true
    validates_associated :version_options,:clustervers
    scope :finder, ->(q) { where("lower(name_ru) like lower(:q) OR lower(name_en) like lower(:q)", q: "%#{q.mb_chars}%").limit(10) }
    validate :date_and_state, :work_with_stale, :pack_deleted

    aasm :column => :state do
      state :forever, :available, :expired
      event :to_expired do
        transitions from: :available, to: :expired
      end
    end

    def self.ransackable_scopes(_auth_object = nil)
      %i[end_lic_greater]
    end

    def self.end_lic_greater(date)
      where(['pack_versions.end_lic > ? OR pack_versions.end_lic IS NULL', Date.parse(date)])
    end


    def add_errors(to)
      if to != self && to.changes != {}
        errors.add(:stale,"stale_error_nested")
      end
      unless to.new_record?
        to.changes.except("lock_col","updated_at").each_key do |key|
          to.errors.add(key.to_sym, I18n.t("stale_error"))
        end
      end
    end

    def work_with_stale
      if changes["lock_col"]
        add_errors(self)
        version_options.each do |opt|
          add_errors(opt)
        end
        clustervers.each do |opt|
          add_errors(opt)
        end
        restore_attributes([:lock_col])
      end

    end

    def pack_deleted
      if package && package.deleted && !deleted
        errors.add(:deleted,:pack_deleted)
      end
    end

    before_save :incr,:delete_accesses,:make_clvers_not_active, :remove_ticket

    def remove_ticket
      self.ticket = nil if end_lic.blank? || end_lic > Date.today + Pack.expire_after
    end

    def incr
      self.lock_col= lock_col.to_i + 1
    end

    def delete_accesses
      if deleted == true || package.deleted == true
        self.deleted = true
      end
      if deleted == true || state == 'expired' && delete_on_expire
        accesses.load
        accesses.each do |a|
          a.status = 'deleted'
          a.save
        end
      end
    end

    def make_clvers_not_active

      if deleted == true


        clustervers.where(active: true).each do |cl|
          cl.active= false
          cl.save
        end
      end
    end

    def end_lic_readable
      end_lic || Access.human_attribute_name(:forever)
    end

    after_commit :send_emails

    def send_emails
      if previous_changes["state"]
        accesses.where("pack_accesses.who_type in ('User','Core::Project') AND pack_accesses.status IN ('allowed','expired')").each do |ac|
          ::Pack::PackWorker.perform_async(:email_vers_state_changed, ac.id)
        end
      end
    end

    def self.expired_versions
      Version.transaction do
       where("end_lic IS NOT NULL and end_lic < ? and state='available'", Date.today).each{ |ac| ac.update!(state: 'expired') }
      end
    end

    def self.expiring_versions_without_ticket
      where("end_lic IS NOT NULL and end_lic < ?
            AND state='available'", Date.today + Pack.expire_after)
        .where(ticket_id: nil)
    end

    def self.notify_about_expiring_versions
      return unless expiring_versions_without_ticket.exists?
      Version.transaction do
        ticket = Notificator.notify_about_expiring_versions(expiring_versions_without_ticket)
        expiring_versions_without_ticket.each do |version|
          version.update!(ticket: ticket)
        end
      end
    end

    def self.allowed_for_users
      where("pack_versions.service= 'f' OR pack_accesses.status='allowed'")
    end

    def self.allowed_for_users_with_joins(user_id)
      allowed_for_users.user_access(user_id, "LEFT")
    end

    def self.left_join_user_accesses user_id
      joins(
        <<-eoruby
        LEFT JOIN "core_members" ON ( "core_members"."user_id" = #{user_id}   )
        LEFT JOIN "user_groups" ON ( "user_groups"."user_id" = #{user_id}   )
         LEFT JOIN pack_accesses ON (pack_accesses.version_id = pack_versions.id
        AND (pack_accesses.who_type='User' AND pack_accesses.who_id=#{user_id} OR
         pack_accesses.who_type='Core::Project' AND pack_accesses.who_id=core_members.project_id OR
         pack_accesses.who_type='Group' AND pack_accesses.who_id="user_groups"."group_id"  ))
        eoruby
        )

    end

    def self.user_access user_id,join_type
      if user_id==true
        user_id=1
      end
      self.join_accesses self,user_id,join_type
    end

    def name_with_package
      "#{name}   #{I18n.t('Package_name')}: #{package.name}"
    end

    def self.join_accesses(relation,user_id,join_type)
      project_accesses =  relation.joins(
          <<-eoruby
          LEFT JOIN "core_members" ON ( "core_members"."user_id" = #{user_id}   )
          #{join_type} JOIN  pack_accesses ON (pack_accesses.version_id = pack_versions.id
          AND "pack_accesses"."who_type" = 'Core::Project'
          AND core_members.project_id = pack_accesses.who_id)
          eoruby
         )
      group_accesses = relation.joins(
          <<-eoruby
         LEFT JOIN "user_groups" ON ("user_groups"."user_id" = #{user_id}  )
           #{join_type} JOIN  pack_accesses ON (pack_accesses.version_id = pack_versions.id AND "pack_accesses"."who_type" = 'Group'
          AND user_groups.group_id = pack_accesses.who_id)
          eoruby
          )
      user_accesses  = relation.joins(
          <<-eoruby
          #{join_type} JOIN  pack_accesses ON (pack_accesses.version_id = pack_versions.id AND "pack_accesses"."who_type" = 'User'
          AND #{user_id} = pack_accesses.who_id)
          eoruby
            )
      (project_accesses.union group_accesses).union user_accesses
    end


    def deleted?
      deleted || package.deleted
    end

    def available_for_user?
      %w[available forever].include?(state) && !deleted?
    end

    def readable_state
      I18n.t "versions.#{state}"
    end

    def date_and_state
      if state != "forever" && !end_lic
        errors.add(:end_lic, :blank)
      end
    end

    def state_select
       state == "forever" ? "forever" : "not_forever"
    end

    def edit_state_and_lic(state,date)
      if state=="forever"
        date=""
      end
      self.end_lic=(date)
      case state
      when "forever"
      self.state="forever"
      when "not_forever"
        unless end_lic
          self.state = "available"
          return false
        end
        if  end_lic >= Date.current
          self[:state] = "available"
        else
          self[:state] = "expired"
        end
      else
        raise "incorrect state argument"
      end
    end

    def build_clusterver(cluster)
      clustervers.new(core_cluster: cluster).mark_for_destruction
    end

    def build_clustervers
      cluster_ids = clustervers.map(&:core_cluster_id)
      ::Core::Cluster.all.each do |cluster|
        if cluster_ids.exclude? cluster.id
          build_clusterver(cluster)
        end
      end
    end

    def edit_opts
      hash = @params.delete(:version_options_attributes)
      return unless hash
      #Удаляем все
      (hash.values.select { |i| i[:id] }.map { |i| i[:id].to_i } - version_options.map(&:id)).each do |opt_id|
        opt_params = hash.values.detect { |val| val[:id].to_i == opt_id  }
        opt = version_options.new(opt_params.except(:id, :_destroy))
        opt.stale_edit = true
        hash.delete_if { |_key, val| val[:id].to_i == opt_id }
      end
      self.version_options_attributes = hash
    end

    def vers_update(params)
      @params = params.require(:version)
      edit_opts
      update_clustervers @params.delete(:clustervers_attributes)
      edit_state_and_lic(@params.delete(:state_select), @params.delete(:end_lic))
      assign_attributes(version_params @params)
    end

    def update_clustervers(hash)
      return unless hash
      hash.each_value do |h|
        method_name = h.delete(:action)
        destroy = false
        case method_name
        when "active"
          h[:active]="1"
        when "not_active"
          h[:active]="0"
        when "_destroy"
          destroy = true
        else
          raise "incorrect attribute in clustervers"
        end
        needed_cl = clustervers.detect { |cl| cl.core_cluster_id == h[:core_cluster_id].to_i }
        needed_cl ||= clustervers.new h
        if destroy
          needed_cl.mark_for_destruction
        elsif !needed_cl.new_record?
          needed_cl.assign_attributes(h)
        end
      end
    end

    def as_json(_options)
    { id: id, text: (name + self.package_id) }
    end

    def version_params(params)
      params.permit(:delete_on_expire, *Version.locale_columns(:description, :name),:name, :description, :version,
                    :cost, :deleted, :lock_col, :service)
    end

  end
end
