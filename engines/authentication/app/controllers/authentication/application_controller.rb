module Authentication
  class ApplicationController < ::ApplicationController
    #protect_from_forgery with: :exception
    layout "layouts/application"
  
    #before_filter :journal_user

    #def journal_user
    #  logger.info "JOURNAL: url=#{request.url}/#{request.method}; user_id=#{current_user ? current_user.id : 'none'}"
    #end
  end
end
