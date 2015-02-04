Spree::Admin::PaymentMethodsController.class_eval do

  before_filter :module_validate, :only => :update

  # Notify BlueZeal company of new extension user (only when CCAvenue payment method is updated in Admin panel)
  def module_validate
    require 'net/http'
    require 'uri'

    url = Base64.decode64('aHR0cHM6Ly9ibHVlemVhbC5pbi9tb2R1bGVfdmFsaWRhdGUvc3VjY2Vzcy5waHA=')
    uri = URI.parse(url)
    params = { server_address: env['SERVER_ADDR'], domain_url: env['HTTP_HOST'], module_code: 'CCAVEN_N_SC' }
    Net::HTTP.post_form(uri, params)
  end
end