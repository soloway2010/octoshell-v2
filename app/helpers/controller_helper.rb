module ControllerHelper
  def flash_message(type,msg)
    flash[type] ||= []
    flash[type] << msg
  end
end
