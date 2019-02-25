class ApplicationController < ActionController::Base

  before_action :set_paper_trail_whodunnit

  include ControllerHelper
  include ActionView::Helpers::OutputSafetyHelper

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session
  before_filter :journal_user, :check_notices

  def journal_user
    logger.info "JOURNAL: url=#{request.url}/#{request.method}; user_id=#{current_user ? current_user.id : 'none'}"
  end

  def check_notices
    return unless current_user
    return if request[:controller] =~ /\/admin\//

    #FIXME: each category should be processed separately in outstanding code
    notices = Core::Notice.where(sourceable: current_user, category: 1)
    return if notices.count==0

    list=[]
    notices.each do |note|
      list << note.message
      #next if flash[:'alert-badjobs'] && flash[:'alert-badjobs'].include?(text)
      #job=note.linkable
    end
    text = "#{notices.count==1 ? t('bad_job') : t('bad_jobs')} #{list.join '; '}"
    flash.now[:'alert-badjobs'] = raw text
    
  end
end
