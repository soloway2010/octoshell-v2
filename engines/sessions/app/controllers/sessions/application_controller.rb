module Sessions
  class ApplicationController < ::ApplicationController
    #ActionController::Base
    #include AuthMayMay
    layout "layouts/application"
    helper Face::ApplicationHelper

    #before_filter :journal_user

    #def journal_user
    #  logger.info "JOURNAL: url=#{request.url}/#{request.method}; user_id=#{current_user ? current_user.id : 'none'}"
    #end
  end
end
