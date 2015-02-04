module Spree

  CheckoutController.class_eval do

    before_filter :confirm_ccavenue, :only => :update

    private

    # Redirect user to CCAvenue gateway when he/she selects that payment method on checkout page
    def confirm_ccavenue
      return unless (params[:state] == 'payment') && params[:order][:payments_attributes]
      payment_method = PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])
      if payment_method && payment_method.kind_of?(Spree::Ccavenue::PaymentMethod)
        redirect_to gateway_ccavenue_path(@order.number, payment_method.id)
      end
    end

  end

end