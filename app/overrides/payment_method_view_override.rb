# We want to remove environments select list from payment methods view in admin panel
Deface::Override.new(:virtual_path => 'spree/admin/payment_methods/_form',
                     :name => 'Environment section removal',
                     :remove => "[data-hook='environment']"
                     )

# BlueZeal company branding
Deface::Override.new(:virtual_path  => 'spree/admin/payment_methods/_form',
                     :insert_before => "[data-hook='name']",
                     :text => "<%= render 'branding', payment_method: @payment_method%>",
                     :name          => 'branding')